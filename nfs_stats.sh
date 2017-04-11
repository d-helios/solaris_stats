#!/usr/bin/bash


source $(dirname "$0")/ENV_FILE

/usr/sbin/dtrace -n '

#pragma D option quiet
#pragma D option defaultargs


inline int TOP_FILES = 10;

nfsv3:::op-read-start,
nfsv4:::op-read-start,
nfsv3:::op-write-start,
nfsv4:::op-write-start
{
        start[args[1]->noi_xid] = timestamp;
}

nfsv3:::op-read-done, nfsv3:::op-write-done /start[args[1]->noi_xid] != 0/
{
        this->elapsed = timestamp - start[args[1]->noi_xid];
        @rw[probename == "op-read-done" ? "nfsv3-op-read-latency" : "nfsv3-op-write-latency"] =
            avg(this->elapsed / 1000);
        start[args[1]->noi_xid] = 0;
}

nfsv4:::op-read-done, nfsv4:::op-write-done /start[args[1]->noi_xid] != 0/
{
        this->elapsed = timestamp - start[args[1]->noi_xid];
        @rw[probename == "op-read-done" ? "nfsv4-op-read-latency" : "nfsv4-op-write-latency"] =
            avg(this->elapsed / 1000);
        start[args[1]->noi_xid] = 0;
}


profile:::tick-14sec / ticks > 0 / { ticks--; }

profile:::tick-14sec
{
        printa(@rw);
}

profile:::tick-56sec {exit(0);} ' | \

gawk -v hostname=$HOSTNAME -v influx_srv=$INFLUX_SRV '
/nfs/ {
        system("/usr/bin/curl -XPOST http://" influx_srv ":8086/write?db=znstor --data-binary \"nfs_stats,host=" hostname " "$1"="$2"\"")
       }

'
