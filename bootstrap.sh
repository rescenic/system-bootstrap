#!/bin/bash
sudo pacman --quiet --noconfirm -S  dialog git >/dev/null 2>&1
# while-menu-dialog: a menu driven system information program

DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0

display_result() {
  dialog --title "$1" \
    --no-collapse \
    --msgbox "$result" 0 0
}

  exec 3>&1
  selection=$(dialog \
    --backtitle "System Information" \
    --title "Menu" \
    --clear \
    --cancel-label "Exit" \
    --menu "Please select:" $HEIGHT $WIDTH 4 \
    "1" "Install Arch Linux" \
    "2" "Install dotfiles" \
    2>&1 1>&3)
  exit_status=$?
  exec 3>&-
  case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Program terminated."
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
  esac
  case $selection in
    0 )
      clear
      echo "Program terminated."
      ;;
    1 )
#       result=$(echo "Hostname: $HOSTNAME"; uptime)
      display_result "System Information"
      ;;
    2 )
#       result=$(df -h)
      display_result "Disk Space"
      ;;
  esac

git clone https://github.com/vladdoster/personal-system-installer 2> /dev/null || echo "Already cloned"
cp --recursive ./personal-system-installer/* $(pwd); rm --recursive ./personal-system-installer/ LICENSE README.md; chmod +x *.sh
echo "Install Arch: sudo ./arch-install.sh"
