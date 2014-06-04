#!/bin/bash
#Plugin to check windows processes with the FULL path, which 
#check_snmp_process.pl doesn't do
################################################################################
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
	echo "Plugin to check windows processes with the FULL path, which"
	echo "check_snmp_process.pl doesn't do"
	echo
	echo "usage: '$0 [-O] -H hostname_or_IP -v [1|2c] -c community -p process_name -P 'WinDisk:\Path\to\process' -C critical_threshold -w warning_threshold'"
	echo "usage: '$0 -h' displays this message"
	echo "usage: '$0 -v' displays version"
	echo "-O for verbose output (debugging)"
}

printvariables() {
	echo "Variables:"
	#Add all your variables at the en of the "for" line to display them in verbose
	for i in HOSTNAME SNMPVERSION SNMPCOMMUNITY PROCNAME PROCPATH PROCESSES OIDS NUMPROC WARNING_THRESHOLD CRITICAL_THRESHOLD FINAL_STATE FINAL_COMMENT ENABLE_PERFDATA VERSION
	do
		echo -n "$i : "
		eval echo \$${i}
	done
	echo
}

#Set to unknown in case of unplaned exit
FINAL_STATE=$STATE_UNKNOWN
FINAL_COMMENT="UNKNOWN: Unplaned exit. You should check that everything is alright"

#Default values (should be changed according to context)
WARNING_THRESHOLD=1
CRITICAL_THRESHOLD=1
ENABLE_PERFDATA=1
VERSION="1.0"

#Process arguments. Add proper options and processing
while getopts ":c:C:hH:Op:P:v:Vw:" opt; do
	case $opt in
		c)
			SNMPCOMMUNITY=$OPTARG
			;;
		C)
			CRITICAL_THRESHOLD=$OPTARG
			;;
		h)
			printusage
			exit $STATE_OK
			;;
		H)
			HOSTNAME=$OPTARG
			;;
		O)
			echo "Verbose mode ON"
			echo
			VERBOSE=1
			;;
		p)
			PROCNAME=$OPTARG
			;;
		P)
			PROCPATH=$OPTARG
			;;
		v)
			SNMPVERSION=$OPTARG
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

if [[ -z $HOSTNAME || -z $SNMPVERSION || -z $SNMPCOMMUNITY]]; then
	echo "UNKNOWN: No hostname or snmp version or snmp community given"
	printusage
	exit $STATE_UNKNOWN
fi

if [[ -z $PROCNAME || -z $PROCPATH ]]; then
	echo "UNKNOWN: No processus name or processus path given"
	printusage
	exit $STATE_UNKNOWN
fi

PROCPATH=$(echo $PROCPATH | tr '\\' '/')
PROCESSES=$(snmpwalk $HOSTNAME -v $SNMPVERSION -c $SNMPCOMMUNITY HOST-RESOURCES-MIB::hrSWRunName 2>/dev/null |grep $PROCNAME  | awk -F"[. ]" '{print $2}')
#check if full pass
for i in $PROCESSES
do
        OIDS="$OIDS HOST-RESOURCES-MIB::hrSWRunPath.$i"
done
NUMPROC=$(snmpget $HOSTNAME -v $SNMPVERSION -c $SNMPCOMMUNITY $OIDS 2>/dev/null | sed -e 's/\\\\/\//g' | grep -i "$PROCPATH" | wc -l)
CHECK_VALUE="nbre_proc=$NUMPROC"

if [[ $NUMPROC -le $CRITICAL_THRESHOLD ]]; then
	FINAL_COMMENT="CRITICAL: There are less than $CHECK_VALUE $PROCPATH $PROCNAME on $SERVER_NAME!"
	FINAL_STATE=$STATE_CRITICAL
else
	if [[ $NUMPROC -le $WARNING_THRESHOLD ]]; then
		FINAL_COMMENT="WARNING: There are less than $CHECK_VALUE $PROCPATH $PROCNAME on $SERVER_NAME"
		FINAL_STATE=$STATE_WARNING
	else
		FINAL_COMMENT="OK: There are $CHECK_VALUE $PROCPATH $PROCNAME on $SERVER_NAME"
		FINAL_STATE=$STATE_OK
	fi
fi

#Perfdata processing, if applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
	PERFDATA=" | $CHECK_VALUE;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;"
fi

#Script end, display verbose information
if [[ $VERBOSE -eq 1 ]] ; then
	printvariables
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
