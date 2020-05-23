#!/bin/sh
LOCALREPO_VC_DIR="system-installer"
yes | sudo pacman -Syy git
git clone https://github.com/vladdoster/system-installer 2> /dev/null || echo "Already cloned"
# cp -r system-installer/. .
# rm -r system-installer/
rsync -av system-installer/ $(cwd) --exclude LICENSE --exclude README.md
