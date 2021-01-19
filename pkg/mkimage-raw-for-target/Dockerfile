FROM linuxkit/alpine:77287352db68b442534c0005edd6ff750c8189f3 AS build

RUN apk add --no-cache \
    util-linux-dev=2.28.2-r2 \
    util-linux=2.28.2-r2 \
    sgdisk=1.0.1-r1 \
    bash=4.3.48-r1 \
    busybox=1.26.2-r6 \
    mtools=4.0.18-r1 \
    dosfstools=4.1-r1 \
    libarchive-tools=3.3.1-r2 \
    e2fsprogs=1.43.4-r0 \
    coreutils=8.27-r0 \
    sfdisk=2.28.2-r2

RUN echo "mtools_skip_check=1" >> etc/mtools.conf
WORKDIR /
COPY make-raw-for-target /make-raw-for-target
ENTRYPOINT ["/make-raw-for-target"]