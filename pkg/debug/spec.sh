#!/bin/sh
#shellcheck disable=SC2039
# This script creates an initial hardware model file.
# It should be run on KVM and without having already made some adapters be
# app direct
# The KVM requirement is due to looking at iommu_group and that might be
# bogus under Xen
# Note that the generated USB configuration does not include each USB port
# aka receptacle, since that is not known to software; only the controllers
# can be seen. Those can be manually added after determining which USB controller
# handles the different USB ports.
# Also, the user needs to fill in the jpg links with the photos of the front
# and back of the box.

if [ "$(uname -m)" = x86_64 ]; then
   ARCH=2
else
   ARCH=4
fi

# pci_iommu_group returns the iommu_group, or "" if there is none
# $1 is the PciLong value
# If running on Xen we can't tell the safe groups
pci_iommu_group() {
    local pcilong=$1
    if [ -e /dev/xen ]; then
        echo "warning:no_group_determined_using_xen"
    else
        readlink "/sys/bus/pci/devices/$pcilong/iommu_group" 2>/dev/null | sed 's,.*kernel/,,'
    fi
}

# get_assignmentgroup returns a guess at the assignment group
# Note that if multiple devices are functions on the same controller
# they are made unassignable, since it is hard to gather the group and
# verify that there are no other functions on that controller
# $1 is the name; $2 is the PciLong value
get_assignmentgroup() {
    local pcilong=$2
    pci_iommu_group "$pcilong"
}


if [ -e /dev/xen ]; then
   CPUS=$(eve exec xen-tools xl info | grep nr_cpus | cut -f2 -d:)
   MEM=$(( $(eve exec xen-tools xl info | grep total_memory | cut -f2 -d:) / 1024 ))
else
   CPUS=$(grep -c '^processor.*' < /proc/cpuinfo)
   MEM=$(awk '/MemTotal:/ { print int($2 / 1048576); }' < /proc/meminfo)
fi

DISK=$(lsblk -b  | grep disk | awk '{ total += $4; } END { print int(total/(1024*1024*1024)); }')
WDT=$([ -e /dev/watchdog ] && echo true || echo false)
HSM=$([ -e /dev/tpmrm0 ] && echo 1 || echo 0)

cat <<__EOT__
{
  "arch": $ARCH,
  "productURL": "$(cat /persist/status/hardwaremodel || cat /config/hardwaremodel)",
  "productStatus": "production",
  "attr": {
    "memory": "${MEM}G",
    "storage": "${DISK}G",
    "Cpus": "${CPUS}",
    "watchdog": ${WDT},
    "hsm": ${HSM},
    "leds": 0
  },
  "logo": {
    "logo_back":"/workspace/spec/logo_back_.jpg",
    "logo_front":"/workspace/spec/logo_front_.jpg"
  },
  "ioMemberList": [
__EOT__

#enumerate GPUs
ID=""
for VGA in $(lspci -D  | grep VGA | cut -f1 -d\ ); do
    grp=$(get_assignmentgroup "VGA${ID}" "$VGA")
cat <<__EOT__
    {
      "ztype": 7,
      "phylabel": "VGA${ID}",
      "assigngrp": "${grp}",
      "phyaddrs": {
        "PciLong": "${VGA}"
      },
      "logicallabel": "VGA${ID}",
      "usagePolicy": {}
    },
__EOT__
    ID=$(( ${ID:-0} + 1 ))
done

#enumerate USB
ID=""
for USB in $(lspci -D  | grep USB | cut -f1 -d\ ); do
    grp=$(get_assignmentgroup "USB${ID}" "$USB")
cat <<__EOT__
    {
      "ztype": 2,
      "phylabel": "USB${ID}",
      "assigngrp": "${grp}",
      "phyaddrs": {
        "PciLong": "${USB}"
      },
      "logicallabel": "USB${ID}",
      "usagePolicy": {}
    },
__EOT__
    ID=$(( ${ID:-0} + 1 ))
done
if [ -z "$ID" ] && [ "$(lsusb -t | wc -l)" -gt 0 ]; then
cat <<__EOT__
    {
      "ztype": 2,
      "phylabel": "USB",
      "assigngrp": "USB",
      "logicallabel": "USB",
      "usagePolicy": {}
    },
__EOT__
fi

#enumerate serial ports
ID="1"
for TTY in /sys/class/tty/*; do
   if [ -f "$TTY/device/resources" ]; then
      IO=$(grep '^io ' "$TTY/device/resources" | sed -e 's#io 0x##' -e 's#0x##')
      IRQ=$(awk '/^irq /{print $2;}' < "$TTY/device/resources")
   elif [ "$(uname -m)" = aarch64 ] && [ -f "$TTY/irq" ]; then
      IRQ=$(cat "$TTY/irq")
      [ "${IRQ:-0}" -gt 0 ] || IRQ=""
      IO=""
   else
      IO=""
      IRQ=""
   fi
   TTY=$(echo "$TTY" | cut -f5 -d/)
   if [ -n "$IO" ] || [ -n "$IRQ" ]; then
cat <<__EOT__
    {
      "ztype": 3,
      "phylabel": "COM${ID}",
      "assigngrp": "COM${ID}",
      "phyaddrs": {
__EOT__
      if [ -n "$IO" ] && [ -n "$IRQ" ]; then
cat <<__EOT__
        "Ioports": "${IO}",
        "Irq": "${IRQ}",
__EOT__
      fi
cat <<__EOT__
        "Serial": "/dev/${TTY}"
      },
      "logicallabel": "COM${ID}",
      "usagePolicy": {}
    },
__EOT__
     ID=$(( ${ID:-0} + 1 ))
   fi
done

#enumerate NICs
for ETH in /sys/class/net/*; do
   LABEL=$(echo "$ETH" | sed -e 's#/sys/class/net/##' -e 's#^k##')
   ETH=$(readlink "$ETH")
   if echo "$ETH" | grep -vq '/virtual/'; then
cat <<__EOT__
    ${COMMA}
    {
      "ztype": 1,
      "usage": 1,
      "phylabel": "${LABEL}",
      "logicallabel": "${LABEL}",
      "usagePolicy": {
        "freeUplink": true
      },
__EOT__
     BUS_ID=$(echo "$ETH" | sed -e 's#/net/.*'"${LABEL}"'##' -e 's#^.*/##')
     if echo "$BUS_ID" | grep -q '[0-9a-f][0-9a-f][0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f].[0-9a-f]'; then
         grp=$(get_assignmentgroup "$LABEL" "$BUS_ID")
cat <<__EOT__
      "assigngrp": "${grp}",
      "phyaddrs": {
        "Ifname": "${LABEL}",
        "PciLong": "${BUS_ID}"
      }
__EOT__
     else
cat <<__EOT__
      "phyaddrs": {
        "Ifname": "${LABEL}"
      }
__EOT__
     fi
     COMMA="},"
  fi
done
#enumerate Audio
ID=""
for audio in $(lspci -D  | grep Audio | cut -f1 -d\ ); do
    grp=$(get_assignmentgroup "Audio${ID}" "$audio")
cat <<__EOT__
    ${COMMA}
    {
      "ztype": 2,
      "phylabel": "Audio${ID}",
      "assigngrp": "${grp}",
      "phyaddrs": {
        "PciLong": "${audio}"
      },
      "logicallabel": "Audio${ID}",
      "usagePolicy": {}
__EOT__
    ID=$(( ${ID:-0} + 1 ))
    COMMA="},"
done

cat <<__EOT__
    }
  ]
}
__EOT__
