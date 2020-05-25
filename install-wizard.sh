#!/bin/bash

# --- Variables --- #
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=6
WIDTH=50
TITLE="Install Wizard"
WIZARD_DEPENDENCIES="dialog git"

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

# --- Different options --- #
function install_arch() {

  dialog \
    --title "$TITLE" \
    --infobox "Please wait" 0 0
    
  msg=$(
      rm --force --recursive ./system-bootstrap/ 2>&1 1> /dev/null &&
      git clone --quiet https://github.com/vladdoster/system-bootstrap 2>&1 1> /dev/null &&
      cp --recursive ./system-bootstrap/* $(pwd) 2>&1 1> /dev/null &&
      rm --recursive ./system-bootstrap/ LICENSE README.md 2>&1 1> /dev/null &&
      chmod +x *.sh 2>&1 1> /dev/null
  )
  [[ -n $msg ]] && catch $msg
  
  dialog \
    --title "$TITLE" \
    --yesno "Install Arch Linux?" 0 0
  response=$?
  case $response in
    0) (./arch-installer.sh) ;;
    1) return ;;
  esac
}

function install_dotfiles() {
  echo "Installing dotfiles"
}

################################
#        Install script        #
################################
# --- Require root user --- #
if [ "$(id -u)" != "0" ]; then
  echo "This script requires it be run as root"
  exit 1
fi

# --- Install dependencies --- #
sudo pacman --quiet --noconfirm -S "$WIZARD_DEPENDENCIES" > /dev/null 2>&1

# --- Main menu --- #
while true; do
  exec 3>&1
  selection=$(dialog \
    --backtitle "$TITLE" \
    --title "$TITLE" \
    --clear \
    --cancel-label "Exit" \
    --menu "Please select:" 0 0 0 \
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
done
