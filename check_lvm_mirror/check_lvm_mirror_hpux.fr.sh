#!/bin/ksh
################################################################################
# Script permettant de verifier qu'un miroir LVM donne est bien actif
################################################################################
# 22/05/2013 : Premiere version, adaptation de la version Linux
################################################################################
#Constantes Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

FINAL_STATE=$UNKNOWN
FINAL_COMMENT="UNKNOWN : Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que tout fonctionne bien comme il le devrait"

#Valeur par defaut de variable.
#On met le CRITICAL a 0 car le miroir doit au minimum comprendre 2 membres. Warning ne sert a rien je pense
WARNING_LIMIT=0
CRITICAL_LIMIT=0
ENABLE_PERFDATA=1

#Recuperation des arguments
if [[ $1 == "-v" ]]; then
        echo "Activation du verbose mode"
        echo
        VERBOSE=1
        shift
fi

#Si on a des arguments et qu'on veut les verifier
if [[ -z $1 ]] ; then
        #Faire une fonction USAGE
        echo "Usage : $0 [-v] VG_NAME LV_NAME WARNING_LIMIT CRITICAL_LIMIT"
        exit 1
else
        VG_NAME=$1
        shift
        LV_NAME=$1
        shift
fi
if [[ -n $1 ]] ; then
        WARNING_LIMIT=$1
fi
if [[ -n $2 ]] ; then
        CRITICAL_LIMIT=$2
fi

#Execution du script a proprement parler
/sbin/lvdisplay /dev/$VG_NAME/$LV_NAME > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
        FINAL_COMMENT="UNKNOWN : LV non trouve"
else
		#Verification du nombre de pates du miroir
		MIRROR_COPIES=`/sbin/lvdisplay -F /dev/$VG_NAME/$LV_NAME | awk -F ":" '{print $5}'`
		
		if [[ $MIRROR_COPIES != "mirror_copies=1" ]]; then
                FINAL_STATE=$CRITICAL
                FINAL_COMMENT="CRITICAL : $MIRROR_COPIES, pas de miroir!"
		else
				STALE=`/sbin/lvdisplay -v /dev/$VG_NAME/$LV_NAME | grep -i stale | wc -l`
				if [[ $STALE -ne 0 ]] ; then
						FINAL_STATE=$WARNING
						FINAL_COMMENT="OK : $MIRROR_COPIES, mais $STALE PE sont a l'etat STALE!"						
				else
						FINAL_STATE=$OK
						FINAL_COMMENT="OK : $MIRROR_COPIES, le miroir semble operationnel et synchronise"
				fi
		fi
fi

#Generation des PERFDATA si c'est applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
		CHECK_VALUE="stale=$STALE"
        PERFDATA=" | $CHECK_VALUE;$WARNING_LIMIT;$CRITICAL_LIMIT;"
fi

#Fin du script
if [[ $VERBOSE -eq 1 ]] ; then
        echo "Variables :"
        #Ajouter en fin de ligne les variables a afficher en mode verbose
        for i in VG_NAME LV_NAME MIRROR_COPIES STALE WARNING_LIMIT CRITICAL_LIMIT
        do
                echo -n "$i : "
                eval echo \$${i}
        done
        echo
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
