#!/bin/sh
yes | sudo pacman -Syy git && git clone https://github.com/vladdoster/system-installer
chmod --recursive 777 system-installer/
