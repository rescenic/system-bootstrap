#!/bin/bash

# --- Error handling --- #
function catch() { \
  # error handling goes here
  error=$(echo "$@")
  dialog --title "Arch install" \
         --no-collapse \
         --msgbox "$error" \
         0 0
  exit
}

function clear_partition_cruft() { \
    dialog --title "Partitions" \
           --infobox "Unmounting any parititons from ${drive}..." \
           0 0
    swapoff -a >/dev/null 2>&1
    for i in {1..4}
    do
       umount --force ${drive}${i} >/dev/null 2>&1
    done
    # ============================================================= #
    # The sed script strips off all the comments so that we can     #
    # document what we're doing in-line with the actual commands    #
    # ============================================================= #
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<- EOF | gdisk ${drive}
		o # clear the in memory partition table
		Y # confirmation
		w # write the partition table
		Y # confirmation
		q # and we're done
	EOF

    update_kernel
}

function confirm_install() { \
dialog --title "DON'T BE A BRAINLET!" \
       --defaultno \
       --yesno "Only run this script if you're a big-brane who doesn't mind deleting your entire ${drive} drive." \
       9 50 || exit
}

function confirm_partition_sizes() { \
    dialog --defaultno \
           --title "System information" \
           --yesno "Hostname: ${hostname}\nDrive: ${drive}\nSwap: ${SIZE[0]} GiB\nRoot: ${SIZE[1]} GiB\nIs this correct?" \
           8 30 || exit
}

function create_partitions() { \
    # ============================================================= #
    # The sed script strips off all the comments so that we can     #
    # document what we're doing in-line with the actual commands    #
    # ============================================================= #
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<- EOF | gdisk ${drive}
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

    update_kernel
}

function create_partition_filesystems() { \
    dialog --title "Arch install" \
           --infobox "Format and mount partitions" \
           0 0
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

    update_kernel
}

function enter_chroot_env() { \
    chroot_url="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/arch-chroot.sh"
    curl "$chroot_url" > /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh "$drive" "$drive"3
}

function generate_fstab() { \
    genfstab -U -p /mnt >> /mnt/etc/fstab
}

function get_hostname() { \
    dialog --no-cancel \
           --inputbox "Enter a name for your computer." \
           7 50 \
           2> comp
    hostname=$(cat comp)
}

function get_partition_sizes() { \
    dialog --no-cancel \
           --title "Arch install" \
           --inputbox "Enter partitionsize in gb, separated by space (swap & root)." \
           0 0 \
           2>psize
    IFS=' ' read -ra SIZE <<< $(cat psize)
    re='^[0-9]+$'
    if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
        SIZE=(12 50);
    fi
}

function get_timezone() { \
    dialog --defaultno \
           --title "Arch install" \
           --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone"  \
           10 50 && \
           echo "America/New_York" > tz.tmp || tzselect > tz.tmp
}

function install_arch() { \
    dialog --title "Arch install" \
           --infobox "Installing Arch via pacstrap" \
           0 0
    pacstrap -i /mnt base base-devel linux linux-headers linux-firmware
}

function ntp_sync() { \
    dialog --title "Arch install" \
           --infobox "Setting timedatectl to use ntp \"$name\"..." \
           0 0
    timedatectl set-ntp true
}

function postinstall_options() { \
    dialog --defaultno \
           --title "Arch install complete" \
           --yesno "Reboot computer?" \
           0 0 && reboot
    dialog --defaultno \
           --title "Arch install complete" \
           --yesno "Return to chroot environment?" \
           0 0 && arch-chroot /mnt
}

function preinstall_checks { \
    if [ "$(id -u)" != "0" ]; then
        catch "This script requires it be run as root"
        exit 1
    fi

    dialog \
      --title "Arch install" \
      --infobox "Doing preliminary checks..." \
      0 0
      msg=$(
          ping -q -w 1 -c 1 $(ip r | grep default | cut -d ' ' -f 3) >/dev/null 2>&1 &&
          pacman -Sy --quiet --noconfirm reflector >/dev/null 2>&1
      )
    [[ -n $msg ]] && catch $msg
}

function refresh_arch_keyring() { \
    dialog --title "Arch install" \
           --infobox "Refreshing archlinux-keyring" \
           0 0
    pacman -Sy --noconfirm archlinux-keyring
}

function run_reflector() { \
    dialog --title "Arch install" \
           --infobox "Updating pacman mirrors..." \
           0 0
    reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null
}

function select_install_drive() { \
    drives=()
    drives+=($(lsblk -d -o name | tail -n +2 | awk '{print NR " " $1}'))
    selection=$(dialog \
      --menu "Please select:" 0 0 0 \
      "${drives[@]}" 2>&1 > /dev/tty)

    drive=$(lsblk -d -o name | tail -n +2 | awk -v var="$selection" 'NR==var {print $1}')

    # -- Confirm drive choice -- #
    dialog --defaultno \
           --title "Arch install" \
           --yesno "Install Arch on: /dev/${drive}" \
           6 50 || exit
    partition_prefix=$drive
    if [[ "$drive" =~ ^nvme ]]; then
        echo "Need to add p for nvme drive partitions"
        partition_prefix=$drive"p"
    fi
    drive="/dev/${partition_prefix}"
}

function set_hostname() { \
    mv comp /mnt/etc/hostname
}

function set_timezone() { \
    cat tz.tmp > /mnt/tzfinal.tmp
    rm tz.tmp
}

function update_kernel() { \
    partprobe
}


################################
#        Install script        #
################################
preinstall_checks

select_install_drive

confirm_install

run_reflector

get_hostname

get_timezone

ntp_sync

get_partition_sizes

confirm_partition_sizes

clear_partition_cruft

create_partitions

create_partition_filesystems

refresh_arch_keyring

install_arch

generate_fstab

set_timezone

set_hostname

enter_chroot_env

postinstall_options

clear
