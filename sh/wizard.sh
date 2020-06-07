#!/bin/bash

# --- Dialog variables --- #
DIALOG_CANCEL=1
DIALOG_ESC=255
TITLE="Install Wizard"

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

# --- Downloads installers --- #
function download_installer() {
  dialog \
      --title "$TITLE" \
      --infobox "Please wait" 0 0
  installer_url="https://raw.githubusercontent.com/vladdoster/system-bootstrap/master/$1-installer.sh"
  msg=$(
      curl -O "$installer_url"
      chmod +x *.sh 2>&1 1> /dev/null
    )
  [[ -n $msg ]] && catch $msg
}

# --- Different options --- #
function install() {
   download_installer ${1}
   dialog \
     --title "$TITLE" \
     --yesno "Install ${1}?" 0 0
   response=$?
   echo ${1}
   case $response in
     0) sudo ./${1}-installer.sh ;;
     1) return ;;
   esac
}

################################
#        Install script        #
################################
# --- Require root user --- #
if [ "$(id -u)" != "0" ]; then
  echo "This script requires it be run as root"
  exit 1
fi

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
      install arch
      ;;
    2)
      install dotfiles
      ;;
  esac
done
