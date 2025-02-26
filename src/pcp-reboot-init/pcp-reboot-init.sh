#!/bin/sh
#
# Copyright (c) 2024 Ken McDonell.  All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# Intended as "run after reboot" to make sure transient things that PCP
# needs have been setup ...
#

tmp=`mktemp -d "$PCP_TMPFILE_DIR/pcp-reboot-init.XXXXXXXXX"` || exit 1
status=1	# fail is the default
trap "rm -rf $tmp; exit \$status" 0 1 2 3 15

if [ ! -f "$PCP_DIR/etc/pcp.env" ]
then
    echo "$0: Error: \$PCP_DIR/etc/pcp.env missing ... arrgh"
    exit
fi
. "$PCP_DIR/etc/pcp.env"

if [ `id -u` -ne 0 ]
then
    echo "$0: Error: You must be root (uid 0) to run script"
    exit
fi

if [ -z "$PCP_RUN_DIR" ]
then
    echo "$0: Botch: no PCP_RUN_DIR= in $PCP_DIR/etc/pcp.conf"
    exit
fi

if [ -z "$PCP_USER" ]
then
    echo "$0: Botch: no PCP_USER= in $PCP_DIR/etc/pcp.conf"
    exit
fi

if [ -z "$PCP_GROUP" ]
then
    echo "$0: Botch: no PCP_GROUP= in $PCP_DIR/etc/pcp.conf"
    exit
fi

# Need $PCP_RUN_DIR to exist and be owned by $PCP_USER:$PCP_GROUP
#
if [ ! -d "$PCP_RUN_DIR" ]
then
    if mkdir "$PCP_RUN_DIR"
    then
	:
    else
	echo "$0: Error: mkdir for \$PCP_RUN_DIR ($PCP_RUN_DIR) failed"
	ls -ld "$PCP_RUN_DIR/.." "$PCP_RUN_DIR"
	exit
    fi
fi

# ls(1) line looks like
# drwxrwxr-x 2 pcp pcp 220 Jan 20 15:25 /var/run/pcp
# or
# drwxrwxr-x  2 pcp  pcp  512 Jan 20 15:02 /var/run/pcp
#  ^^^^^^^^^    ^^^  ^^^
#    mode      user group
#
if ls -ld "$PCP_RUN_DIR" >$tmp/tmp
then
    :
else
    echo "$0: Error: ls \$PCP_RUN_DIR ($PCP_RUN_DIR) failed"
    ls -ld "$PCP_RUN_DIR/.." "$PCP_RUN_DIR"
fi
mode=`awk '{print $1}' <$tmp/tmp | sed -e 's/^.//' -e 's/\(.........\).*/\1/'`
user=`awk '{print $3}' <$tmp/tmp`
group=`awk '{print $4}' <$tmp/tmp`

if [ "$user" != $PCP_USER -o "$group" != $PCP_GROUP ]
then
    if chown $PCP_USER:$PCP_GROUP "$PCP_RUN_DIR"
    then
	:
    else
	echo "$0: Error: chown for \$PCP_RUN_DIR ($PCP_RUN_DIR) failed"
	ls -ld "$PCP_RUN_DIR"
	exit
    fi
fi

if [ "$mode" != "rwxrwxr-x" ]
then
    if chmod 775 "$PCP_RUN_DIR"
    then
	:
    else
	echo "$0: Error: chmod for \$PCP_RUN_DIR ($PCP_RUN_DIR) failed"
	ls -ld "$PCP_RUN_DIR"
	exit
    fi
fi

status=0
exit
