#!/bin/bash
yes | sudo pacman --quiet -S git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
cp --recursive ./system-installer/* $(pwd); rm --recursive LICENSE README.md; chmod +x *.sh
echo "To start install, sudo ./install-arch"
