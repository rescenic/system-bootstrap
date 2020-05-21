#!/bin/sh
sudo pacman -Syy && yes | sudo pacman -S git && git clone https://github.com/vladdoster/dotfile-installer
chmod 777 -R arch-installer/
cd dotfile-installer/arch-installer/
