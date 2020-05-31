#!/bin/bash

BACKTITLE="Arch installer"
TITLE="Arch chroot"

if [ $# -ne 3 ]; then
    dialog \
        --backtitle "$BACKTITLE" \
        --title "BOOMER BRAINLET" \
        --msgbox "Chroot did not receive 2 arguments.\nIt needs a drive and bootloader partition." \
        0 0
    exit 1
fi

DRIVE="$1"
BOOTLOADER_PARTITION="$2"
BOOTLOADER=$3

get_dependencies() {
    pacman -Sy --noconfirm dialog intel-ucode reflector networkmanager
}

install_bootctl_bootloader() {
    UUID=$(blkid -s PARTUUID -o value "$BOOTLOADER_PARTITION")
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
   if [ "$BOOTLOADER" = "grub" ]; then
    install_grub_bootloader
   elif [ "$BOOTLOADER" = "bootctl" ]; then
    install_bootctl_bootloader
   else
        dialog \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --infobox "Installer exited because no bootloader was chosen?" \
            0 0
        exit
    fi
}

install_grub_bootloader() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "Install ${BOOTLOADER}?" \
        0 0 || exit
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Installing "${BOOTLOADER}" on ${DRIVE}" \
        0 0
    pacman --noconfirm --needed -S grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
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
    reflector \
        --verbose \
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
set_locale
set_timezone
start_network_manager
install_bootloader
install_dotfiles
