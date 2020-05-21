#!/bin/bash
set -o pipefail   # Unveils hidden failures
 
# require root user
if [ "$(id -u)" != "0" ]; then
   echo "This script requires it be run as root"
   exit 1
fi

echo "Doing preliminary checks..."

ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3` > /dev/null || $(echo "Are you sure there is an active internet connection?" && exit)

pacman -Sy --noconfirm dialog pv reflector >/dev/null 2>&1

clear && clear && clear

################################
# ====== Install script ====== #
################################
# Figure out which drive to install Arch on
printf "Select one of the following drives to install Arch on\n"
lsblk -d -o name | tail -n +2 | awk '{print NR ". " $1}'
read -rp "Full drive name (ex. sda or nvme0n1): " drive
dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "Install Arch on: /dev/${drive}"  7 50 || exit

partition_prefix=$drive
if [[ "$drive" =~ ^nvme ]]; then
    echo "Need to add p for nvme drive partitions"
    partition_prefix=$drive"p"
fi

drive="/dev/${partition_prefix}"

# Alert user about installation drive
dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "Arch will install on ${drive}\nPartitions will start with ${partition_prefix}"  7 50 || exit

dialog --title "Arch installer" --infobox "Updating pacman mirrors..." 3 50
reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null

dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "This is an Arch install script for chads.\nOnly run this script if you're a big-brane who doesn't mind deleting your entire ${drive} drive."  10 50 || exit

dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "Do you think I'm meming? Only select yes to DELET your entire ${drive} and reinstall Arch.\n\nTo stop this script, press no."  7 50 || exit

dialog --no-cancel --inputbox "Enter a name for your computer." 7 50 2> comp

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone"  10 50 && echo "America/New_York" > tz.tmp || tzselect > tz.tmp

dialog --infobox "Setting timedatectl to use ntp \"$name\"..." 7 50
timedatectl set-ntp true

dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 7 50 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 50);
fi

dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "Drive: ${drive}\nSwap: ${SIZE[0]} GiB\nRoot: ${SIZE[1]} GiB\nIs this correct?"  8 30 || exit

dialog --title "Partitions" --infobox "Unmounting any parititons from ${drive}..." 7 50
for i in {1..4}
do
   echo "${drive}${i}"
   umount --force ${drive}${i} >/dev/null 2>&1
done

dialog --title "Clearing previous partitions" --infobox "Wiping all parititons from ${drive}...\n$(dd if=/dev/zero | pv --size | of=${drive} bs=4096; sync)" 6 50


# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can 
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${drive}
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +1G # 1 GiB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
  +${SIZE[0]}G # size user specified, extend partition to end of disk
  n # new partition
  p # primary partition
  3 # partion number 3 
    # default, start immediately after preceding partition
  +${SIZE[1]}G # size user specified, extend partition to end of disk
  n # new partition
  p # primary partition
    # default, start immediately after preceding partition
    # default, extend for rest of drive space
  a # make a partition bootable
  1 # bootable partition is partition 1
  t # set partition type
  2 # partition 2
  19 # SWAP
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

partprobe

# Partition drive
yes | mkfs.ext4 ${drive}4
yes | mkfs.ext4 ${drive}3
yes | mkfs.fat -F32 ${drive}1
mkswap ${drive}2
swapon ${drive}2
mount ${drive}3 /mnt
mkdir -p /mnt/boot
mount ${drive}1 /mnt/boot
mkdir -p /mnt/home
mount ${drive}4 /mnt/home

pacman -Sy --noconfirm archlinux-keyring >/dev/null

# Install Arch
pacstrap /mnt base base-devel linux linux-headers linux-firmware >/dev/null

# Generate FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

# System hostname
mv comp /mnt/etc/hostname

# Enter chroot
curl https://raw.githubusercontent.com/vladdoster/dotfile-installer/master/arch-installer/chroot.sh > /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh "$drive" "$drive"3 && rm /mnt/chroot.sh

dialog --defaultno --title "Final Qs" --yesno "Reboot computer?"  5 30 && reboot
dialog --defaultno --title "Final Qs" --yesno "Return to chroot environment?"  6 30 && arch-chroot /mnt
clear
