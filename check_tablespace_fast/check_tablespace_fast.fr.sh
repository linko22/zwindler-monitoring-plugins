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
################################################################################
# Script permettant de verifier rapidement le remplissage des tablespaces de
# la base a l'aide d'une vue Oracle (dans certaines bases check_oracle_health
# part en timeout malgre la requete efficace)
################################################################################
# 17/10/2013 : Premiere version
################################################################################

#Constantes Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

FINAL_STATE=$UNKNOWN
FINAL_COMMENT="UNKNOWN : Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que tout fonctionne bien comme il le devrait"

#Path Oracle, a changer en fonction evidemment. TODO argument
PATH="$PATH:/appli/oracle/10.2.0/bin"
export ORACLE_HOME="/appli/oracle/10.2.0"

#Valeur par defaut de variable
LOG_PATH="/tmp/"
WARNING_LIMIT=95
CRITICAL_LIMIT=98

if [[ -z $1 ]] ; then
        #Faire une fonction USAGE
        echo "Usage : $0 [-v] INSTANCE USER PASSWORD WARNING_LIMIT CRITICAL_LIMIT"
        exit 1
fi

#Recuperation des arguments
if [[ "$1" = "-v" ]]; then
        echo "Activation du verbose mode"
        echo
        VERBOSE=1
        shift
fi
if [[ "$#" -ge 3 ]]; then
        INSTANCE=$1
        shift
        USER=$1
        shift
        PASSWORD=$1
        shift
else
        #Faire une fonction USAGE
        echo "Pas assez d'arguments !"
        echo "Usage : $0 [-v] INSTANCE USER PASSWORD WARNING_LIMIT CRITICAL_LIMIT"
        exit 1
fi
if [[ -n $1 ]] ; then
        WARNING_LIMIT=$1
fi
if [[ -n $2 ]] ; then
        CRITICAL_LIMIT=$2
fi

FILE_CRITICAL=${LOG_PATH}${INSTANCE}"_critical_tablespace"
FILE_WARNING=${LOG_PATH}${INSTANCE}"_warning_tablespace"

#On verifie les tablespaces critiques
sqlplus -S ${USER}/${PASSWORD}@${INSTANCE} << EOT 2>&1 1>/dev/null
SPOOL $FILE_CRITICAL
SET pagesize 100
select tablespace_name, used_percent
from dba_tablespace_usage_metrics
where USED_PERCENT > $CRITICAL_LIMIT;
SPOOL off
exit
EOT

#On verifie les tablespaces en alerte
sqlplus -S ${USER}/${PASSWORD}@${INSTANCE} << EOT 2>&1 1>/dev/null
SPOOL $FILE_WARNING
SET pagesize 100
select tablespace_name, used_percent
from dba_tablespace_usage_metrics
where USED_PERCENT > $WARNING_LIMIT;
SPOOL off
exit
EOT

TEST_CRITICAL_OUTPUT=`/usr/bin/tail -n +4 ${FILE_CRITICAL}.lst`
TEST_WARNING_OUTPUT=`/usr/bin/tail -n +4 ${FILE_WARNING}.lst`
if [[ -n $TEST_CRITICAL_OUTPUT ]]; then
        FINAL_COMMENT="CRITICAL, tablespace(s) en erreur : $TEST_CRITICAL_OUTPUT"
        FINAL_STATE=$CRITICAL
elif [[ -n $TEST_WARNING_OUTPUT ]]; then
        FINAL_COMMENT="WARNING, tablespace(s) en alerte : $TEST_WARNING_OUTPUT"
        FINAL_STATE=$WARNING
else
        FINAL_COMMENT="OK, pas d'alerte sur les tablespaces"
        FINAL_STATE=$OK
fi

#Fin du script
if [[ $VERBOSE -eq 1 ]] ; then
        echo "Variables :"
        #Ajouter en fin de ligne les variables a afficher en mode verbose
        for i in INSTANCE USER PASSWORD WARNING_LIMIT CRITICAL_LIMIT
        do
                echo "$i : "
                eval echo \$${i}
        done
        echo
fi

echo ${FINAL_COMMENT}
exit $FINAL_STATE
