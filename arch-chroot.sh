#!/bin/bash

BACKTITLE="Arch installer"
TITLE="Arch chroot"

if [ $# -ne 2 ]; then
    dialog \
        --backtitle "$BACKTITLE" \
        --title "BOOMER BRAINLET" \
        --msgbox "Chroot did not receive 2 arguments.\nIt needs a drive and bootloader partition." \
        0 0
    exit 1
fi

DRIVE="$1"
BOOTLOADER_PARTITION="$2"

get_dependencies() {
    pacman -Sy --noconfirm dialog intel-ucode reflector networkmanager
}

install_bootctl_bootloader() {
    UUID=$(blkid -s PARTUUID -o value "$DRIVE"3)
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "Install Bootctl on ${BOOTLOADER_PARTITION} with UUID ${UUID}?" \
        0 0 || exit
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Installing bootctl on ${BOOTLOADER_PARTITION} with UUID ${UUID}" \
        0 0
    bootctl install || echo "Bootctl seemed to hit a snag..."
    {
        echo title Arch Linux
        echo linux /vmlinuz-linux
        echo initrd /intel-ucode.img
        echo initrd /initramfs-linux.img
        echo options root=PARTUUID="${UUID}"
    } >> /boot/loader/entries/arch.conf
}

install_bootloader() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --menu "Choose a bootloader to install" \
        0 0 \
        2 1 Grub 2 Bootctl \
        2> temp
    if [ "$?" = "0" ]; then
        _return=$(cat temp)
        if [ "$_return" = "1" ]; then
            install_grub_bootloader
        fi
        if [ "$_return" = "2" ]; then
            install_bootctl_bootloader
        fi
    else
        dialog \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --infobox "Installer exited because no bootloader was chosen." \
            0 0
        rm -f temp
        exit
    fi
    rm -f temp
}

install_grub_bootloader() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "Install Grub on ${BOOTLOADER_PARTITION} with UUID ${UUID}?" \
        0 0 || exit
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Installing grub on ${BOOTLOADER_PARTITION}" \
        0 0
    pacman --noconfirm --needed -S grub
    grub-install --target=i386-pc "$DRIVE"
    grub-mkconfig -o /boot/grub/grub.
}

install_dotfiles() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "Install dotfiles" \
        0 0 || return
    curl -O https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/dotfiles-installer.sh
    sudo bash dotfiles-installer.sh
}

set_root_password() {
    passwd
}

set_timezone() {
    TZuser=$(cat tzfinal.tmp)
    ln -sf /usr/share/zoneinfo/"$TZuser" /etc/localtime
    hwclock --systohc
}

start_network_manager() {
    systemctl enable NetworkManager
    systemctl start NetworkManager
}

set_locale() {
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    {
        echo "en_US.UTF-8 UTF-8"
        echo "en_US ISO-8859-1"
    } > /etc/locale.gen
    locale-gen
}

run_reflector() {
    reflector --verbose \
        --latest 25 \
        --sort rate \
        --save /etc/pacman.d/mirrorlist \
        > /dev/null 2>&1
}

# ---------------------------- #
#            Install           #
# ---------------------------- #
get_dependencies
run_reflector
# set_root_password
set_locale
set_timezone
start_network_manager
install_bootloader
install_dotfiles
