#!/bin/sh
# Potential variables: timezone, lang, local, drive, and bootloader partition
pacman --noconfirm --needed -Sy dialog intel-ucode reflector networkmanager >/dev/null 2>&1

if [ $# -ne 2 ]; then
    dialog --title "BOOMER BRAINLET" --msgbox "Something went wrong. Chroot did not receive 2 arguments.\nIt needs the drive and the bootloader partition." 5 50
    exit 1
fi

drive="$1"
bootloader_partition="$2"

dialog --title "Dotfile installer" --infobox "Arch was installed on ${drive}!" 3 50

# dialog --title "Dotfile installer" --infobox "Updating pacman mirrors." 3 70
# reflector --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
UUID=$(blkid -s PARTUUID -o value ${bootloader_partition})
dialog --title "Dotfile installer" --infobox "Installing bootloader on ${bootloader_partition} with UUID ${UUID}" 3 50
bootctl install >/dev/null 2>&1 || echo "Bootctl seemed to hit a snag..."
echo title Arch Linux >> /boot/loader/entries/arch.conf
echo linux /vmlinuz-linux >> /boot/loader/entries/arch.conf
echo initrd /intel-ucode.img >> /boot/loader/entries/arch.conf
echo initrd /initramfs-linux.img >> /boot/loader/entries/arch.conf
echo options root=PARTUUID=${UUID} >> /boot/loader/entries/arch.conf

# Set system password
passwd

# Set system timezone
TZuser=$(cat tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
hwclock --systohc

# Set system locale
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

systemctl enable NetworkManager
systemctl start NetworkManager

installdotfiles() { curl -O https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/chroot.sh && bash dotfile-installer.sh ;}
dialog --title "Install dotfiles?" --yesno "Install dotfiles.vdoster.com?" 5 50 && installdotfiles
