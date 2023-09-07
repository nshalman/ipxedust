#! /usr/bin/env nix-shell
#! nix-shell -i bash -p dosfstools parted qemu-utils

# This is terrible
# Don't use this somewhere important
# It might wipe all your drives
# Pretend you never saw it.

set -o xtrace
set -o errexit

sudo umount /mnt || :
sudo losetup -d /dev/loop9 || :

diskImage=ipxedust.floppy
qemu-img create -f raw $diskImage 1440K

parted --script $diskImage -- \
	mklabel gpt \
	mkpart ESP fat32 0 -0 \
	set 1 boot on \

sudo losetup /dev/loop9 $diskImage
sudo partprobe /dev/loop9
sudo mkfs.vfat -F 12 /dev/loop9p1
sudo mount /dev/loop9p1 /mnt

sudo mkdir -p /mnt/EFI/BOOT 
sudo cp binary/ipxe.efi /mnt/EFI/BOOT/BOOTX64.efi
sudo sync
sudo umount /mnt
