#!/bin/bash
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
#Checks whether there are files in a directory matching some criteria or not
############################################################################
# 19/05/2014 - DGE - First version
############################################################################
#Fixed variables
FIND_COMMAND="/usr/bin/find"

#Nagios Constants
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
SCRIPTPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`
if [[ -f ${SCRIPTPATH}/utils.sh ]]; then
        . ${SCRIPTPATH}/utils.sh # use nagios utils to set real STATE_* return values
fi

#Useful functions
printversion(){
        echo "$0 $VERSION"
        echo
}

printusage() {
        printversion
        echo "Checks whether there are files in a directory matching some criteria or not"
        echo
        echo "'$0 [-v] -p PATH_TO_CHECK_TO_CHECK [-c CRITICAL_THRESHOLD] [-w WARNING_THRESHOLD] ...'"
        echo "'$0 -h' displays help"
        echo "'$0 -h' displays version"
        echo
        echo "c - (positive number, default = 1) critical threshold for files"
        echo "d - (days , [+|-]number) only take into account files more than/less than/exactly (use
'+' or '-' or nothing) X days old. Ex: '-d +3' for file older than 3 days"
        echo "D - (positive number, default = 1) depth of find"
        echo "e - (pattern) exclude from the result the files whose name matches the pattern"
        echo "h - displays help"
        echo "i - (pattern) only take into account files whose name matches the pattern"
        echo "m - (minutes, [+|-]number) only take into account files more than/less than/exactly (use 
'+' or '-' or nothing) X minutes old. Ex: '-m +30' for file older than 30 minutes"
        echo "p - (path, mandatory) directory or file to check"
        echo "v - verbose mode"
        echo "V - displays version"
        echo "w - (positive number, default = 1) warning threshold for files"
}

printvariables() {
        echo "Variables:"
        #Add all your variables at the en of the "for" line to display them in verbose
        for i in WARNING_THRESHOLD CRITICAL_THRESHOLD FINAL_STATE FINAL_COMMENT ENABLE_PERFDATA VERSION PATH_TO_CHECK EXCLUDE_PATTERN INCLUDE_PATTERN FIND_COMMAND AGE_DAYS AGE_MINUTES MAXDEPTH
        do
                echo -n "$i : "
                eval echo \$${i}
        done
        echo
}

#Set to unknown in case of unplaned exit
FINAL_STATE=$STATE_UNKNOWN
FINAL_COMMENT="UNKNOWN: Unplaned exit. You should check that everything is alright"

#Default values
WARNING_THRESHOLD=1
CRITICAL_THRESHOLD=1
ENABLE_PERFDATA=1
VERSION="1.1"
MAXDEPTH=1

#Process arguments. Add proper options and processing
while getopts ":c:d:D:e:hi:m:p:vVw:" opt; do
        case $opt in
        c)
                CRITICAL_THRESHOLD=$OPTARG
                ;;
        d)
                AGE_DAYS=$OPTARG
                ;;
        D)
                MAXDEPTH=$OPTARG
                ;;
        e)
                EXCLUDE_PATTERN=$OPTARG
                ;;
        h)
                printusage
                exit $STATE_OK
                ;;
        i)
                INCLUDE_PATTERN=$OPTARG
                ;;
        m)
                AGE_MINUTES=$OPTARG
                ;;
        p)
                PATH_TO_CHECK=$OPTARG
                ;;
        v)
                echo "Verbose mode ON"
                echo
                VERBOSE=1
                ;;
        V)
                printversion
                exit $STATE_UNKNOWN
                ;;
        w)
                WARNING_THRESHOLD=$OPTARG
                ;;
        \?)
                echo "UNKNOWN: Invalid option: -$OPTARG"
                exit $STATE_UNKNOWN
                ;;
        :)
                echo "UNKNOWN: Option -$OPTARG requires an argument."
                exit $STATE_UNKNOWN
                ;;
        esac
done

#Check all the mandatory arguments, adapt to your case
if [[ -z $CRITICAL_THRESHOLD || -z $WARNING_THRESHOLD ]]; then
        echo "UNKNOWN: No warning or critical threshold given"
        printusage
        exit $STATE_UNKNOWN
fi

if [[ -z $PATH_TO_CHECK ]]; then
        echo "UNKNOWN: No path given"
        printusage
        exit $STATE_UNKNOWN
fi
#TODO check directory exists
if [[ ! -d $PATH_TO_CHECK && ! -f $PATH_TO_CHECK ]]; then
        echo "UNKNOWN: Path $PATH_TO_CHECK doesn't exist, no file or directory found"
        exit $STATE_UNKNOWN
fi

#Building command according to given arguments
FIND_COMMAND="$FIND_COMMAND '$PATH_TO_CHECK'"

#Adding age criteria (mtime OR mmin)
if [[ -n $AGE_MINUTES ]]; then
        FIND_COMMAND="$FIND_COMMAND -mmin $AGE_MINUTES"
elif [[ -n $AGE_DAYS ]]; then
        FIND_COMMAND="$FIND_COMMAND -mtime $AGE_DAYS"
fi

#Include pattern if any
if [[ -n $INCLUDE_PATTERN ]]; then
        FIND_COMMAND="$FIND_COMMAND -name \"*$INCLUDE_PATTERN*\""
fi

#Adding the depth criteria
if [[ -n $MAXDEPTH ]]; then
        FIND_COMMAND="$FIND_COMMAND -maxdepth $MAXDEPTH"
fi

#Checking for files only and remove error output
FIND_COMMAND="$FIND_COMMAND -type f 2>/dev/null"

#Exclude pattern if any
if [[ -n $EXCLUDE_PATTERN ]]; then
        FIND_COMMAND="$FIND_COMMAND | grep -v $EXCLUDE_PATTERN"
fi

#Count lines (aka files matching criteria)
FIND_COMMAND="$FIND_COMMAND | wc -l"

#Executing and storing result
#echo $FIND_COMMAND
CHECK_VALUE=$(eval $FIND_COMMAND)

if [[ $CHECK_VALUE -ge $CRITICAL_THRESHOLD ]]; then
        FINAL_COMMENT="CRITICAL: $CHECK_VALUE found matching criteria in $PATH_TO_CHECK"
        FINAL_STATE=$STATE_CRITICAL
else
        if [[ $CHECK_VALUE -ge $WARNING_THRESHOLD ]]; then
                FINAL_COMMENT="WARNING: $CHECK_VALUE found matching criteria in $PATH_TO_CHECK"
                FINAL_STATE=$STATE_WARNING
        else
                FINAL_COMMENT="OK: $CHECK_VALUE found matching criteria in $PATH_TO_CHECK"
                FINAL_STATE=$STATE_OK
        fi
fi

# - Put numbered the values in $CHECK_VALUE, used for perfdata

#Perfdata processing, if applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
        PERFDATA=" | nbFiles=$CHECK_VALUE;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;"
fi

#Script end, display verbose information
if [[ $VERBOSE -eq 1 ]] ; then
        printvariables
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
