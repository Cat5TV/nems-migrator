#!/bin/bash

set -eo pipefail

if [[ "$(id -u)" -ne "0" ]]; then
    echo "This script requires root."
    exit 1
fi

if dpkg -s "u-boot-rockchip-rockpro64" &>/dev/null; then
    BOARD=rockpro64
    LOADER_NAME=rksd_loader
elif dpkg -s "u-boot-rockchip-rock64" &>/dev/null; then
    BOARD=rock64
    LOADER_NAME=rksd_loader
else
    exit "Unknown package installed."
    exit 1
fi

LOADER="/usr/lib/u-boot-${BOARD}/${LOADER_NAME}.img"
if [[ ! -f "$LOADER" ]]; then
    echo "Missing board bootloader image: $LOADER"
    exit 1
fi

echo "Doing this will overwrite bootloader stored on your boot device it might break your system."
echo "If this happens you will have to manually fix that outside of your Rock64."
echo "If you are booting from SPI. You have to use 'rock64_write_spi_flash.sh'."
echo ""

if ! ( grep -qi "$BOARD" /proc/device-tree/compatible || grep -qi "$BOARD" /etc/flash-kernel/machine ); then
    echo "You are currently running on different board ($(cat /proc/device-tree/model))."
    echo "It may brick your device or the system unless"
    echo "you know what are you doing."
    echo ""
fi

while true; do
    echo "Type YES to continue or Ctrl-C to abort."
    read CONFIRM
    if [[ "$CONFIRM" == "YES" ]]; then
        break
    fi
done

if ! debsums -s "u-boot-rockchip-${BOARD}"; then
    echo "Verification of 'u-boot-rockchip-${BOARD}' failed."
    echo "Your disk might have got corrupted."
    exit 1
fi

MNT_DEV=$(findmnt /boot/efi -n -o SOURCE)

case $MNT_DEV in
    /dev/mmcblk*p6|/dev/sd*p6|/dev/mapper/loop*p6|/dev/mapper/nvme*p6)
        dd if=$LOADER of="${MNT_DEV/p6/p1}"
        ;;

    *)
        echo "Cannot detect boot device ($MNT_DEV)."
        exit 1
        ;;
esac

sync

echo Done.
