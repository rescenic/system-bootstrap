# Potential variables: timezone, lang and local
if [ $# -ne 2 ]; then
    dialog --title "BOOMER BRAINLET" --infobox "Something went wrong. Chroot did not receive 2 arguments.\It needs the drive and the bootloader partition." 7 50
    exit 1
fi

drive="$1"
bootloader_partition="$2"

dialog --title "Dotfile installer" --infobox "Arch was installed on: ${drive}" 7 50
sleep 10

dialog --title "Dotfile installer" --infobox "Installing bootloader on ${bootloader_partition}" 7 50
pacman --noconfirm --needed -S intel-ucode
UUID=$(blkid -s PARTUUID -o value ${bootloader_partition})
bootctl install || error "Installing bootctl"
echo title Arch Linux >> /boot/loader/entries/arch.conf
echo linux /vmlinuz-linux >> /boot/loader/entries/arch.conf
echo initrd /intel-ucode.img >> /boot/loader/entries/arch.conf
echo initrd /initramfs-linux.img >> /boot/loader/entries/arch.conf
echo options root=PARTUUID=${UUID} >> /boot/loader/entries/arch.conf

pacman --noconfirm --needed -S dialog reflector || { echo "Error at script start: Are you sure you're running this as the root user? Are you sure you have an internet connection?"; exit; }
dialog --title "Dotfile installer" --infobox "Installing and running \`reflector\` for fastest possible download speeds." 5 70
reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null
clear

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

# System password
passwd

# System timezone
TZuser=$(cat tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
hwclock --systohc

# System locale
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

pacman --noconfirm --needed -S networkmanager intel-ucode
systemctl enable NetworkManager
systemctl start NetworkManager

installdotfiles() { curl -O https://raw.githubusercontent.com/vladdoster/dotfile-installer/master/dotfile-installer.sh && bash dotfile-installer.sh ;}
dialog --title "Install dotfiles?" --yesno "This install script will easily let you access boostrapping scripts which automatically install a full Arch Linux i3-gaps desktop environment.\n\nIf you'd like to install this, select yes, otherwise select no."  15 60 && installdotfiles
