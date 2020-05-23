#!/bin/bash
yes | sudo pacman -Syy git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
rsync --exclude={'.git/','LICENSE','README.md'} system-installer/ $(pwd)
rm --recursive system-installer/
