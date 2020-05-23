## Personal system installer
An everyday desktop evironment geared towards **productivity** ,  **development** ,  **low resource usage**, and **reproducibility**.

### Included:

1. Arch Linux installer asks for input, has sensible defaults, and does the heavy lifting for you.
2. Dotfile installer sets up fully configured system using [Suckless utilities](https://suckless.org/).
    - [Dynamic window manager](https://dwm.suckless.org/)
    - [Dynamic menu](https://tools.suckless.org/dmenu/)
    - [Simple Terminal](https://st.suckless.org/)

### Installation:

cURL this script, it downloads all files you might need:
```bash
$ curl -LO files.vdoster.com/setup.sh; sudo bash ./setup.sh
```

Arch install (asks to install dotfiles in chroot env):
```bash
$ sudo ./arch-installer.sh
```

Install just dotfiles:
```bash
$ sudo ./dotfile-installer.sh
```

#### `programs.csv` list

Parses the given programs list and install all given programs.
Can handle:
    - AUR packages
    - Python via pip
    - Git repos
  
The first column is a "tag" that determines how the program is installed, ""
(blank) for the main repository, `A` for via the AUR or `G` if the program is a
git repository that is meant to be `make && sudo make install`ed.

#### Check which programs arent installed:

```bash
$ programs="https://raw.githubusercontent.com/vladdoster/dotfile-installer/master/programs.csv"
$ printf "\n" && echo "$(curl -s "$programs" | sed '/^#/d')" | \
  while IFS=, read -r tag program comment; do
   if [[ $tag == 'G' ]]; then 
       printf "$program might not be installed because it is from git\n" 
   else 
       printf "$(pacman -Qi "$program" > /dev/null)"
   fi;  done
```
