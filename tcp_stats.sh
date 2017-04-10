#!/bin/bash

source $(dirname "$0")/ENV_FILE

netstat -s -P tcp | sed 's/tcp/\ntcp/g;s/\t//g'|egrep -v "^$"| tr -d '[:blank:]' | gawk -F'=' -v hostname=$HOSTNAME -v influx_srv=$INFLUX_SRV '
 /tcp/ {
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \""$1",host=" hostname " value="$2"\"")
 }'

exit $?
