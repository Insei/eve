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
    sfdisk=2.28.2-r2 \
    openssl=1.0.2k-r0 \
    python3=3.6.1-r2

RUN ln -sf python3 /usr/bin/python

ARG WD=/wd

ARG BSP_T210_LINK=https://developer.download.nvidia.com/embedded/L4T/r32_Release_v4.4/r32_Release_v4.4-GMC3/T210/Tegra210_Linux_R32.4.4_aarch64.tbz2
ARG BSP_T210_FILE=$WD/Tegra210_Linux_R32.4.4_aarch64.tbz2
ARG BSP_T210_FOLDER=$WD/L4T_210

RUN echo "mtools_skip_check=1" >> etc/mtools.conf
WORKDIR $WD/
COPY patches patches

RUN wget "$BSP_T210_LINK" -O "$BSP_T210_FILE"
RUN mkdir "$BSP_T210_FOLDER" && tar xpf "$BSP_T210_FILE" -C "$BSP_T210_FOLDER"
RUN mkdir parts

# TODO: build from source in u-boot package.
# replace jetson-nano-b u-boot.bin binnary to new version.
COPY jetson-nano-b/u-boot.bin $BSP_T210_FOLDER/Linux_for_Tegra/bootloader/t210ref/p3450-porg/u-boot.bin

# Apply local patches
WORKDIR $BSP_T210_FOLDER/Linux_for_Tegra
RUN set -e ; for patch in /wd/patches/*.patch; do \
        echo "Applying $patch"; \
        patch -p1 < "$patch"; \
    done

# Make jetson nano sdcard signed parts
RUN BOARDID=3448 BOARDSKU='' FAB=300 ./flash.sh --no-flash --no-systemimg --sign jetson-nano-qspi-sd mmcblk0p1
# Parse partitions and remove APP partition from parsed layout
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN tools/nvptparser.py bootloader/signed/flash.xml sdcard | head -n -1 > bootloader/signed/partitions.txt
RUN mkdir $WD/parts/jetson-nano-b && cp bootloader/signed/* $WD/parts/jetson-nano-b/
RUN cp bootloader/eks.img bootloader/bmp.blob bootloader/rp4.blob $WD/parts/jetson-nano-b/

# Clean UP TEGRA BSP
WORKDIR $WD/
RUN rm -rf $BSP_T210_FOLDER
RUN rm -rf $BSP_T210_FILE
RUN rm -rf patches

FROM scratch
ENTRYPOINT []
CMD []
WORKDIR /preseted
COPY --from=build /wd/parts ./tegra