#!/bin/bash
yes | sudo pacman -S git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
ls -al
rsync --exclude={".git/", "LICENSE", "README.md"} system-installer/ $(pwd)
ls -al
rm --recursive system-installer/
