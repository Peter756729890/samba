# Samba

A [Docker](http://docker.com) file to build images for many platforms (linux/amd64, linux/arm64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6) with a installation of [Samba](https://www.samba.org/) that is the standard Windows interoperability suite of programs for Linux and Unix. This is my own Multi-architecture docker recipe.

> Be aware! You should read carefully the usage documentation of every tool!

## Thanks to

- [Samba](https://www.samba.org/)
- [dastrasmue rpi-samba](https://github.com/dastrasmue/rpi-samba)

## Details

- [GitHub](https://github.com/DeftWork/samba)
- [Deft.Work my personal blog](http://deft.work/Samba)

| Docker Hub | Docker Pulls | Docker Stars | Size/Layers |
| --- | --- | --- | --- |
| [samba](https://hub.docker.com/r/elswork/samba "elswork/samba on Docker Hub") | [![](https://img.shields.io/docker/pulls/elswork/samba.svg)](https://hub.docker.com/r/elswork/samba "elswork/samba on Docker Hub") | [![](https://img.shields.io/docker/stars/elswork/samba.svg)](https://hub.docker.com/r/elswork/samba "elswork/samba on Docker Hub") | [![](https://images.microbadger.com/badges/image/elswork/samba.svg)](https://microbadger.com/images/elswork/samba "elswork/samba on microbadger.com") |

## Build Instructions

Build for amd64, armv7l, aarch64 architecture (thanks to its [Multi-Arch](https://blog.docker.com/2017/11/multi-arch-all-the-things/) base image)

``` sh
docker build -t elswork/samba .
```

## Usage

I use it to share files between Linux and Windows, but Samba has many other capabilities.

ATTENTION: This is a recipe highly adapted to my needs, it might not fit yours.
Deal with local filesystem permissions, container permissions and Samba permissions is a Hell, so I've made a workarround to keep things as simple as possible.
I want avoid that the usage of this conainer would affect current file permisions of my local system, so, I've "synchronized" the owner of the path to be shared with Samba user. This mean that some commitments and limitations must be assumed.

Container will be configured as samba sharing server and it just needs:
 * host directories to be mounted,
 * users (one or more uid:gid:username:usergroup:password tuples) provided,
 * shares defined (name, path, users).

-u uid:gid:username:usergroup:password

- uid from user p.e. 1000
- gid from group that user belong p.e. 1000
- username p.e. alice
- usergroup (wich user must belong) p.e. alice
- password (The password may be different from the user's actual password from your host filesystem)

-s name:path:rw:user1[,user2[,userN]]

- add share, that is visible as 'name', exposing contents of 'path' directory for read+write (rw) or read-only (ro) access for specified logins user1, user2, .., userN 

### Serve 

Start a samba fileshare.

``` sh
docker run -d -p 445:445 \
  -- hostname any-host-name \ # Optional
  -e TZ=Europe/Madrid \ # Optional
  -v /any/path:/share/data \ # Replace /any/path with some path in your system owned by a real user from your host filesystem
  elswork/samba \
  -u "1000:1000:alice:alice:put-any-password-here" \ # At least the first user must match (password can be different) with a real user from your host filesystem
  -u "1001:1001:bob:bob:secret" \
  -u "1002:1002:guest:guest:guest" \
  -s "Backup directory:/share/backups:rw:alice,bob" \ 
  -s "Alice (private):/share/data/alice:rw:alice" \
  -s "Bob (private):/share/data/bob:rw:bob" \
  -s "Documents (readonly):/share/data/documents:ro:guest,alice,bob"
``` 

This is my real usage command:

``` sh
docker run -d -p 445:445 -e TZ=Europe/Madrid \
    -v /home/pirate/docker/makefile:/share/folder elswork/samba \
    -u "1000:1000:pirate:pirate:put-any-password-here" \
    -s "SmbShare:/share/folder:rw:pirate"
```
or this if the user that owns the path to be shared match with the user that raise up the container:

``` sh
docker run -d -p 445:445 --hostname $HOSTNAME -e TZ=Europe/Madrid \
    -v /home/pirate/docker/makefile:/share/folder elswork/samba \
    -u "$(id -u):$(id -g):$(id -un):$(id -gn):put-any-password-here" \
    -s "SmbShare:/share/folder:rw:$(id -un)"
```

On Windows point your filebrowser to `\\host-ip\` to preview site.

---
**[Sponsor me!](https://github.com/sponsors/elswork) Together we will be unstoppable.**
2021-07-09 14:17:44 echo
issue: 没有自动创建文件夹，需要手动生产并给权限。
2021-07-14 09:09:14 echo
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
#或者使用如下方式，支持后续增加账户，无需重新编译镜像。
docker run -d -p 445:445 --name samba \
  -e TZ=Asia/Shanghai \
  -v /home/docker_apps/samba_minio:/share/data \
  echo756729890/samba -b

#加载默认配置
bash entrypoint.sh -p
#容器启动后新增账户格式
bash entrypoint.sh -u "2000:2000:young:young:young" -s "young (private):/share/data/young:rw:young"
#启动samba,每次新增用户需要重新启动该服务。
bash entrypoint.sh -l &
