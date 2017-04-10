# Tools to send system statistics to influxdb

## dsk_stats.sh
send __iostat -rxdmne 15 3__ output to influxdb

## tcp_stats
send __netstat -s -P tcp__ to influxdb

## fs_stats
send __fsstat zfs__ to influxdb

## zfs_stats
send __kstat -p zfs:0__ to influxdb
