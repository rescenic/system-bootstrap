# Potential variables: timezone, lang and local

# sda
# drive=/dev/sda
# UUID=$(blkid -s PARTUUID -o value /dev/sda3)

pacman --noconfirm --needed -S dialog reflector || { echo "Error at script start: Are you sure you're running this as the root user? Are you sure you have an internet connection?"; exit; }
reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist

# nvme0n1
drive=/dev/nvme0n1
UUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p3)

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

passwd

TZuser=$(cat tzfinal.tmp)

ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime

hwclock --systohc

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

pacman --noconfirm --needed -S networkmanager intel-ucode
systemctl enable NetworkManager
systemctl start NetworkManager

# Bootloader
bootctl install || error "Installing bootctl"
# This assumes ROOT is p3
echo title Arch Linux >> /boot/loader/entries/arch.conf
echo linux /vmlinuz-linux >> /boot/loader/entries/arch.conf
echo initrd /intel-ucode.img >> /boot/loader/entries/arch.conf
echo initrd /initramfs-linux.img >> /boot/loader/entries/arch.conf
echo options root=PARTUUID=${UUID} >> /boot/loader/entries/arch.conf

# cat /boot/loader/entries/arch.conf || error "Couldnt cat /boot/loader/entries/arch.conf"

installdotfiles() { curl -O https://raw.githubusercontent.com/vladdoster/dotfile-installer/master/dotfile-installer.sh && bash dotfile-installer.sh ;}
dialog --title "Install dotfiles?" --yesno "This install script will easily let you access boostrapping scripts which automatically install a full Arch Linux i3-gaps desktop environment.\n\nIf you'd like to install this, select yes, otherwise select no."  15 60 && installdotfiles
