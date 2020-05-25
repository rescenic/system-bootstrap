#!/bin/bash
set -o pipefail   # Unveils hidden failures
 
# --- Error handling --- #
catch() {
  # error handling goes here
  error=$(echo "$@")
  dialog \
    --backtitle "$TITLE" \
    --title "$TITLE Error" \
    --no-collapse \
    --msgbox "$error" 0 0
  exit
}

# -- Require root user -- #
if [ "$(id -u)" != "0" ]; then
   catch "This script requires it be run as root"
   exit 1
fi

# -- Check internet connection -- #
dialog \
  --title "$TITLE" \
  --infobox "Doing preliminary checks..." 0 0
  msg=$(
      ping -q -w 1 -c 1 $(ip r | grep default | cut -d ' ' -f 3) >/dev/null 2>&1 &&
      pacman -Sy --quiet --noconfirm reflector >/dev/null 2>&1
  )
[[ -n $msg ]] && catch $msg  
# ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3` > /dev/null || $(echo "Are you sure there is an active internet connection?" && exit)
# pacman -Sy --noconfirm dialog reflector >/dev/null 2>&1

################################
#        Install script        #
################################

# -- Set drive to install on -- #
drives=()
drives+=($(lsblk -d -o name | tail -n +2 | awk '{print NR " " $1}'))
dialog \
  --title "Drive selection" \
  --menu "Select one of the following drives to install Arch on" 0 0 0 \
  "${drives[@]}"  2>"${drive}"
drive=$(<"${drive}")

# -- Confirm drive choice -- #
dialog --defaultno --title "Installation drive" --yesno "Install Arch on: /dev/${drive}"  6 50 || exit
partition_prefix=$drive
if [[ "$drive" =~ ^nvme ]]; then
    echo "Need to add p for nvme drive partitions"
    partition_prefix=$drive"p"
fi
drive="/dev/${partition_prefix}"

# -- Confirm drive choice again -- #
dialog --defaultno --title "DON'T BE A BRAINLET!" --yesno "This is an Arch install script for chads.\nOnly run this script if you're a big-brane who doesn't mind deleting your entire ${drive} drive." 9 50 || exit

# -- Set fast Pacman mirrors -- #
dialog --title "Arch install" --infobox "Updating pacman mirrors..." 3 50
reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null

# -- Get hostname -- #
dialog --no-cancel --inputbox "Enter a name for your computer." 7 50 2> comp
hostname=$(cat comp)

# -- Get timezone -- #
dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone"  10 50 && echo "America/New_York" > tz.tmp || tzselect > tz.tmp

# -- Sync w/ NTP -- #
dialog --title "Arch install" --infobox "Setting timedatectl to use ntp \"$name\"..." 7 50
timedatectl set-ntp true

# -- Read in/sanity check user swap/root partition sizes -- #
dialog --no-cancel --title "Arch install" --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 7 50 2>psize
IFS=' ' read -ra SIZE <<< $(cat psize)
re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 50);
fi

# -- One last chance to quit -- #
dialog --defaultno --title "System information" --yesno "Hostname: ${hostname}\nDrive: ${drive}\nSwap: ${SIZE[0]} GiB\nRoot: ${SIZE[1]} GiB\nIs this correct?"  8 30 || exit

# ============================================================= #
# To create partitions programatically (rather than manually)   #
# simulate the manual input to gdisk.                           #
# The sed script strips off all the comments so that we can     #
# document what we're doing in-line with the actual commands    #
# ============================================================= #

# -- Clear cruft partitions and make GPT partition table -- #
dialog --title "Partitions" --infobox "Unmounting any parititons from ${drive}..." 7 50
for i in {1..4}
do
   echo "${drive}${i}"
   umount --force ${drive}${i} >/dev/null 2>&1
done
swapoff -a >/dev/null 2>&1
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | gdisk ${drive}
  o # clear the in memory partition table
  Y # confirmation
  w # write the partition table
  Y # confirmation
  q # and we're done
EOF

# -- Update kernel --#
partprobe

# -- Make new partitions -- #
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
  w # write GPT partition table
  Y # confirmation
  q # exit gdisk
EOF

# -- Update kernel --#
partprobe

# -- Create partition file systems -- #
dialog --title "Arch install" --infobox "Format and mount partitions" 3 50
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

# -- Refresh Arch keyring -- #
dialog --title "Arch install" --infobox "Refreshing archlinux-keyring" 3 50
pacman -Sy --noconfirm archlinux-keyring >/dev/null 2>&1

# -- Install Arch -- #
dialog --title "Arch install" --infobox "Installing Arch via pacstrap" 3 50
pacstrap /mnt base base-devel linux linux-headers linux-firmware >/dev/null 2>&1

# -- Generate FSTAB -- #
genfstab -U /mnt >> /mnt/etc/fstab
# -- Set timezone -- #

# -- Set timezone -- #
cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

# -- Set system hostname -- #
mv comp /mnt/etc/hostname

# -- Enter chroot environment -- #
curl https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/arch-chroot.sh > /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh "$drive" "$drive"3 && rm /mnt/chroot.sh

# -- Post install user options -- #
dialog --defaultno --title "Install complete" --yesno "Reboot computer?" 3 30 && reboot
dialog --defaultno --title "Install complete" --yesno "Return to chroot environment?" 3 30 && arch-chroot /mnt
clear
