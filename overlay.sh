#!/bin/bash
set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

# How were we called?
case "${1}" in

    client)
        OVERLAY_DIR="overlay__client"
    ;;

    server)
        OVERLAY_DIR="overlay__server"
        make_my_cnf="yes"
        config_xinetd="yes"
        start_xinetd="yes"
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

# VARIABLE REPLACEMENT
if [ "${1}" = "client" ]; then
    echo

    while [ -z "${enable_mac_allow_db}" ]; do
        read -p "Do you have a MAC allow list database (y/n)?: " enable_mac_allow_db
        enable_mac_allow_db=$(echo "${enable_mac_allow_db}" | tr '[A-Z]' '[a-z]' | sed -e 's/[^(y|n)]//g')
    
        case ${enable_mac_allow_db} in
    
            y)
                echo
    
                while [ -z "${mac_allow_db}" ]; do
                    read -p "Enter the MAC allow DB name: " mac_allow_db
                done
    
                echo
    
                while [ -z "${db_host}" ]; do
                    read -p "Enter the DB Hostname for DB '${mac_allow_db}': " db_host
                done
    
                echo
    
                while [ -z "${db_port}" ]; do
                    read -p "Enter the Port Number for DB host '${db_host}': " db_port
                done
    
                echo
    
                while [ -z "${db_user}" ]; do
                    read -p "Enter the Username with grants to DB '${mac_allow_db}': " db_user
                done
    
                echo
    
                while [ -z "${db_password}" ]; do
                    read -p "Enter the Password for DB username '${db_user}': " db_password
                done
    
            ;;
    
        esac
    
    done

    # Prep hostapd for MAC management
    for suffix in allow deny ; do
    
        if [ ! -e "/etc/hostapd/mac_addresses.${suffix}" ]; then
            touch "/etc/hostapd/mac_addresses.${suffix}"
        fi
    
    done

    for prefix in accept deny ; do
        find /etc/hostapd -maxdepth 1 -type f -iname "hostapd-*.conf" -exec sed -i -e "|s^#\(${prefix}_mac_file=.*\)|\1|g" '{}' \;
    done

fi

# Find all files
this_dir=$(realpath -L $(dirname "${0}"))

if [ -d "${this_dir}/${OVERLAY_DIR}" ]; then
    overlay_files=$(find "${this_dir}/${OVERLAY_DIR}" -depth -type f 2> /dev/null)

    for overlay_file in ${overlay_files} ; do
        copy_command=""
        target_file=$(basename "${overlay_file}")
	target_path=$(dirname "${overlay_file}" | sed -e "s|^${this_dir}/${OVERLAY_DIR}||g")

        if [ ! -e "${target_path}" ]; then
            mkdir -p "${target_path}"
        fi

        # Perform any variable substitution in line
        case ${target_file} in

            mac_allow_list.conf)
                copy_command="sed -e 's|::MAC_ALLOW_DB::|${mac_allow_db}|g' -e 's|::DB_HOST::|${db_host}|g' -e 's|::DB_PORT::|${db_port}|g' -e 's|::DB_USER::|${db_user}|g' -e 's|::DB_PASSWORD::|${db_password}|g' '${overlay_file}' > '${target_path}/${target_file}'"
            ;;

            *)
                copy_command="cp '${overlay_file}' '${target_path}/${target_file}'"
            ;;

        esac

        if [ -n "${copy_command}" ]; then
            eval "${copy_command}"
        fi

    done

fi

# Setup /root/.my.cnf
if [ "${make_my_cnf}" = "yes" ]; then
    rm -f /root/.my.cnf                   > /dev/null 2>&1

    echo
    read -p "Please enter the MySQL/MariaDB root password: " my_root_db_passwd

    if [ -n "${my_root_db_passwd}" ]; then
        echo "[client]"                       > /root/.my.cnf
        echo "user=root"                     >> /root/.my.cnf
        echo "password=${my_root_db_passwd}" >> /root/.my.cnf
    fi

    if [ -s "/root/.my.cnf" ]; then
        chmod 640 /root/.my.cnf > /dev/null 2>&1
    fi

    systemctl enable mariadb
    systemctl start mariadb
fi

# Define new local xinetd service definition
if [ "${config_xinetd}" = "yes" ]; then
    egrep "^# Local services" /etc/services > /dev/null 2>&1

    if [ ${?} -ne 0 ]; then
        echo                    >> /etc/services
        echo "# Local services" >> /etc/services
    fi

    egrep "^ip_allowlist    60000/tcp" /etc/services > /dev/null 2>&1

    if [ ${?} -ne 0 ]; then
        echo "ip_allowlist    60000/tcp" >> /etc/services
    fi

fi

# Activate new local xinetd service definition
if [ "${start_xinetd}" = "yes" ]; then
    systemctl enable xinetd
    systemctl start xinetd
fi


## NOTES
#
## Needs to be replaced with values
#./${OVERLAY_DIR}/etc/mac_allow_list/mac_allow_list.conf:db="::MAC_ALLOW_DB::"
#./${OVERLAY_DIR}/etc/mac_allow_list/mac_allow_list.conf:db_host="::DB_HOST::"
#./${OVERLAY_DIR}/etc/mac_allow_list/mac_allow_list.conf:db_port="::DB_PORT::"
#./${OVERLAY_DIR}/etc/mac_allow_list/mac_allow_list.conf:db_user="::DB_USER::"
#./${OVERLAY_DIR}/etc/mac_allow_list/mac_allow_list.conf:db_password="::DB_PASSWORD::"
