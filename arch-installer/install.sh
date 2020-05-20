#!/bin/bash
set -o pipefail   # Unveils hidden failures

# This is a lazy script I have for auto-installing Arch.
# which means RIP in peace qq your data unless you've already backed up all of your drive.

# This is single place to change drive prefix for whole script
# Don't forget to change it in chroot.sh as well

# Figure out which drive to install Arch on
printf "Select one of the following drives to install Arch on\n"
lsblk -d -o name | tail -n +2 | awk '{print NR ". " $1}'
read -rp "Drive: " drive
printf "Selected %s drive to install Arch on, is this correct?\n" $drive
read -p "Enter [Y/n] : " user_confirmation
if [[ "$user_confirmation" == "Y" ]]; then
    printf "Setting drive to %s for Arch install" $drive
    if [[ "$drive" =~ ^nvme ]]; then
        echo "Need to make add p for nvme drive partitions"
        drive_partition_prefix=$drive"p"
    else
        drive_partition_prefix=$drive
fi
else
    echo "Exiting install script"
    exit 0
fi

# Alert user about installation drive
echo "Arch will install on $drive and partitions will start with $drive_partition_prefix"

# #---Install script---# #
pacman -Sy --noconfirm dialog reflector || { echo "Error at script start: Are you sure you're running this as the root user? Are you sure you have an internet connection?"; exit; }

reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null

dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "This is an Arch install script that is very rough around the edges.\n\nOnly run this script if you're a big-brane who doesn't mind deleting your entire $drive drive.\n\nThis script is only really for me so I can autoinstall Arch."  15 60 || exit

dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "Do you think I'm meming? Only select yes to DELET your entire ${drive} and reinstall Arch.\n\nTo stop this script, press no."  10 60 || exit

dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> comp

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone"  10 60 && echo "America/New_York" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 50);
fi

timedatectl set-ntp true
# PARTITIONS
# Assuming there are no partitons yet!
# ----------------------------
cat <<EOF | fdisk $drive
n
p


+1G
n
p


+${SIZE[0]}G
n
p


+${SIZE[1]}G
n
p



t
1
1
t
2
19
w
p
EOF
# ----------------------------
partprobe

# Partition drive
yes | mkfs.ext4 ${drive_partition_prefix}4
yes | mkfs.ext4 ${drive_partition_prefix}3
yes | mkfs.fat -F32 ${drive_partition_prefix}1
mkswap ${drive_partition_prefix}2
swapon ${drive_partition_prefix}2
mount ${drive_partition_prefix}3 /mnt
mkdir -p /mnt/boot
mount ${drive_partition_prefix}1 /mnt/boot
mkdir -p /mnt/home
mount ${drive_partition_prefix}4 /mnt/home

pacman -Sy --noconfirm archlinux-keyring

# Install Arch
pacstrap /mnt base base-devel linux linux-headers linux-firmware

# Generate FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp
mv comp /mnt/etc/hostname
curl https://raw.githubusercontent.com/vladdoster/dotfile-installer/master/arch-installer/chroot.sh > /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh

dialog --defaultno --title "Final Qs" --yesno "Reboot computer?"  5 30 && reboot
dialog --defaultno --title "Final Qs" --yesno "Return to chroot environment?"  6 30 && arch-chroot /mnt
clear
