### Check which files arent installed
echo "$(cat programs.csv | sed '/^#/d')" | while IFS=, read -r tag program comment; do pacman -Qi "$program" > /dev/null; done
