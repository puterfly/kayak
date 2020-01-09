# {{{ CDDL HEADER
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source. A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
# }}}

# Copyright 2019 OmniOS Community Edition (OmniOSce) Association.

check_hostname() {
    echo $1 | egrep -s '^[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9]$'
}

t_prompt_hostname() {
    NEWHOST="$1"
    while [ -n "$NEWHOST" ]; do
        HOSTNAME="$NEWHOST"
        echo -n "Please enter a hostname or press RETURN if you want [$HOSTNAME]: "
        read NEWHOST
        [ -z "$NEWHOST" ] && break
        check_hostname "$NEWHOST" && continue
        echo "Invalid hostname - $NEWHOST"
        NEWHOST=$HOSTNAME
    done
}

d_prompt_hostname() {
    HOSTNAME="$1"
    while :; do
        dialog \
            --title "Enter the system hostname" \
            --inputbox '' 7 40 "$HOSTNAME" 2> $tmpf
        [ $? -ne 0 ] && exit 0
        HOSTNAME="`cat $tmpf`"
        rm -f $tmpf
        [ -z "$HOSTNAME" ] && continue
        check_hostname "$HOSTNAME" && break
        d_msg "Invalid hostname"
    done
}

prompt_hostname() {
    [ -n "$USE_DIALOG" ] && d_prompt_hostname "$@" || t_prompt_hostname "$@"
    log "Selected hostname: $HOSTNAME"
}

t_prompt_timezone() {
    tzselect |& tee /tmp/tz.$$
    TZ="`tail -1 /tmp/tz.$$`"
    rm -f /tmp/tz.$$
}

d_prompt_timezone() {
    # Select a timezone.
    /kayak/installer/dialog-tzselect /tmp/tz.$$
    TZ="`tail -1 /tmp/tz.$$`"
    rm -f /tmp/tz.$$
}

prompt_timezone() {
    [ -n "$USE_DIALOG" ] && d_prompt_timezone "$@" || t_prompt_timezone "$@"
    log "Selected timezone: $TZ"
}

runpkg() {
    log "runpkg: $*"
    LD_LIBRARY_PATH=$ALTROOT/usr/lib/amd64 \
        PYTHONPATH=$ALTROOT/usr/lib/python3.7/vendor-packages \
        $ALTROOT/usr/bin/python3.7 \
        $ALTROOT/usr/bin/pkg -R $ALTROOT "$@" | pipelog
    sed -i '/^last_uuid/d' $ALTROOT/var/pkg/pkg5.image
}

extrarepo() {
    log "extrarepo $1"
    if [ "$1" = "-off" ]; then
        runpkg unset-publisher extra.omnios
        sed -i '
        /^#*PATH=/c\
PATH=/usr/bin:/usr/sbin:/sbin:/usr/gnu/bin
        /^#*SUPATH=/c\
SUPATH=/usr/sbin:/sbin:/usr/bin
        ' $ALTROOT/etc/default/login $ALTROOT/etc/default/su
    else
        coreuri=`runpkg publisher omnios | \
            nawk '/Origin URI:/ { print $3 }'`
        extrauri="${coreuri/core/extra}"
        runpkg set-publisher --no-refresh -O $extrauri extra.omnios
        runpkg publisher omnios | egrep -s require-signatures &&
            runpkg set-publisher --no-refresh --set-property \
            signature-policy=require-signatures extra.omnios
        sed -i~ '
        /^#*PATH=/c\
PATH=/usr/bin:/usr/sbin:/sbin:/opt/ooce/bin:/usr/gnu/bin
        /^#*SUPATH=/c\
SUPATH=/usr/sbin:/sbin:/opt/ooce/sbin:/usr/bin:/opt/ooce/bin
        ' $ALTROOT/etc/default/login $ALTROOT/etc/default/su
    fi
    log "--- final publisher configuration ---"
    runpkg publisher
}

# Vim hints
# vim:ts=4:sw=4:et:fdm=marker
