#!/bin/bash

source $(dirname "$0")/ENV_FILE

kstat -p zfs:0 15 3 | gawk -v hostname=$HOSTNAME -v influx_srv=$INFLUX_SRV '
 $NF ~ "^[0-9]" {
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"zfs_stats,host=" hostname " "$1"="$2"\"")
 }'

exit $?
