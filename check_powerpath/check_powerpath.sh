#!/bin/sh
############################################################################
#This file is a part of zwindler-monitoring-plugins repository
#Copyright (C) 2013 zwindler
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program. If not, see {http://www.gnu.org/licenses/}.
############################################################################
# 22/02/2013 - Rael Mussell (Initial author)
# Detect degraded EMC paths
################################################################################
# 22/11/2013 - Denis GERMAIN
# Code factorization
# Added a variable to find sudo (not always in usr/local)
# Modified output to standard Nagios pluggin output, and perfdata
# To add privilege for nagios, add the following line in /etc/sudoers
#    nagios  ALL = NOPASSWD: /sbin/powermt
################################################################################
# 10/03/2014 - Denis GERMAIN
# Modified code to also display Unlic paths
################################################################################
# Nagios constants
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

HOSTNAME=$1
OS=`uname -s`

if [[ -f "/usr/local/bin/sudo" ]]; then
        SUDOPATH="/usr/local/bin/sudo"
else
        SUDOPATH=`which sudo`
fi

# Routine to check is PowerPath is installed and being used.  If not, exit UNKNOWN
case "$OS" in
        'Linux' )
        POWERPATH_CHECK=`rpm -qa | grep EMC | wc -l`
        POWERMT_PATH="/sbin/powermt"
        ;;
        'HP-UX' )
        POWERPATH_CHECK=`/usr/sbin/swlist | grep EMC | wc -l`
        POWERMT_PATH="/sbin/powermt"
        ;;
        'SunOS' )
        POWERPATH_CHECK=`pkginfo | grep EMC | wc -l`
        POWERMT_PATH="/etc/powermt"
        ;;
esac

if [ $POWERPATH_CHECK -gt 0 ]; then
        #Check for unlicensed paths
        CHECK_UNLIC=`$SUDOPATH $POWERMT_PATH display dev=all | grep unlic | wc -l`
        if [ $CHECK_UNLIC -gt 0 ]; then
                CHECK_OUTPUT="WARNING: SAN issue detected - $CHECK_UNLIC SAN path(s) in degraded mode."
                CHECK_RETURN_CODE=$WARNING
        fi
        #Check for degraded paths
        CHECK_DEGRADED=`$SUDOPATH $POWERMT_PATH display dev=all | grep degraded | wc -l`
        if [ $CHECK_DEGRADED -gt 0 ]; then
                #if there are, this is worse than unlic, so we overwrite previous warning if any
                CHECK_OUTPUT="CRITICAL: SAN issue detected - $CHECK_DEGRADED SAN path(s) in degraded mode."
                CHECK_RETURN_CODE=$CRITICAL
        else
                #No degraded, and no unlic here
                if [ $CHECK_UNLIC -eq 0 ]; then
                        CHECK_OUTPUT="OK: No SAN issue detected"
                        CHECK_RETURN_CODE=$OK
                fi
        fi
        echo $CHECK_OUTPUT." | Degraded=$CHECK_DEGRADED;1;1;; Unlic=$CHECK_UNLIC;1;1;;"
        exit $CHECK_RETURN_CODE
else
        echo "UNKNOWN: EMC PowerPath couldn't be found. Please check the system."
        exit $UNKNOWN
fi
