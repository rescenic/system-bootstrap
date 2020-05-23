#!/bin/bash
yes | sudo pacman --quiet -S git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
cp --recursive ./system-installer/* $(pwd); rm --recursive ./system-installer/ LICENSE README.md; chmod +x *.sh
echo "Install Arch: sudo ./arch-install.sh"
