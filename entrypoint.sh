#!/bin/bash
function launch_backgroud(){
  while true; do echo hello world; sleep 1; done
}

function check_account(){
#add this for minio server, pwd limit "secret key length should be between 8 and 40".
#account limit "access key length should be between 3 and 20"
  if [ ! -f /usr/bin/mc ];then
    return;
  fi
  local username=$1
  local password=$2
  if [ `echo ${username} |wc -L` -lt 3 ];then 
    echo "access key must be minimum 3 or more characters long"; 
    exit 0
  fi
  if [ `echo ${password} |wc -L` -lt 8 ];then 
    echo "secret key must be minimum 8 or more characters long"; 
    exit 0
  fi

}
function smb_base_config(){
  local config_file="$1"
cat >"$config_file" <<EOT
[global]
workgroup = WORKGROUP
netbios name = $hostname
server string = $hostname
security = user
create mask = 0664
directory mask = 0775
force create mode = 0664
force directory mode = 0775
#force user = smbuser
#force group = smbuser
load printers = no
printing = bsd
printcap name = /dev/null
disable spoolss = yes
guest account = nobody
max log size = 50
map to guest = bad user
socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192
local master = no
dns proxy = no
EOT
}
function help_usage(){
cat <<EOH
Samba server container

ATTENTION: This is a recipe highly adapted to my needs, it might not fit yours.
Deal with local filesystem permissions, container permissions and Samba permissions is a Hell, so I've made a workarround to keep things as simple as possible.
I want avoid that the usage of this conainer would affect current file permisions of my local system, so, I've "synchronized" the owner of the path to be shared with Samba user. This mean that some commitments and limitations must be assumed.

Container will be configured as samba sharing server and it just needs:
 * host directories to be mounted,
 * users (one or more uid:gid:username:usergroup:password tuples) provided,
 * shares defined (name, path, users).

 -u uid:gid:username:usergroup:password         add uid from user p.e. 1000
                                                add gid from group that user belong p.e. 1000
                                                add a username p.e. alice
                                                add a usergroup (wich user must belong) p.e. alice
                                                protected by 'password' (The password may be different from the user's actual password from your host filesystem)

 -s name:path:rw:user1[,user2[,userN]]
                              add share, that is visible as 'name', exposing
                              contents of 'path' directory for read+write (rw)
                              or read-only (ro) access for specified logins
                              user1, user2, .., userN
 -d user1[,user2[,userN]]
                              delete account for 
                              user1, user2, .., userN
 -p        perpare the common configure.
 -l        launch the application
 -r        relaunch the application

To adjust the global samba options, create a volume mapping to /config

Example:
docker run -d -p 445:445 --name samba \
  -e TZ=Asia/Shanghai \
  -v /home/docker_apps/samba_minio:/share/data \
  echo756729890/samba -p \
  -u "1000:1000:echo:echo:echo" \
  -u "1001:1001:bob:bob:secret" \
  -u "1002:1002:guest:guest:guest" \
  -s "Backup directory:/share/backups:rw:echo,bob" \
  -s "echo (private):/share/data/echo:rw:echo" \
  -s "Bob (private):/share/data/bob:rw:bob" \
  -s "Documents (readonly):/share/data/documents:ro:guest,echo,bob" \
  -l

EOH
}
function add_minio_account(){
  if [ ! -f /usr/bin/mc ];then
    return;
  fi
  local username=$1
  local password=$2
  cp /etc/model.json /tmp/${username}.json
  sed -i "s/minio-my-bucketname/$username/" /tmp/${username}.json
  mc admin policy add minio ${username} /tmp/${username}.json
  mc admin user add minio ${username} ${password}
  mc admin policy set minio ${username} user=${username}
  mc policy set download minio/${username}

}
function del_minio_account(){
  if [ ! -f /usr/bin/mc ];then
    return;
  fi
  local username=$1
  mc admin user remove minio ${username}
  mc policy set none minio/${username}

}

function smb_launch(){
  nmbd -D
  exec ionice -c 3 smbd -FS --no-process-group --configfile="$CONFIG_FILE" < /dev/null
}
function smb_relaunch(){
  nmbd reload
  smbd reload
}
#main
CONFIG_FILE="/etc/samba/smb.conf"
FIRSTTIME=true

hostname=`hostname`
set -e

while getopts ":u:s:f:hlpbdr" opt; do
  case $opt in
    f)
      if [ "$OPTARG" == "minio" ];then
	rm -rf /usr/bin/mc
        cp /usr/bin/mc.bin/mc /usr/bin/mc
        chmod u+x /usr/bin/mc
      fi
      ;;
    b)
      #  nohup ping -i 1000 localhost
      launch_backgroud
      ;;
    p)
      smb_base_config "$CONFIG_FILE"
      ;;
    h)
      help_usage
      launch_backgroud
      # exit 1
      ;;
    l)
      smb_launch
      ;;
    r)
      smb_relaunch
      ;;
    u)
      echo -n "Add user "
      IFS=: read uid group username groupname password <<<"$OPTARG"
      check_account $username $password
      echo -n "'$username' "
      if [[ $FIRSTTIME ]] ; then
        id -g "$group" &>/dev/null || id -gn "$groupname" &>/dev/null || addgroup -g "$group" -S "$groupname"
        id -u "$uid" &>/dev/null || id -un "$username" &>/dev/null || adduser -u "$uid" -G "$groupname" "$username" -SHD 
        echo "mkdir /share/data/$username"
        mkdir -p "/share/data/$username" && chown -R "$username": "/share/data/$username"
        if [ $? != 0 ];then
          echo "mkdir fail"
        fi
        FIRSTTIME=false
      fi
      echo -n "with password '$password' "
      echo "$password" |tee - |smbpasswd -s -a "$username"
      echo "DONE"
      ;;
    s)
      echo -n "Add share folder"
      IFS=: read sharename sharepath readwrite users <<<"$OPTARG"
      echo -n "'$sharename' "
      echo "[$sharename]" >>"$CONFIG_FILE"
      echo -n "path '$sharepath' "
      echo "path = \"$sharepath\"" >>"$CONFIG_FILE"
      echo -n "read: $readwrite"
      if [[ "rw" = "$readwrite" ]] ; then
        echo -n "+write "
        echo "read only = no" >>"$CONFIG_FILE"
        echo "writable = yes" >>"$CONFIG_FILE"
      else
        echo -n "-only "
        echo "read only = yes" >>"$CONFIG_FILE"
        echo "writable = no" >>"$CONFIG_FILE"
      fi
      add_minio_account $username $password
      if [[ -z "$users" ]] ; then
        echo -n "for guests: "
        echo "browseable = yes" >>"$CONFIG_FILE"
        echo "guest ok = yes" >>"$CONFIG_FILE"
        echo "public = yes" >>"$CONFIG_FILE"
      else
        echo -n "for users: "
        users=$(echo "$users" |tr "," " ")
        echo -n "$users "
        echo "valid users = $users" >>"$CONFIG_FILE"
        echo "write list = $users" >>"$CONFIG_FILE"
      fi
      echo "DONE"
      ;;
    d)
      echo -n "Del user "
      IFS=: read username groupname <<<"$OPTARG"
      echo -n "${username}"
      add_minio_account $username
      deluser "$username"
      # if [ -d "/share/data/$username" ];then
         # rm -rf "/share/data/$username"
      # fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      help_usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      help_usage
      exit 1
      ;;
  esac
done

