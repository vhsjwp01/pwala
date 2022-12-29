#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

# Install available needed things from default repo(s)
utilities="        \
    bc             \
    coreutils      \
    curl           \
    ethtool        \
    git            \
    gnupg          \
    gnupg1         \
    gnupg2         \
    htop           \
    iftop          \
    ifupdown       \
    iotop          \
    jq             \
    lsb-release    \
    openssh-server \
    rsync          \
    screen         \
    sudo           \
    uuid-runtime   \
    vim            \
    wget           "

# How were we called?
case "${1}" in

    client)
        utilities+=" netcat"
    ;;

    server)
        utilities+=" mariadb-client mariadb-server xinetd"
    ;;

    *)
        echo 
        echo "  No arguments supplied"
        echo "  Valid arguments are:"
        echo "    client"
        echo "    server"
        echo
        exit
    ;;

esac

echo "Updating apt source manifests"
apt update -qq > /dev/null 2>&1

echo "Installing needed packages"
apt install -y ${utilities} > /dev/null 2>&1

# Turn off graphical login and boot
echo "Disabling graphical boot"
systemctl set-default multi-user > /dev/null 2>&1
sed -i -e 's|\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)splash\(.*\)$|\1\2|g' /etc/default/grub > /dev/null 2>&1
update-grub > /dev/null 2>&1

exit 0
