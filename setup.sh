#!/bin/bash
yes | sudo pacman -S git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
ls -alr
(cd system-installer/; rsync --exclude={".git/", "LICENSE", "README.md"} . ../) 
ls -al
rm --recursive system-installer/
