#!/bin/bash
# ====================================================== #
# arch-installer.sh                                      #
# Released by: Vlad Doster <vlad_doster@hms.harvard.edu> #
# License: GNU GPLv3                                     #
# ====================================================== #
# ====== Variables ====== #
BACKTITLE="System bootstrap"
TITLE="Arch install"
CHROOT_URL="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/arch-chroot.sh"
# ======================= #
#       Dialog boxes      #
# ======================= #
display_info_box() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "$1" \
        0 0
}

display_password_input() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-cancel \
        --passwordbox "$1" \
        0 0 \
        3>&1 1>&2 2>&3 3>&1
}

display_yes_no_box() {
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
clean_partition_cruft() {
    display_info_box "Unmounting any parititons from ${drive}..."
    swapoff -a > /dev/null 2>&1
    for i in {1..5}; do
        umount --force "${drive}""${i}" || true
    done
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<- EOF | gdisk "${drive}"
		o # clear the in memory partition table
		Y # confirmation
		w # write the partition table
		Y # confirmation
		q # exit gdisk
	EOF
    update_kernel
}

create_partitions() {
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
    display_yes_no_box "Does this look correct?
            		\nBoot: ${drive}${boot_partition}
		        \nSwap: ${drive}${swap_partition}
		        \nRoot: ${drive}${root_partition}
		        \nUser: ${drive}${user_partition}"
    yes | mkfs.fat -F32 "${drive}""${boot_partition}"
    yes | mkfs.ext4 "${drive}""${root_partition}"
    yes | mkfs.ext4 "${drive}""${user_partition}"
    # Enable swap
    mkswap "${drive}""${swap_partition}"
    swapon "${drive}""${swap_partition}"
    # Mount partitions
    mount "${drive}""${root_partition}" /mnt
    mkdir -p /mnt/boot
    mount "${drive}""${boot_partition}" /mnt/boot
    mkdir -p /mnt/home
    mount "${drive}""${user_partition}" /mnt/home
    update_kernel
}

enter_chroot_environment() {
    display_info_box "Preparing to enter chroot environment"
    curl "$CHROOT_URL" > /mnt/chroot.sh &&
    arch-chroot /mnt bash chroot.sh \
        "${drive}" \
        "${drive}${boot_partition}" \
        "${bootloader}"
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
    display_info_box "Generating fstab..."
    genfstab -pU /mnt > /mnt/etc/fstab
}

install_arch() {
    display_info_box "Installing Arch via pacstrap"
    yes " " | pacstrap -i /mnt base base-devel linux linux-firmware linux-headers
}

ntp_sync() {
    display_info_box "Setting timedatectl to use ntp..."
    timedatectl set-ntp true > /dev/null 2>&1
}

preinstall_system_checks() {
    display_info_box "Performing system checks..."
    [[ "$(id -u)" != "0" ]] && error "This script requires be run as root"
    msg=$(
        {
            ping -q -w 1 -c 1 "$(ip r | grep default | cut -d ' ' -f 3)"
            pacman -Sy --quiet --noconfirm reflector
        } > /dev/null 2>&1
    )
    [[ -n $msg ]] && error "$msg"
}

refresh_arch_keyring() {
    display_info_box "Refreshing archlinux-keyring"
    pacman -Sy --quiet --noconfirm archlinux-keyring > /dev/null 2>&1
}

run_reflector() {
    display_info_box "Updating pacman mirrors..."
    reflector \
        --verbose \
        --latest 200 \
        --sort rate \
        --save /etc/pacman.d/mirrorlist > /dev/null 2>&1
}

set_hostname() {
    display_info_box "Setting hostname"
    mv comp /mnt/etc/hostname
}

set_root_password() {
    echo "root:$1" | arch-chroot /mnt chpasswd || error "Couldn't set root password to $1"
    display_info_box "Set root password to $1"
    sleep 5 
}

set_timezone() {
    display_info_box "Setting timezone"
    cat tz.tmp > /mnt/tzfinal.tmp
    rm tz.tmp
}

update_kernel() {
    display_info_box "Updating kernel"
    partprobe > /dev/null 2>&1
}

# ======================== #
#   User input functions   #
# ======================== #
user_confirm_bootloader() {
    display_yes_no_box "User chose $bootloader so gdisk is using\n$create_partition_cmd"
}

user_confirm_install() {
    display_yes_no_box "Continue only if you're a big-brane who doesn't mind deleting your entire ${drive} drive."
}

user_confirm_partition_sizes() {
    display_yes_no_box "Hostname: ${hostname}\nDrive: ${drive}\nSwap: ${SIZE[0]} GiB\nRoot: ${SIZE[1]} GiB\nIs this correct?"
}

user_postinstall_options() {
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

user_select_bootloader() {
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
            boot_partition=2
            swap_partition=3
            root_partition=4
            user_partition=5
        elif [ "$_return" = "2" ]; then
            bootloader="bootctl"
            create_partition_cmd="sed -e '/grub/d' -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/'"
            boot_partition=1
            swap_partition=2
            root_partition=3
            user_partition=4
        fi
    else
        display_info_box "Installer exited because no bootloader was chosen."
        rm -f temp
        exit
    fi
    rm -f temp
}

user_select_hostname() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-cancel \
        --inputbox "Enter a name for your computer." \
        0 0 \
        2> comp
    hostname=$(cat comp)
}

user_select_install_drive() {
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
    display_yes_no_box "Install Arch on: /dev/${drive}?"
    partition_prefix=$drive
    [[ $drive =~ ^nvme ]] && partition_prefix="${drive}p"
    drive="/dev/${partition_prefix}"
}

user_select_partition_sizes() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-cancel \
        --inputbox "Enter partitionsize in gb, separated by space (swap & root)." \
        0 0 \
        2> psize
    IFS=' ' read -ra SIZE <<< "$(cat psize)"
    re='^[0-9]+$'
    if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]]; then
        SIZE=(2 10)
    fi
}

user_select_timezone() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "Use default time zone(America/New_York)?
                \nPress no to select a time zone" \
        0 0 && echo "America/New_York" > tz.tmp ||
        tzselect > tz.tmp
}

user_select_root_password() {
    r_passwd=$(
        display_password_input "Enter root password"

    )
    confirm_r_passwd=$(
        display_password_input "Confirm root password"
    )

    while true; do
        [[ $r_passwd != "" && $r_passwd == "$confirm_r_passwd" ]] && break
        r_passwd=$(
	    display_password_input "Passwords do not match or are not present.\n\nEnter root password again"
        )
        confirm_r_passwd=$(
            display_password_input "Confirm root password"
        )
    done
    export r_passwd="$r_passwd" 
}
# ================= #
#   Install steps   #
# ================= #
preinstall_system_checks
user_select_install_drive
user_confirm_install
run_reflector
user_select_hostname
user_select_timezone
ntp_sync
user_select_bootloader
user_confirm_bootloader
user_select_partition_sizes
user_confirm_partition_sizes
clean_partition_cruft
create_partitions
create_partition_filesystems
refresh_arch_keyring
generate_fstab
install_arch
set_timezone
set_hostname
user_select_root_password
enter_chroot_environment
user_postinstall_options
