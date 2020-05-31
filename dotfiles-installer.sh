#!/bin/bash
# ====================================================== #
# dotfiles-installer.sh                                  #
# Released by: Vlad Doster <vlad_doster@hms.harvard.edu> #
# License: GNU GPLv3                                     #
# ====================================================== #
# ====== Variables ====== #
BACKTITLE="System bootstrap"
TITLE="Configuration files installer"
USER_PROGRAMS_PARSE_PATTERN='"^[PGA]*,"'
# ======================= #
#       Dialog boxes      #
# ======================= #
display_input_box() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --no-cancel \
        --inputbox "$1" \
        0 0 \
        3>&1 1>&2 2>&3 3>&1
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
# ======================= #
#   Installer functions   #
# ======================= #
add_dotfiles() {
    display_info_box "Installing $name's dotfiles"
    git_pkg_clone "$dotfiles_repo" "/home/$name" "$repo_branch"
    rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/.bash*"
    cd /home/"$name" &&
        git update-index --assume-unchanged "/home/$name/LICENSE" &&
        git update-index --assume-unchanged "/home/$name/README.md"
}

aur_pkg_install() {
    display_info_box "Installing \`$1\` from the AUR\n($n of $total)"
    echo "$aurinstalled" | grep "^$1$" > /dev/null 2>&1 && return
    sudo -u "$name" "$aur_helper" -S --noconfirm "$1" > /dev/null 2>&1
}

# clean_installed_packages() {
#   dialog --title "WARNING!" --yesno "Are you sure you want to clean the system of all non-essential packages?" 0 0
#   response=$?
#   case $response in
#     0)
#       # mark all packages as dependencies using command
#       pacman -D --asdeps "$(pacman -Qe)"
#       pacman -S --asexplicit --needed base linux linux-firmware
#       pacman -Rsunc "$(pacman -Qtdq)"
#       ;;
#     1)
#       return
#       ;;
#   esac
# }

create_user_dirs() {
    mkdir -p /home/"${name}"/github
    mkdir -p /home/"${name}"/downloads
}

display_info_box() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --infobox "$1" \
        0 0
}

enable_docker() {
    # https://docs.docker.com/install/linux/linux-postinstall/
    systemctl enable docker.service
    systemctl start docker.service
    usermod -aG docker "$USER"
}

error() {
    clear
    printf 'ERROR:\n%s\n' "$1"
    exit
}

get_user_credentials() {
    # Prompts user for new username and password.
    name=$(display_input_box "First, please enter a name for the user account.") || exit
    while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" > /dev/null 2>&1; do
        name=$(display_input_box  "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _.")
    done
    user_passwd=$(display_password_input "Enter a password for that user.")
    confirm_user_passwd=$(display_password_input "Retype password.")
    while ! [ "$user_passwd" = "$confirm_user_passwd" ]; do
        unset confirm_user_passwd
        user_passwd=$(display_password_input "Passwords do not match.\n\nEnter password again")
        confirm_user_passwd=$(display_password_input "Retype password.")
    done
}

git_pkg_clone() {
    display_info_box "Downloading configuration files"
    [ -z "$3" ] && branch="master" || branch="$repo_branch"
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown -R "$name":wheel "$dir" "$2"
    sudo -u "$name" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" > /dev/null 2>&1
    sudo -u "$name" cp -rfT "$dir" "$2"
}

git_pkg_install() {
    progname="$(basename "$1")"
    dir="$repodir/$progname"
    display_info_box "Installing: \`$progname\` via \`git\` and \`make\`\n($n of $total)"
    sudo -u "$name" git clone --depth 1 "$1" "$dir" > /dev/null 2>&1 || {
        cd "$dir" || return
        sudo -u "$name" git pull --force origin master
    }
    cd "$dir" || exit
    make > /dev/null 2>&1
    make install > /dev/null 2>&1
    cd /tmp || return
}

install_dependencies() {
    display_info_box "Installing dependencies for installation"
    $(
        install_pkg dialog
        install_pkg curl
        install_pkg base-devel
        install_pkg git
        install_pkg ntp
    ) > /dev/null 2>&1
}

