#!/bin/bash
yes | sudo pacman -Syy git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
rsync --recursive --verbose --exclude-from=.copyignore ./system-installer/ $(pwd)
# (cd system-installer/; shopt -s extglob; cp -r !(LICENSE | README | git) ../)
rm --recursive --verbose ./system-installer
