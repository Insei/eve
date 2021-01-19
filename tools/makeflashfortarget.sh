#!/bin/sh
# Usage:
#
#      ./makeflashbyboard.sh <root parts dir> <output.img> <board>
#
EVE="$(cd "$(dirname "$0")" && pwd)/../"
PATH="$EVE/build-tools/bin:$PATH"
MKFLASHFORTARGET_TAG="$(linuxkit pkg show-tag "$EVE/pkg/mkimage-raw-for-target")"

# Script create image with size by partition layout or by the specified image size
touch "$2"
# If we're a non-root user, the bind mount gets permissions sensitive.
# So we go docker^Wcowboy style
chmod ugo+w "$2"

PARTS_ROOT="$(cd "$1" && pwd)"
IMAGE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
BOARD=$3
IMG_SIZE_MB=$4

docker run -v "$PARTS_ROOT:/parts" -v "$IMAGE:/output.img" "$MKFLASHFORTARGET_TAG" /output.img "$BOARD" "$IMG_SIZE_MB"