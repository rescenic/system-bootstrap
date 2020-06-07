#!/bin/bash
# ====================================================== #
# arch-chroot.sh                                         #
# Released by: Vlad Doster <vlad_doster@hms.harvard.edu> #
# License: GNU GPLv3                                     #
# ====================================================== #
# ====== Variables ====== #
BACKTITLE="System bootstrap"
TITLE="Arch chroot"
BOOTLOADER_PARTITION="$2"
BOOTLOADER=$3
DRIVE="$1"
NUM_EXPECTED_ARGS=3
NUM_ARGS="$#"
DOTFILES_INSTALLER_URL="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/dotfiles-installer.sh"
# ======================= #
#     Dialog functions    #
# ======================= #
function display_info_box {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "$1" \
        0 0
}

function display_yes_no_box {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "$1" \
        0 0 || exit
    return
}
# ======================= #
#   Installer functions   #
# ======================= #
function preinstall_setup {
    pacman --noconfirm -Sy  dialog
    if [ "$NUM_ARGS" -ne "$NUM_EXPECTED_ARGS" ]; then
        display_info_box "Chroot expected $NUM_EXPECTED_ARGS args, but got $#"
        exit 1
    fi
    display_info_box "Setting up installation dependencies"
    pacman --noconfirm -Sy intel-ucode reflector networkmanager
}

function install_bootctl_bootloader {
    UUID=$(blkid -s PARTUUID -o value "${BOOTLOADER_PARTITION}")
    display_yes_no_box "Install Bootctl on ${BOOTLOADER_PARTITION} with UUID ${UUID}?"
    display_info_box "Installing bootctl on ${BOOTLOADER_PARTITION} with UUID ${UUID}"
    bootctl install || echo "Bootctl seemed to hit a snag..."
    {
        echo title Arch Linux
        echo linux /vmlinuz-linux
        echo initrd /intel-ucode.img
        echo initrd /initramfs-linux.img
        echo options root=PARTUUID="${UUID}"
    } >> /boot/loader/entries/arch.conf
}

function install_system_bootloader {
    if [ "$BOOTLOADER" = "grub" ]; then
        install_grub_bootloader
    elif [ "$BOOTLOADER" = "bootctl" ]; then
        install_bootctl_bootloader
    else
        display_info_box "Installer exited because no bootloader was chosen?"
        exit
    fi
}

function install_grub_bootloader {
    display_yes_no_box "Install "${BOOTLOADER}" on ${DRIVE}?"
    display_info_box "Installing "${BOOTLOADER}" on ${DRIVE}"
    pacman --noconfirm --needed -S grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
}

function install_user_dotfiles {
    display_yes_no_box "Install dotfiles"
    curl -O "${DOTFILES_INSTALLER_URL}"
    sudo bash dotfiles-installer.sh
}

function set_root_password {
    echo "root:${r_passwd}" | chpasswd
    display_info_box "Successfully set root password to ${r_passwd}"
    sleep 10
}

function set_sytem_timezone {
    display_info_box "Synchronizing hardware clock"
    TZuser=$(cat tzfinal.tmp)
    ln -sf /usr/share/zoneinfo/"$TZuser" /etc/localtime
    hwclock --systohc
}

function set_system_locale {
    display_info_box "Setting locale"
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    {
        echo "en_US.UTF-8 UTF-8"
        echo "en_US ISO-8859-1"
    } > /etc/locale.gen
    locale-gen
}

function start_network_manager {
    display_info_box "Starting NetworkManager"
    systemctl enable NetworkManager
    systemctl start NetworkManager
}

function run_reflector {
    reflector --latest 1000 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}
# ============================ #
#            Install           #
# ============================ #
{
preinstall_setup
run_reflector
set_root_password
set_system_locale
set_system_timezone
start_network_manager
install_system_bootloader
install_user_dotfiles
} >/dev/null