install_user_programs() {
    ([ -f "$user_programs_file" ] &&
        cp "$user_programs_file" /tmp/programs.csv) ||
        curl -Ls "$user_programs_file" | sed '/^#/d' | eval grep "$USER_PROGRAMS_PARSE_PATTERN" > /tmp/programs.csv
    total=$(wc -l < /tmp/programs.csv)
    aurinstalled=$(pacman -Qqm)
    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        echo "$comment" | grep "^\".*\"$" > /dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "A") aur_pkg_install "$program" "$comment" ;;
            "G") git_pkg_install "$program" "$comment" ;;
            "P") pip_pkg_install "$program" "$comment" ;;
            *) official_arch_pkg_install "$program" "$comment" ;;
        esac
    done < /tmp/programs.csv
}

install_nvim_plugins() {
    display_info_box "Installing Neovim plugins"
    nvim +PlugInstall +qall > /dev/null 2>&1
}

install_pkg() {
    pacman --noconfirm --needed -S "$1" > /dev/null 2>&1
}

official_arch_pkg_install() {
    display_info_box "Installing \`$1\`\n($n of $total)"
    install_pkg "$1"
}

manual_install() {
    [ -f "/usr/bin/$1" ] || (
        display_info_box "Installing \"$1\", an AUR helper..."
        cd /tmp || exit
        rm -rf /tmp/"$1"*
        curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
            sudo -u "$name" tar -xvf "$1".tar.gz > /dev/null 2>&1 &&
            cd "$1" &&
            sudo -u "$name" makepkg --noconfirm -si > /dev/null 2>&1
        cd /tmp || return
    )
}

pip_pkg_install() {
    display_info_box "Installing Python package \`$1\`\n($n of $total)"
    command -v pip || install_pkg python-pip > /dev/null 2>&1
    yes | pip install "$1"
}

set_postinstall_settings() {
    # Zsh is default shell
    #sed -i "s/^$name:\(.*\):\/bin\/.*/$name:\1:\/bin\/zsh/" /etc/passwd
    chsh -s /bin/zsh $name >/dev/null 2>&1
    sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
    # Allows user to execute `shutdown`, `reboot`, updating, etc. without password
    set_permissions "%wheel ALL=(ALL) ALL #dotfile-installer
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/nmtui,/usr/bin/pycharm"
    enable_docker || error "Couldn't enable docker."
    install_nvim_plugins || error "Couldn't install nvim plugins"
    start_pulse_audio_daemon || error "Couldn't start Pulse audio daemon"
    yes | sudo -u "$name" "$aur_helper" -S libxft-bgra > /dev/null 2>&1
    system_beep_off || error "Couldn't turn off system beep, erghh!"
    create_user_dirs || error "Couldn't make github  or downloads dir."
}

set_preinstall_settings() {
    display_info_box "Synchronizing system time to ensure successful and secure installation of software..."
    # synchronize NTP
    ntp 0.us.pool.ntp.org > /dev/null 2>&1
    [ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers
    # create fakeroot environment
    set_permissions "%wheel ALL=(ALL) NOPASSWD: ALL"
    # make pacman/yay colorful and add eye candy to progress bar
    grep "^Color" /etc/pacman.conf > /dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
    grep "ILoveCandy" /etc/pacman.conf > /dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
    # enable all cores for compilation
    sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
}

set_permissions() {
    # Set special `sudoers` settings
    sed -i "/#dotfile-installer/d" /etc/sudoers
    echo "$* #dotfile-installer" >> /etc/sudoers
}

set_user_credentials() {
    display_info_box "Adding user \"$name\"..."
    useradd -m -g wheel -s /bin/zsh "$name" > /dev/null 2>&1 || usermod -a -G wheel "$name" &&
        mkdir -p /home/"$name" &&
        chown "$name":wheel /home/"$name"
    repodir="/home/$name/.local/src"
    mkdir -p "$repodir"
    chown -R "$name":wheel "$repodir"
    echo "$name:$user_passwd" | chpasswd
    unset user_passwd confirm_user_passwd
}

start_pulse_audio_daemon() {
    $(
        killall pulseaudio || true
        pulseaudio --system --start --daemonize
    ) > /dev/null 2>&1
}

successful_install_alert() {
    unsuccessfully_installed_programs=$(printf "\n" && echo "$(curl -s "${user_programs_file}" | sed '/^#/d')" | while IFS=, read -r tag program comment; do if [[ $tag == 'G' ]]; then printf "%s\n" "$program"; elif [[ "$(pacman -Qi "$program" > /dev/null)" ]]; then printf "%s\n" "$program"; fi; done)
    dialog \
        --backtitle "$BACKTITLE" \
        --title "Configuration files installed" \
        --msgbox "If no hidden errors, dotfile-installer.sh completed successfully.\nNumber of programs installed -> $total. \nPrograms that might not have gotten installed\n:$unsuccessfully_installed_programs" \
        0 0
}

system_beep_off() {
    display_info_box "Getting rid of that retarded error beep sound..."
    rmmod pcspkr ||
        display_info_box "pcspkr module not loaded, skipping..."
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
}

user_confirm_install() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yes-label "Let's go!" \
        --no-label "No, nevermind!" \
        --yesno "The rest of the installation will now be totally automated, so sit back and relax.\\n\\nNow just press <Let's go!> and the system will begin installation!" \
        0 0 || {
        clear
        exit
    }
}

