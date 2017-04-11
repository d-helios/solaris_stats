#!/usr/bin/python
#vim: set ts=4 sts=4 sw=4 expandtab
import re
import sys
import fcntl
import os
import locale
import requests
import socket
from subprocess import check_call

# influx server
influx_db = os.environ['INFLUX_SRV']

HEADERS = [ 'read_ops', 'read_bytes', 'write_ops', 'write_bytes', 'rddir_ops', 'rddir_bytes', 'rwlock', 'rwunlock' ]

def isfloat( val ):
    try:
        float(val)
        return True
    except ValueError, e:
        return False


#: influxdb sender
def send2influx(key, val):
    v_url="http://%s:8086/write?db=znstor" % (influx_db)
    v_headers={'Content-Type': 'application/octet-stream'}
    v_data='fsstat,host=%s %s=%s' % (socket.gethostname(), key, val)
    print v_data

    r = requests.post(url=v_url, data=v_data, headers=v_headers)

#: for zabbix sender. Need to define zbx_server - zabbix server hostname and zbx_sender - path to zabbix sender
def send2zbx (key, val):
    rc = check_call([zbx_sender, '-z', zbx_server, '-s', os.uname()[1].split('.')[0], '-k', key, '-o', str(val)])
    return rc


def read_stdin():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        yield line


def human2bytes ( val ):
    if isfloat(val):
        return float(val)
    
    symbols = ('B', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y') 

    letter = val[-1:].strip().upper()
    num = val[:-1]

    assert isfloat(num) and letter in symbols

    num = float(num)

    prefix = {symbols[0]: 1}
    for i, s in enumerate(symbols[1:]):
        prefix[s] = 1 << (i+1)*10
    return float(num * prefix[letter])
    

if __name__ == "__main__":

    skip_lines = 3
    skiped_lines = 0

    # interfaval for devision
    divnum = 15

    import sys

   
    for line in read_stdin():
        if not re.search(r'^[0-9].+', line.strip()):
            skiped_lines += 1
            continue

        if skiped_lines < skip_lines:
            skiped_lines += 1
            continue

        line = re.sub( ' +',' ' , line.strip()).split(' ')[0:8]

        if len(line) == 8:
            line = map(human2bytes, line)

        data = map(lambda x: round(x / divnum, 2), line) 

        for i in xrange(len(HEADERS)):
            send2influx(HEADERS[i], data[i])
