#!/bin/bash
#
# Copyright (C) 2010 Mikael Berthe <mikael@lilotux.net>
#
# Copy this script on your system and specify the path for mcabber
# by setting the 'extsay_script_path' option.
#
# Usage: extsay.sh [jid [winsplit [height]]]
#
# This script is free software.
# MiKael, 2010-04-03

FIFOPATH="$HOME/.mcabber/mcabber.fifo"

tmpdir=${TMPDIR:=$TMP}
tmpdir=${tmpdir:="/tmp"}
editor=${EDITOR:="vim"}

jid="."

# Use argument as a recipient JID, if it is provided
[ $# -ge 1 ] && jid=$1
[ $# -ge 2 ] && winsplit=$2
[ $# -ge 3 ] && winheight=$3

# Leave if the FIFO is not available
[ -p $FIFOPATH ] || exit 255

tf=$(mktemp $tmpdir/extsay-${jid%%/*}-XXXXXX) || exit 255

if [ x$winsplit = x"winsplit" ]; then
    screen -r -X other
    screen -r -X split
    screen -r -X focus down
    screen -r -X other

    [ $winheight -gt 0 ] && screen -r -X resize $winheight
fi

# This will not work if the editor runs in the background!
$editor $tf

# Send the message using MCabber's pipe
if [ -s $tf ]; then
    cmd="say_to -q -f $tf $jid"
else
    cmd="echo [extsay] The file has not been modified.  Message cancelled."
fi
echo $cmd >> $FIFOPATH

# Do not remove the file too soon
setsid sh -c "cd / && sleep 20 && rm $tf & :" /dev/null 2>&1 < /dev/null

if [ x$winsplit = x"winsplit" ]; then
    screen -r -X remove
fi

exit 0