refresh_arch_keyring() {
    display_info_box "Refreshing Arch keyring"
    pacman --noconfirm -Sy archlinux-keyring > /dev/null 2>&1
}

run_reflector() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "Install and run reflector? It might speed up package downloads." \
        0 0
    response=$?
    case $response in
        0)
            display_info_box "Installing reflector"
            install_pkg reflector
            display_info_box "Running reflector"
            reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null
            ;;
        1)
            return
            ;;
    esac
}

user_exists_warning() {
    ! (id -u "$name" > /dev/null) 2>&1 ||
        dialog \
            --colors \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --yes-label "CONTINUE" \
            --no-label "No wait..." \
            --yesno "User already exists on this system. Continuing will overwrite conflicting files." \
            0 0
}

welcome_screen() {
    dialog \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --msgbox "Welcome! This script automatically installs a fully-featured Arch Linux desktop." \
        0 0
}

# ---------------------------- #
#            Install           #
# ---------------------------- #
while getopts ":a:r:b:p:h" o; do case "${o}" in
    h) printf 'Optional arguments for custom use:\n  -r: Dotfiles repository (local file or url)\n  -p: Dependencies and programs csv (local file or url)\n  -a: AUR helper (must have pacman-like syntax)\n  -h: Show this message\n' && exit ;;
    r) dotfiles_repo=${OPTARG} && git ls-remote "$dotfiles_repo" || exit ;;
    b) repo_branch=${OPTARG} ;;
    p) user_programs_file=${OPTARG} ;;
    a) aur_helper=${OPTARG} ;;
    *) printf 'Invalid option: -%s\n' "$OPTARG" && exit ;;
esac; done

[ -z "$dotfiles_repo" ] && dotfiles_repo="https://github.com/vladdoster/dotfiles.git"
[ -z "$user_programs_file" ] && user_programs_file="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/user-programs.csv"
[ -z "$aur_helper" ] && aur_helper="yay"
[ -z "$repo_branch" ] && repo_branch="master"

# clean_installed_packages || error "clean_installed_packages() could not clear non-essential packages"
install_dependencies
welcome_screen || error "User exited welcome_screen()"
get_user_credentials || error "Error in prompt_user_credentials()"
user_exists_warning || error "user_exists_warning() could not continue"
user_confirm_install || error "user_confirm_install() could not continue"
set_user_credentials || error "Error adding user in set_user_credentials()"
refresh_arch_keyring || error "Error automatically refreshing Arch keyring. Consider doing so manually."
run_reflector || error "run_reflector() encountered an error"
set_preinstall_settings || error "set_preinstall_settings() did not finish successfully"
manual_install $aur_helper || error "Failed to install yay via manual_install()"
install_user_programs || error "Error in install_user_programs()"
add_dotfiles || error "Error in add_dotfiles()"
set_postinstall_settings || error "set_postinstall_settings() did not finish successfully"
successful_install_alert || error "Unfortunately, the install failed..."
