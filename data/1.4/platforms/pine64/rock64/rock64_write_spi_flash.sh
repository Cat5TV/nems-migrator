#!/bin/bash

set -eo pipefail

if [[ "$(id -u)" -ne "0" ]]; then
    echo "This script requires root."
    exit 1
fi

if ! which nandwrite &>/dev/null; then
    echo "Install mtd-utils with 'apt-get install mtd-utils'"
    exit 1
fi

if dpkg -s "u-boot-rockchip-rockpro64" &>/dev/null; then
    BOARD=rockpro64
    LOADER_NAME=rkspi_loader
elif dpkg -s "u-boot-rockchip-rock64" &>/dev/null; then
    BOARD=rock64
    LOADER_NAME=rksd_loader
else
    exit "Unknown package installed."
    exit 1
fi

LOADER="/usr/lib/u-boot-${BOARD}/${LOADER_NAME}.img"
if ! -f "$LOADER"; then
    echo "Missing board bootloader image: $LOADER"
    exit 1
fi

echo "Doing this will overwrite data stored on SPI Flash"
echo "  and it will require that you use eMMC or SD"
echo "  as your boot device."
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

write_nand() {
    if ! MTD=$(grep \"$1\" /proc/mtd | cut -d: -f1); then
        echo "$1 partition on MTD is not found"
        return 1
    fi

    echo "Writing /dev/$MTD with content of $2"
    flash_erase "/dev/$MTD" 0 0
    nandwrite "/dev/$MTD" < "$2"
}

write_nand loader "$LOADER"

echo Done.
