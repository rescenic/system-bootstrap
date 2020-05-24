#!/bin/sh
# Boostrapping Script
# Orginally released by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/vladdoster/dotfiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/dotfile-programs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$repobranch" ] && repobranch="master"

# Read in types of packages in programs.csv
grepseq="\"^[PGA]*,\""

#--- FUNCTIONS ---#
adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --title "Dotfile installer" --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$repodir"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

aurinstall() { \
	dialog --title "Dotfile installer" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep "^$1$" >/dev/null 2>&1 && return
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}
	
enabledocker() { \
	# https://docs.docker.com/install/linux/linux-postinstall/
	systemctl enable docker.service
	systemctl start docker.service
	usermod -aG docker $USER
	}
	
error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}
	
finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --colors --cr-wrap --title "Dotfiles installed" --msgbox "If no hidden errors, dotfile-installer.sh completed successfully. \nNumber of programs installed -> \\Zb$total\\Zn.\n\n\\ZbPrograms that might not have gotten installed\\Zn:\n$unsuccessfully_installed_programs" 12 80
	}
	
getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --title "Dotfile installer" --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --title "Dotfile installer" --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --title "Dotfile installer" --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --title "Dotfile installer" --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --title "Dotfile installer" --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}
	
gitmakeinstall() {
	progname="$(basename "$1")"
	dir="$repodir/$progname"
	dialog --title "Dotfile installer" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/programs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/programs.csv
	total=$(wc -l < /tmp/programs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/programs.csv ;}
	
installnvimplugins(){ nvim +PlugInstall +qall >/dev/null 2>&1 ;}

installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "Dotfile installer" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

makedirectories() { \
	mkdir -p /home/"$name"/github
	mkdir -p /home/"$name"/downloads
	}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --title "Dotfile installer" --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#dotfile-installer/d" /etc/sudoers
	echo "$* #dotfile-installer" >> /etc/sudoers ;}

pipinstall() { \
	dialog --title "Dotfile installer" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --title "Dotfile installer" --infobox "Downloading and installing config files..." 5 70
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$name":wheel "$dir" "$2"
	sudo -u "$name" git clone -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2"
	}

refreshkeys() { \
	dialog --title "Dotfile installer" --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
	}
	
run_reflector(){
dialog --title "Dotfile installer" --yesno "Install and run reflector? It might speed up package downloads." 7 60
response=$?
case $response in
   0) installpkg reflector && reflector --verbose --latest 100 --sort rate --save /etc/pacman.d/mirrorlist &> /dev/null;;
   1) return ;;
esac
}

systembeepoff() { dialog --title "Dotfile installer" --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. Dotfile installer will install for a pre-existing user, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nDotfile installer will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that Dotfile installer will change $name's password to the one you just gave." 14 70
	}
	
welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to bootstrapping script!\\n\\nThis script will automatically install a fully-featured Arch Linux desktop." 10 60
	}

#--- SCRIPT LOGIC ---#
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
# Add user
adduserandpass || error "Error adding username and/or password."
# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."
# Get fast mirrors
run_reflector
# Required packages for smooth install
dialog --title "Dotfile installer" --infobox "Installing \`basedevel\` and \`git\` for installing other software." 5 70
installpkg curl
installpkg base-devel
installpkg git
installpkg ntp
# Synchronize NTP servers
dialog --title "Dotfile installer" --infobox "Synchronizing system time to ensure successful and secure installation of software..." 4 70
ntp 0.us.pool.ntp.org >/dev/null 2>&1
[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers
# Allow user to run sudo without password. AUR programs require a fakeroot environment
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"
# Make pacman/yay colorful and add eye candy on the progress bar
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
# Use all cores for compilation
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
manualinstall $aurhelper || error "Failed to install AUR helper."
# The command that does all the installing. 
# Reads programs.csv file and installs each program given tag.
installationloop
# Install libxft-bgra for color emojis
dialog --title "Dotfile installer" --infobox "Finally, installing \`libxft-bgra\` to enable color emoji in suckless software without crashes." 5 70
yes | sudo -u "$name" $aurhelper -S libxft-bgra >/dev/null 2>&1
# Install dotfiles in home directory
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
# Remove dotfiles git repo cruft
rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/Downloads"
# Get rid of system beep
systembeepoff || error "Couldnt turn off system beep, erghh!"
# Make github folder and misc
makedirectories || error "Couldnt make github or downloads dir."
# Docker shenanigans
enabledocker || error "Couldnt enable docker."
# Vim shenanigans
installnvimplugins || error "Couldnt install nvim plugins"
# Start audio daemon
killall pulseaudio; sudo -n "$name" pulseaudio --start --daemonize=yes
# Zsh is default shell
sed -i "s/^$name:\(.*\):\/bin\/.*/$name:\1:\/bin\/zsh/" /etc/passwd
# This line, overwriting the `newperms` command above will allow me to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #dotfile-installer
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/nmtui,/usr/bin/pycharm"
# Check which programs arent present programs.csv
unsuccessfully_installed_programs=$(printf "\n" && echo "$(curl -s $progsfile | sed '/^#/d')" | while IFS=, read -r tag program comment; do if [[ $tag == 'G' ]]; then printf "%s\n" "$program"; elif [[ "$(pacman -Qi "$program" > /dev/null)" ]]; then printf "%s\n" "$program"; fi; done)
# Install complete!
finalize
clear
