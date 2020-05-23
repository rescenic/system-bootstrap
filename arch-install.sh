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
dialog --defaultno --title "Installation drive" --yesno "Install Arch on: /dev/${drive}"  6 50 || exit

partition_prefix=$drive
if [[ "$drive" =~ ^nvme ]]; then
    echo "Need to add p for nvme drive partitions"
    partition_prefix=$drive"p"
fi

drive="/dev/${partition_prefix}"

# Alert user about installation drive
dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "Arch will install on: ${drive}\nPartitions will be on: ${partition_prefix}"  7 50 || exit

dialog --title "Arch install" --infobox "Updating pacman mirrors..." 3 50
reflector --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null

dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "This is an Arch install script for chads.\nOnly run this script if you're a big-brane who doesn't mind deleting your entire ${drive} drive." 9 50 || exit

dialog --no-cancel --inputbox "Enter a name for your computer." 7 50 2> comp
hostname=$(cat comp)

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone"  10 50 && echo "America/New_York" > tz.tmp || tzselect > tz.tmp

dialog --title "Arch install" --infobox "Setting timedatectl to use ntp \"$name\"..." 7 50
timedatectl set-ntp true

dialog --no-cancel --title "Arch install" --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 7 50 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 50);
fi

dialog --defaultno --title "System information" --yesno "Hostname: ${hostname}\nDrive: ${drive}\nSwap: ${SIZE[0]} GiB\nRoot: ${SIZE[1]} GiB\nIs this correct?"  8 30 || exit

dialog --title "Partitions" --infobox "Unmounting any parititons from ${drive}..." 7 50
for i in {1..4}
do
   echo "${drive}${i}"
   umount --force ${drive}${i} >/dev/null 2>&1
done
swapoff -a >/dev/null 2>&1

dialog --title "Clearing previous partitions" --infobox "Wiping all parititons from ${drive}...\n$(dd if=/dev/zero | pv --size | of=${drive} bs=4096; sync)" 6 50

# ================================================================= #
# To create partitions programatically (rather than manually)       #
# we're going to simulate the manual input to gdisk                 #
# The sed script strips off all the comments so that we can         #
# document what we're doing in-line with the actual commands        #
# Note that a blank line (commented as "defualt" will send a empty  #
# line terminated with a newline to take the fdisk default.         #
# ================================================================= #

# -- Clear cruft partitons and make new GPT partition table -- #
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | gdisk ${drive}
  o # clear the in memory partition table
  Y # confirmation
  w # write the partition table
  Y # confirmation
  q # and we're done
EOF

partprobe

# -- Make new partitons -- #
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | gdisk ${drive}
  n # new partition
  1 # 1st partition
    # start at beginning of disk 
  +512M # 512 MiB boot partition
  ef00  # EFI system partition
  n # Linux swap
  2 # 2nd partition
    # start immediately after preceding partition
  +${SIZE[0]}G # user specified size
  8200 # Linux swap
  n # new partition
  3 # 3rd partition
    # start immediately after preceding partition
  +${SIZE[1]}G # user specified size
  8304 # Linux x86-64 root (/)
  n # new partition
  4 # 4th partition
    # start immediately after preceding partition
    # extend for rest of drive space
  8302 # Linux /home
  w # write the partition table
  Y # confirmation
  q # exit gdisk
EOF

partprobe

dialog --title "Arch install" --infobox "Format and mount partitions" 3 50
# Partition file systems
yes | mkfs.fat -F32 ${drive}1
yes | mkfs.ext4 ${drive}3
yes | mkfs.ext4 ${drive}4
# Enable swap
mkswap ${drive}2
swapon ${drive}2
# Mount partitions
mount ${drive}3 /mnt
mkdir -p /mnt/boot
mount ${drive}1 /mnt/boot
mkdir -p /mnt/home
mount ${drive}4 /mnt/home

dialog --title "Arch install" --infobox "Refreshing archlinux-keyring" 3 50
pacman -Sy --noconfirm archlinux-keyring >/dev/null

# Install Arch
dialog --title "Arch install" --infobox "Installing Arch via pacstrap" 7 50
pacstrap /mnt base base-devel linux linux-headers linux-firmware >/dev/null

# Generate FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

# System hostname
mv comp /mnt/etc/hostname

# Enter chroot
curl https://raw.githubusercontent.com/vladdoster/system-installer/master/chroot.sh > /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh "$drive" "$drive"3 && rm /mnt/chroot.sh

dialog --defaultno --title "Install complete" --yesno "Reboot computer?" 3 30 && reboot
dialog --defaultno --title "Install complete" --yesno "Return to chroot environment?" 3 30 && arch-chroot /mnt
clear
