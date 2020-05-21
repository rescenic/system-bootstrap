#!/bin/sh
sudo pacman -Syy && yes | sudo pacman -S git && git clone https://github.com/vladdoster/system-installer .
chmod --recursive 777 system-installer/

