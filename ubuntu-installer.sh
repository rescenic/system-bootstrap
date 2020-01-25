#!/bin/sh

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
        h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
        r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
        b) repobranch=${OPTARG} ;;
        p) progsfile=${OPTARG} ;;
        *) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/vladdoster/dotfiles.git"
[ -z "$progsfile" ] && progsfile="https://github.com/vladdoster/dotfile-installer/master/ubuntu_programs.csv"
[ -z "$repobranch" ] && repobranch="master"


### FUNCTIONS ###

grepseq="\"^[PGU]*,\""
      
error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
        dialog --title "Welcome!" --msgbox "Welcome to Ubuntu dotfile installer script!\\n\\nThis script will automatically install a fully-featured Linux desktop.\\n\\n-Vlad" 10 60
        }


getuserandpass() { \
        # Prompts user for new username an password.
        name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
        while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
                name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
        done
        pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        while ! [ "$pass1" = "$pass2" ]; do
                unset pass2
                pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
                pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        done ;}


usercheck() { \
        ! (id -u "$name" >/dev/null) 2>&1 ||
        dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. LARBS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nLARBS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LARBS will change $name's password to the one you just gave." 14 70
        }


preinstallmsg() { \
        dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
        }


adduserandpass() { \
        # Adds user `$name` with password $pass1.
        dialog --infobox "Adding user \"$name\"..." 4 50
        useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
        usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
        echo "$name:$pass1" | chpasswd
        unset pass1 pass2 ;}


newperms() { # Set special sudoers settings for install (or after).
        sed -i "/#LARBS/d" /etc/sudoers
        echo "$* #LARBS" >> /etc/sudoers ;}


# INSTALLATION METHODS

dpkginstall() { \
        dir=$(mktemp -d)
        software="$(basename "$1")"
        dialog --title "LARBS Installation" --infobox "Installing \`$software\`$2" 5 70
        wget "$1" "$dir" >/dev/null 2>&1
        dpkg -i "$software"
        rm "$software";}

gitmakeinstall() { \
        dir=$(mktemp -d)
        dialog --title "LARBS Installation" --infobox "Installing \`$(basename "$1")\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
        git clone --depth 1 "$1" "$dir" >/dev/null 2>&1
        cd "$dir" || exit
        make >/dev/null 2>&1
        make install >/dev/null 2>&1
        cd /tmp || return ;}
	
installbrew() { sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
	PATH="/home/linuxbrew/.linuxbrew/bin:$PATH" ;}	

installpkg(){ apt-get install -y "$1" >/dev/null 2>&1 ;}

maininstall() { # Installs all needed programs from main repo.
        dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
        installpkg "$1"
        }

snapinstall() { \
	dialog --title "LARBS Installation" --infobox "Installing a Snap package \`$1\` ($n of $total). $1 $2" 5 70
        snap install "$1"
        }

installationloop() { \
        ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
        total=$(wc -l < /tmp/progs.csv)
        while IFS=, read -r tag program comment; do
                n=$((n+1))
                echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
                case "$tag" in
			"B") brewinstall "$program" "$comment" ;;
                        "G") gitmakeinstall "$program" "$comment" ;;
			"S") snapinstall "$program" "$comment" ;;
			"U") dpkginstall "$program" "$comment" ;;
                        *) maininstall "$program" "$comment" ;;
                esac
        done < /tmp/progs.csv ;}


putgitrepo() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
        dialog --infobox "Downloading and installing config files..." 4 60
        [ -z "$3" ] && branch="master" || branch="$repobranch"
        dir=$(mktemp -d)
        [ ! -d "$2" ] && mkdir -p "$2" && chown -R "$name:wheel" "$2"
        chown -R "$name:wheel" "$dir"
        sudo -u "$name" git clone -b "$branch" --depth 1 "$1" "$dir/gitrepo" >/dev/null 2>&1 &&
        sudo -u "$name" cp -rfT "$dir/gitrepo" "$2"
        }


systembeepoff() { dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
        rmmod pcspkr
        echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

installi3gaps(){ \
	apt install -y libxcb1-dev libxcb-keysyms1-dev libpango1.0-dev libxcb-util0-dev libxcb-icccm4-dev libyajl-dev libstartup-notification0-dev libxcb-randr0-dev libev-dev libxcb-cursor-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev autoconf libxcb-xrm0 libxcb-xrm-dev automake
	cd /tmp || error

	# clone the repository
	git clone https://www.github.com/Airblader/i3 i3-gaps
	cd i3-gaps || error

	# compile & install
	autoreconf --force --install
	rm -rf build/
	mkdir -p build && cd build/

	# Disabling sanitizers is important for release versions!
	# The prefix and sysconfdir are, obviously, dependent on the distribution.
	../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
	make || error "couldnt make i3 gaps"
	make install || error "couldnt make install i3 gaps"
}


### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
installpkg dialog ||  error "Are you sure you're running this as the root user and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

adduserandpass || error "Error adding username and/or password."

# Refresh Arch keyrings.
# refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

dialog --title "LARBS Installation" --infobox "Installing \`git\` for installing other software." 5 70
installpkg git
add-apt-repository ppa:codejamninja/jam-os --yes || error "adding i3-gaps PPA"
apt update || error "couldnt update apt"
# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installbrew # Do this first to avoid errors in programs.csv install
installationloop

installi3gaps || error "installing i3-gaps"

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -f "/home/$name/README.md" "/home/$name/LICENSE"

# Most important command! Get rid of the beep!
systembeepoff

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #LARBS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

# Make zsh the default shell for the user
sed -i "s/^$name:\(.*\):\/bin\/.*/$name:\1:\/bin\/zsh/" /etc/passwd

# Last message! Install complete!
finalize
clear

