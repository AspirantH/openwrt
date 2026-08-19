#!/bin/bash

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

#bash $SHELL_FOLDER/../common/kernel_6.6.sh

sed -i 's/Os/O2/g' include/target.mk

sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += kmod-fs-f2fs kmod-usb-hid usbutils pciutils kmod-vmxnet3 kmod-igbvf kmod-iavf fdisk lsblk kmod-ixgbevf/' target/linux/x86/Makefile

sed -i 's/256/1024/g' target/linux/x86/image/Makefile
