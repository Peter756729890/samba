ARG BASEIMAGE=alpine
FROM ${BASEIMAGE}

ARG BUILD_DATE=2021-07-08
ARG VCS_REF
ARG VERSION=v1.0
LABEL mantainer="Eloy Lopez <elswork@gmail.com>" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="Samba" \
    org.label-schema.description="Multiarch Samba for amd64 arm32v7 or arm64" \
    org.label-schema.url="https://deft.work/Samba" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/DeftWork/samba" \
    org.label-schema.vendor="Deft Work" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0"
#fetch http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64/APKINDEX.tar.gz timeout, by echo, 2021-07-08 15:34:41
#run cat /etc/apk/repositories
#RUN echo -e http://mirrors.ustc.edu.cn/alpine/v3.7/main/ > /etc/apk/repositories
#RUN echo -e http://mirrors.aliyun.com/alpine/v3.7/main/ > /etc/apk/repositories
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
#RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
RUN apk update && apk upgrade && apk add bash samba-common-tools samba tzdata && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh

EXPOSE 137/udp 138/udp 139 445

HEALTHCHECK --interval=60s --timeout=15s CMD smbclient -L \\localhost -U % -m SMB3

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-h"]
