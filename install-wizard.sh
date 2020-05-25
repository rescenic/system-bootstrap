#!/bin/bash

# --- Variables --- #
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0

# --- Dependencies --- #
sudo pacman --quiet --noconfirm -S dialog git > /dev/null 2>&1

# --- Error handling --- #
catch() {
  # error handling goes here
  error=$(echo "$@")
  dialog --title "Install wizard" \
    --no-collapse \
    --msgbox "$error" 0 0
  exit
}

# --- Different options --- #
function install_arch() {

  dialog --title "Install wizard" \
    --no-collapse \
    --msgbox "Installing arch" 3 30
  msg=$(
    git clone --quiet https://github.com/vladdoster/system-bootstrap 2>&1 1> /dev/null &&
      cp --recursive ./system-bootstrap/* $(pwd) 2>&1 1> /dev/null &&
      rm --recursive ./system-bootstrap/ LICENSE README.md 2>&1 1> /dev/null &&
      chmod +x *.sh 2>&1 1> /dev/null
  )
  [[ -n $msg ]] && catch $msg
}

function install_dotfiles() {
  echo "Installing dotfiles"
}

# --- Main menu of install wizard --- #
exec 3>&1
selection=$(dialog \
  --backtitle "System bootstrap" \
  --title "System boostrap" \
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
  0)
    clear
    echo "Program terminated."
    ;;
  1)
    install_arch
    ;;
  2)
    install_dotfiles
    ;;
esac
