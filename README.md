# Bootstrapping Scripts

## Installation:

In an Arch live image, run:

```sh
$ curl -LO files.vdoster.com/setup.sh && sudo bash ./setup.sh
$ sudo bash ./arch-install.sh
```
## What is this?

A script that autoinstalls and autoconfigures a fully-functioning
and minimal terminal-and-vim-based Arch Linux environment.

Originally intended to be run on a fresh install of Arch Linux, and
provides you with a fully configured system using [Suckless utilities](https://suckless.org/).

- [Dynamic window manager](https://dwm.suckless.org/)
- [Dynamic menu](https://tools.suckless.org/dmenu/)
- [Simple Terminal](https://st.suckless.org/)

## Customization

By default, it uses the programs [here in programs.csv](programs.csv) and installs
[my dotfiles](https://github.com/vladdoster/dotfiles), but can easily change this by either 
modifying the default variables at the beginning of the script or giving the script one of these options:
- `-r`: custom dotfiles repository (URL)
- `-p`: custom programs list/dependencies (local file or URL)
- `-a`: a custom AUR helper (must be able to install with `-S` unless you
  change the relevant line in the script

### The `programs.csv` list

Parses the given programs list and install all given programs. Note
that the programs file must be a three column `.csv`.

The first column is a "tag" that determines how the program is installed, ""
(blank) for the main repository, `A` for via the AUR or `G` if the program is a
git repository that is meant to be `make && sudo make install`ed.

The second column is the name of the program in the repository, or the link to
the git repository, and the third comment is a description (should be a verb
phrase) that describes the program.

**Note**: If a program description includes commas, be sure to include double quotes around the whole description to ensure correct parsing.

##### Check which programs arent installed

```sh
$ programs="https://raw.githubusercontent.com/vladdoster/dotfile-installer/master/programs.csv"
$ printf "\n" && echo "$(curl -s "$programs" | sed '/^#/d')" | \
  while IFS=, read -r tag program comment; do
   if [[ $tag == 'G' ]]; then 
       printf "$program might not be installed because it is from git\n" 
   else 
       printf "$(pacman -Qi "$program" > /dev/null)"
   fi;  done
```

### The script itself

The script is broken up extensively into functions for easier readability and
trouble-shooting. Most everything should be self-explanatory.

The main work is done by the `installationloop` function, which iterates
through the programs file and determines based on the tag of each program,
which commands to run to install it. You can easily add new methods of
installations and tags as well.
