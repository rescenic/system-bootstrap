#!/bin/bash
yes | sudo pacman -Syy git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
rsync --recursive --verbose --exclude ".git/" --exclude LICENSE --exclude README.md ./system-installer/ "$(pwd)"
rm --recursive ./system-installer
