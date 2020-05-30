#!/bin/bash

if [ $# -ne 2 ]; then
    dialog --title "BOOMER BRAINLET" \
           --msgbox "Chroot did not receive 2 arguments.\nIt needs a drive and bootloader partition." \
           0 0
    exit 1
fi

drive="$1"
bootloader_partition="$2"

get_dependencies() { \
    pacman -Sy --noconfirm dialog intel-ucode reflector networkmanager 
}

set_root_password() { \
    passwd
}

set_timezone() { \
    TZuser=$(cat tzfinal.tmp)
    ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
    hwclock --systohc
}

start_network_manager() { \
    systemctl enable NetworkManager
    systemctl start NetworkManager
}

set_locale() { \
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "en_US ISO-8859-1" >> /etc/locale.gen
    locale-gen
}

install_bootloader() { \
    UUID=$(blkid -s PARTUUID -o value "$drive"3)
    dialog --title "Arch chroot" --yesno "Install bootloader on ${bootloader_partition} with UUID ${UUID}?" 0 0 || exit
    dialog --title "Arch chroot" \
           --infobox "Installing bootloader on ${bootloader_partition} with UUID ${UUID}" \
           0 0
    bootctl install || echo "Bootctl seemed to hit a snag..."
    echo title Arch Linux >> /boot/loader/entries/arch.conf
    echo linux /vmlinuz-linux >> /boot/loader/entries/arch.conf
    echo initrd /intel-ucode.img >> /boot/loader/entries/arch.conf
    echo initrd /initramfs-linux.img >> /boot/loader/entries/arch.conf
    echo options root=PARTUUID=${UUID} >> /boot/loader/entries/arch.conf
}

install_dotfiles() { \
    dialog --title "Arch chroot" \
           --yesno "Install dotfiles" \
           0 0 || return
    curl -O https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/dotfiles-installer.sh 
    bash dotfiles-installer.sh 
}

run_reflector() { \
    reflector --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
}

# ---------------------------- #
#            Install           #
# ---------------------------- #
get_dependencies
run_reflector
set_root_password
set_locale
set_timezone
start_network_manager
install_bootloader
install_dotfiles
