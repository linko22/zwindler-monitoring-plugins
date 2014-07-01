#!/bin/bash
#Squelette de plugin Nagios en bash
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
################################################################################
#Constantes Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3
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
	echo "A ecrire : ajouter des informations sur le scripts et les arguments a fournir"
}

printvariables() {
	echo "Variables:"
	#Ajouter toutes les variables utilisees dans le script a la suite de la ligne "for"
	for i in WARNING_THRESHOLD CRITICAL_THRESHOLD FINAL_STATE FINAL_COMMENT ENABLE_PERFDATA VERSION
	do
		echo -n "$i : "
		eval echo \$${i}
	done
	echo
}

#En cas de sortie non prevue du script
FINAL_STATE=$UNKNOWN
FINAL_COMMENT="UNKNOWN : Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que tout fonctionne bien comme il le devrait"

#Valeurs par defaut de variable (a modifier en fonction du contexte)
WARNING_THRESHOLD=1
CRITICAL_THRESHOLD=1
ENABLE_PERFDATA=0
VERSION="1.0"

#Recuperation des arguments. A modifier en fonction du contexte
while getopts ":c:hvVw:" opt; do
	case $opt in
	c)
		CRITICAL_THRESHOLD=$OPTARG
		;;
	h)
		printusage
		exit $STATE_OK
		;;
	v)
		echo "Mode 'verbose' active"
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
		echo "Option invalide: -$OPTARG" >&2
		exit $STATE_UNKNOWN
		;;
	:)
		echo "L'option -$OPTARG nécessite un argument." >&2
		exit 1
		;;
	esac
done

#Verification des arguments obligatoires (a modifier en fonction du contexte)
#if [[ -z $MY_ARGUMENT ]] ; then
#        #TODO %USAGE
#        echo "Usage : $0 [-v] -a MY_ARGUMENT -w WARNING_LIMIT -c CRITICAL_LIMIT"
#        exit 1
#fi

#Execution du script a proprement parler. A remplir en fonction du contexte
#####Le vrai code du check vient ici

#A la fin, vous devriez 
#- Affecter le status dans la variable $FINAL_STATE
#- Affecter le descriptif du check dans la variable $FINAL_COMMENT
#- Affecter les valeurs numériques dans la variable $FINAL_STATE, pour les données de performance

#Generation des PERFDATA si c'est applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
	PERFDATA=" | $CHECK_VALUE;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;"
fi

#Fin du script
if [[ $VERBOSE -eq 1 ]] ; then
	printvariables
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
