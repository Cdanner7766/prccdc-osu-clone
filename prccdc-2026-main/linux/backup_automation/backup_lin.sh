#!/usr/bin/env bash

# shell script to create a subdirectory, bak, to backup important directories and folders.
# living document; update as needed
# warning: this takes a HOT minute. Do critical sec tasks first
# last updated: 1-29-2026, dangjam

# make root subdirectory for storing backups
mkdir bak
cd bak

# backup home directories
tar -zcvf init_home.tar.gz /home

# backup current state
cat /etc/passwd > init_passwd
cat /etc/group > init_group
systemctl list-units > init_systemctl
lsmod > init_lsmod
last > init_last
tar -zcvf init_etc.tar.gz /etc
tar -zcvf init_bin.tar.gz /bin

# if html, copy that too
if [ -d "/var/www/html" ]; then
    tar -zcvf init_html.tar.gz /var/www/html
fi