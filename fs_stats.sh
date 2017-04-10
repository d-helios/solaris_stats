#!/bin/bash

SCRIPTS_DIR=$(dirname $0)

source $SCRIPTS_DIR/ENV_FILE

fsstat -i zfs 15 3 | python $SCRIPTS_DIR/lib/iorep.py
