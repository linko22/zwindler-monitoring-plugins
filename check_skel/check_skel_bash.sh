#!/bin/bash
#Bash Nagios plugin skeleton
############################################################################
#This file is a part of zwindler-monitoring-plugins repository
#Copyright (C) 2014 zwindler
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
################################################################################
#Nagios Constants
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

#Set to unknown in case of unplaned exit
FINAL_STATE=$UNKNOWN
FINAL_COMMENT="UNKNOWN : Unplaned exit. You should check that everything is alright"

#Default values (should be changed according to context)
WARNING_LIMIT=1
CRITICAL_LIMIT=2
ENABLE_PERFDATA=0

#Process arguments. Add proper options and processing
while getopts ":vc:w:" opt; do
	case $opt in
		v)
			echo "Verbose mode ON"
			echo
			VERBOSE=1
			;;
		c)
			CRITICAL_LIMIT=$OPTARG
			;;
		w)
			WARNING_LIMIT=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

#In case some arguments are mandatory (like -a), check for them
#if [[ -z $MY_ARGUMENT ]] ; then
#        #TODO %USAGE
#        echo "Usage : $0 [-v] -a MY_ARGUMENT -v WARNING_LIMIT -c CRITICAL_LIMIT"
#        exit 1
#fi

#Real check goes here. Write your own code according to context
#####REAL CHECK GOES HERE
#At the end of this, you should 
# - Put check status in $FINAL_STATE
# - Put check output in $FINAL_COMMENT
# - Put numbered the values in $CHECK_VALUE, used for perfdata

#Perfdata processing, if applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
	PERFDATA=" | $CHECK_VALUE;$WARNING_LIMIT;$CRITICAL_LIMIT;"
fi

#Script end, display verbose information
if [[ $VERBOSE -eq 1 ]] ; then
	echo "Variables :"
	#Add all your variables at the en of the "for" line to display them 
	for i in WARNING_LIMIT CRITICAL_LIMIT
	do
		echo -n "$i : "
		eval echo \$${i}
	done
	echo
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
