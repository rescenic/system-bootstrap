#!/bin/bash

BACKTITLE="Arch installer"
TITLE="Arch install"

clear_partition_cruft() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Unmounting any parititons from ${drive}..." \
        0 0
    swapoff -a > /dev/null 2>&1
    for i in {1..4}; do
        umount --force "${drive}""${i}" > /dev/null 2>&1
    done
    # ============================================================= #
    # The sed script strips off all the comments so that we can     #
    # document what we're doing in-line with the actual commands    #
    # ============================================================= #
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<- EOF | gdisk "${drive}"
		o # clear the in memory partition table
		Y # confirmation
		w # write the partition table
		Y # confirmation
		q # exit gdisk
	EOF

    update_kernel
}

confirm_bootloader() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "User chose $bootloader so gdisk is using\n$create_partition_cmd" \
        0 0 || exit
}

confirm_install() {
    dialog \
        --title "DON'T BE A BRAINLET!" \
        --defaultno \
        --yesno "Only run this script if you're a big-brane who doesn't mind deleting your entire ${drive} drive." \
        0 0 || exit
}

confirm_partition_sizes() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "Hostname: ${hostname}\nDrive: ${drive}\nSwap: ${SIZE[0]} GiB\nRoot: ${SIZE[1]} GiB\nIs this correct?" \
        0 0 || exit
}

select_bootloader() {
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
            bootloader="grub"
	    create_partition_cmd="sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/'"
        fi
        if [ "$_return" = "2" ]; then
            bootloader="bootctl"
	    create_partition_cmd="sed -e '/grub/d' -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/'"
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

create_partitions() {
    # ============================================================= #
    # The sed script strips off all the comments so that we can     #
    # document what we're doing in-line with the actual commands    #
    # ============================================================= #
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "User chose $bootloader so gdisk is using\n$create_partition_cmd" \
        0 0
    eval "$create_partition_cmd" <<- EOF | gdisk "${drive}"
		n # grub partition
		  # default number (grub)
		# start at beginning of disk (grub)
		+1M # 1 MiB partition (grub)
		ef02 # (grub)
		n # new partition
		  # 1st partition
		# start at beginning of disk
		+512M # 512 MiB boot partition
		ef00  # EFI system partition
		n # Linux swap
		 # 2nd partition
		# start immediately after preceding partition
		+${SIZE[0]}G # user specified size
		8200 # Linux swap
		n # new partition
		 # 3rd partition
		# start immediately after preceding partition
		+${SIZE[1]}G # user specified size
		8304 # Linux x86-64 root (/)
		n # new partition
		 # 4th partition
		# start immediately after preceding partition
		# extend for rest of drive space
		8302 # Linux /home
		w # write GPT partition table
		Y # confirmation
		q # exit gdisk
	EOF

    update_kernel
}

create_partition_filesystems() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Format and mount partitions" \
        0 0
    yes | mkfs.fat -F32 "${drive}"1
    yes | mkfs.ext4 "${drive}"3
    yes | mkfs.ext4 "${drive}"4
    # Enable swap
    mkswap "${drive}"2
    swapon "${drive}"2
    # Mount partitions
    mount "${drive}"3 /mnt
    mkdir -p /mnt/boot
    mount "${drive}"1 /mnt/boot
    mkdir -p /mnt/home
    mount "${drive}"4 /mnt/home

    update_kernel
}

enter_chroot_env() {
    chroot_url="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/arch-chroot.sh"
    curl "$chroot_url" > /mnt/chroot.sh
    arch-chroot /mnt bash chroot.sh "$drive" "$drive"3 $bootloader
}

error() {
    # error handling goes here
    error=$(echo "$@")
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-collapse \
        --msgbox "$error" \
        0 0
    exit
}

generate_fstab() {
    genfstab -U -p /mnt > /mnt/etc/fstab
}

