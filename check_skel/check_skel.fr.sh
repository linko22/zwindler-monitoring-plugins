#!/bin/bash
#Squelette de plugin Nagios perso

#Constantes Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

#En cas de sortie non prevue du script
FINAL_STATE=$UNKNOWN
FINAL_COMMENT="UNKNOWN : Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que tout fonctionne bien comme il le devrait"

#Valeur par defaut de variable (a modifier en fonction du contexte)
WARNING_LIMIT=1
CRITICAL_LIMIT=2
ENABLE_PERFDATA=0

#Si on a des arguments et qu'on veut les verifier
if [[ -z $1 ]] ; then
        #Faire une fonction USAGE
        echo "Usage : $0 [-v] MY_ARGUMENT WARNING_LIMIT CRITICAL_LIMIT"
        exit 1
fi

#Recuperation des arguments
if [[ $1 == "-v" ]]; then
        echo "Activation du verbose mode"
        echo
        VERBOSE=1
        shift
fi
if [[ $# -ge 1 ]]; then
        MY_ARGUMENT=$1
        shift
        #MY_ARGUMENT_2=$1
        #shift
else
        #Faire une fonction USAGE
        echo "Pas assez d'arguments !"
        echo "Usage : $0 [-v] MY_ARGUMENT WARNING_LIMIT CRITICAL_LIMIT"
        exit 1
fi
if [[ -n $1 ]] ; then
        WARNING_LIMIT=$1
fi
if [[ -n $2 ]] ; then
        CRITICAL_LIMIT=$2
fi

#Execution du script a proprement parler
#A remplir en fonction du contexte

#Generation des PERFDATA si c'est applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
	PERFDATA=" | $CHECK_VALUE;$WARNING_LIMIT;$CRITICAL_LIMIT;"
fi

#Fin du script
if [[ $VERBOSE -eq 1 ]] ; then
        echo "Variables :"
	#Ajouter en fin de ligne les variables a afficher en mode verbose
	for i in WARNING_LIMIT CRITICAL_LIMIT
	do
		echo -n "$i : "
		eval echo \$${i}
	done
	echo
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE

