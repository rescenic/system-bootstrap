#!/bin/bash
sudo pacman -Syy && yes | sudo pacman -S git && git clone https://github.com/vladdoster/dotfile-installer
cd dotfile-installer/arch-installer/