get_hostname() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-cancel \
        --inputbox "Enter a name for your computer." \
        0 0 \
        2> comp
    hostname=$(cat comp)
}

get_partition_sizes() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-cancel \
        --inputbox "Enter partitionsize in gb, separated by space (swap & root)." \
        0 0 \
        2> psize
    IFS=' ' read -ra SIZE <<< $(cat psize)
    re='^[0-9]+$'
    if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]]; then
        SIZE=(12 50)
    fi
}

get_timezone() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone" \
        0 0 &&
        echo "America/New_York" > tz.tmp || tzselect > tz.tmp
}

install_arch() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Installing Arch via pacstrap" \
        0 0
    yes " " | pacstrap -i /mnt base base-devel linux linux-headers linux-firmware
}

ntp_sync() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Setting timedatectl to use ntp..." \
        0 0
    timedatectl set-ntp true
}

postinstall_options() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "Reboot computer?" \
        0 0 && reboot
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "Return to chroot environment?" \
        0 0 && arch-chroot /mnt
}

preinstall_checks() {
    if [ "$(id -u)" != "0" ]; then
        error "This script requires it be run as root"
        exit 1
    fi

    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Doing preliminary checks..." \
        0 0
    msg=$(
        ping -q -w 1 -c 1 $(ip r | grep default | cut -d ' ' -f 3) > /dev/null 2>&1 &&
            pacman -Sy --quiet --noconfirm reflector > /dev/null 2>&1
    )
    [[ -n $msg ]] && error "$msg"
}

refresh_arch_keyring() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Refreshing archlinux-keyring" \
        0 0
    pacman -Sy --noconfirm archlinux-keyring
}

run_reflector() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "Updating pacman mirrors..." \
        0 0
    reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null
}

select_install_drive() {
    drives=()
    drives+=($(lsblk -d -o name | tail -n +2 | awk '{print NR " " $1}'))
    selection=$(
        dialog \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --menu "Please select:" 0 0 0 \
            "${drives[@]}" 2>&1 > /dev/tty
    )
    drive=$(lsblk -d -o name | tail -n +2 | awk -v var="$selection" 'NR==var {print $1}')
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --defaultno \
        --yesno "Install Arch on: /dev/${drive}" \
        0 0 || exit
    partition_prefix=$drive
    if [[ $drive =~ ^nvme ]]; then
        echo "Need to add p for nvme drive partitions"
        partition_prefix=$drive"p"
    fi
    drive="/dev/${partition_prefix}"
}

set_hostname() {
    mv comp /mnt/etc/hostname
}

set_timezone() {
    cat tz.tmp > /mnt/tzfinal.tmp
    rm tz.tmp
}

set_root_password() {
    root_password=$(
        dialog \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --no-cancel \
            --passwordbox "Enter a root password." \
            0 0 \
            3>&1 1>&2 2>&3 3>&1
    )
    root_password_confirm=$(
        dialog \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --no-cancel \
            --passwordbox "Retype password." \
            0 0 \
            3>&1 1>&2 2>&3 3>&1
    )

    while true; do
        [[ $root_password != "" && $root_password == "$root_password_confirm" ]] && break
        root_password=$(
            dialog \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --no-cancel \
                --passwordbox "Passwords do not match or are not present.\n\nEnter password again." \
                0 0 \
                3>&1 1>&2 2>&3 3>&1
        )
        root_password_confirm=$(
            dialog \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --no-cancel \
                --passwordbox "Retype password." \
                0 0 \
                3>&1 1>&2 2>&3 3>&1
        )
    done
    arch-chroot /mnt echo "root:$root_password" | chpasswd
}

update_kernel() {
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
select_bootloader
confirm_bootloader
get_partition_sizes
confirm_partition_sizes
clear_partition_cruft
create_partitions
create_partition_filesystems
refresh_arch_keyring
generate_fstab
install_arch
set_timezone
set_hostname
set_root_password
enter_chroot_env
postinstall_options
clear
