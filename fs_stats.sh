#!/bin/bash

SCRIPTS_DIR=$(dirname $0)

source $SCRIPTS_DIR/ENV_FILE

/usr/bin/fsstat -i zfs 15 3 | /usr/bin/python $SCRIPTS_DIR/lib/iorep.py
