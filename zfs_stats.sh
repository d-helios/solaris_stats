#!/usr/bin/bash


source $(dirname "$0")/ENV_FILE

/usr/sbin/dtrace -n '

#pragma D option quiet
#pragma D option defaultargs

zfs_read:entry,zfs_write:entry {
         self->ts = timestamp;
}

zfs_read:return,zfs_write:return /self->ts  / {
        this->type =  probefunc == "zfs_write" ? "zfs_write_latency" : "zfs_read_latency";
        this->delta=(timestamp - self->ts);
        @zfs_latency[this->type] = avg(this->delta / 1000);
}

profile:::tick-14sec / ticks > 0 / { ticks--; }

profile:::tick-14sec
{
        printa(@zfs_latency);
}

profile:::tick-56sec {exit(0);} ' | \

gawk -v hostname=$HOSTNAME -v influx_srv=$INFLUX_SRV '
/zfs_/ {
        system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"zfs_stats,host=" hostname " "$1"="$2"\"")
       }

'
