#!/bin/bash

source $(dirname "$0")/ENV_FILE

iostat -rxdmne 15 3 | gawk -F',' -v hostname=$HOSTNAME -v influx_srv=$INFLUX_SRV '
 $NF ~ "^c[0-9]" {
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_sw_err,host=" hostname ",disk="$NF" value="$11"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_hw_err,host=" hostname ",disk="$NF" value="$12"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_trn_err,host=" hostname ",disk="$NF" value="$13"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_tot_err,host=" hostname ",disk="$NF" value="$14"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_wait,host=" hostname ",disk="$NF" value="$5"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_actv,host=" hostname ",disk="$NF" value="$6"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_wsvct,host=" hostname ",disk="$NF" value="$7"\"")
 system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"disk_asvct,host=" hostname ",disk="$NF" value="$8"\"")
 }'

exit $?
