#!/bin/bash
yes | sudo pacman -Syy git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
rsync -r --verbose --exclude-from=.copyignore system-installer .
# (cd system-installer/; shopt -s extglob; cp -r !(LICENSE | README | git) ../)
rm -r system-installer/
