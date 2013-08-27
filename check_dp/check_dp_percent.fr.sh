#!/bin/bash
#Permet d'avoir un pourcentage brut des sauvegarde OK, moins les ARCHLOG
#############################################################################
#03 mai 2012 - Permiere version
#############################################################################
#05 juin 2012 - Prise en compte des 24 dernieres heures/60 derniers resultats
#plutot que le 10 derniers jours => statistiques moins lissees
#############################################################################

#Definition des variables Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

FINAL_STATE=$UNKNOWN
FINAL_COMMENT="Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que ton fonctionne bien comme il le devrait"

#Recuperation des arguments
if [[ $1 == "-v" ]]; then
        echo "Activation du verbose mode"
        VERBOSE=1
        shift
fi

if [[ $1 -eq "" ]] ; then
        WARNING_LIMIT=30
else
        WARNING_LIMIT=$1
fi
if [[ $2 -eq "" ]] ; then
        CRITICAL_LIMIT=50
else
        CRITICAL_LIMIT=$2
fi

SINCE=`date -d "1 day ago" +'%Y/%m/%d'`
FULL_COUNT=`/opt/omni/bin/omnidb -session -since $SINCE | tail -60 | grep Backup | wc -l`
FULL_OK_COUNT=`/opt/omni/bin/omnidb -session -since $SINCE | tail -60 | grep Completed | wc -l`
ARCH_COUNT=`/opt/omni/bin/omnidb -session -since $SINCE -datalist T1_ARCH_LOG_QUOTID | tail -60 | grep Backup | wc -l`
ARCH_OK_COUNT=`/opt/omni/bin/omnidb -session -since $SINCE -datalist T1_ARCH_LOG_QUOTID | tail -60 | grep Completed | wc -l`

JOBSSANSARCHLOG=`echo "scale=2; 1 - (($FULL_OK_COUNT - $ARCH_OK_COUNT) / ($FULL_COUNT - $ARCH_COUNT))" | bc`
JOBSSANSARCHLOG=`echo "100 * $JOBSSANSARCHLOG" | bc | cut -d "." -f 1`
JOBSAVECARCHLOG=`echo "scale=2; 1 - ($FULL_OK_COUNT / $FULL_COUNT)" | bc`
JOBSAVECARCHLOG=`echo "100 * $JOBSAVECARCHLOG" | bc | cut -d "." -f 1`

PERFDATA=" | %age_echec_sans_archlog=$JOBSSANSARCHLOG;$WARNING_LIMIT;$CRITICAL_LIMIT; %age_echec_archlog_compris=$JOBSAVECARCHLOG;$WARNING_LIMIT;$CRITICAL_LIMIT;"


if [[ $VERBOSE -eq 1 ]] ; then
        echo "Resultats :"
        echo "full count : $FULL_COUNT"
        echo "arch count : $ARCH_COUNT"
        echo "full ok count : $FULL_OK_COUNT"
        echo "arch ok count : $ARCH_OK_COUNT"
        echo ""
        echo "Pourcentage d'echec sur les jobs d'un jour sans les archlogs"
        echo "$JOBSSANSARCHLOG"
        echo "Pourcentage d'echec sur un jour tous jobs confondus"
        echo "$JOBSAVECARCHLOG"
fi

if [[ $JOBSSANSARCHLOG -gt $CRITICAL_LIMIT ]] || [[ $JOBSAVECARCHLOG -gt $CRITICAL_LIMIT ]] ; then
        FINAL_COMMENT="CRITICAL : ${JOBSSANSARCHLOG}% d'echecs des jobs de sauvegarde sans les archlogs et ${JOBSAVECARCHLOG}% d'echecs archlogs compris. Le pourcentage de sauvegardes en echec est inquietant, merci de jeter un oeil et de prevenir l'admin systeme qui est de quart"
        FINAL_STATE=$CRITICAL
elif [[ $JOBSSANSARCHLOG -gt $WARNING_LIMIT ]] || [[ $JOBSAVECARCHLOG -gt $WARNING_LIMIT ]] ; then
        FINAL_COMMENT="WARNING : ${JOBSSANSARCHLOG}% d'echecs des jobs de sauvegarde sans les archlogs et ${JOBSAVECARCHLOG}% d'echecs archlogs compris. Le pourcentage de sauvegardes en echec est consequent, a surveiller..."
        FINAL_STATE=$WARNING
else
        FINAL_COMMENT="OK : ${JOBSSANSARCHLOG}% d'echecs des jobs de sauvegarde sans les archlogs et ${JOBSAVECARCHLOG}% d'echecs archlogs compris. Le pourcentage de sauvegardes en echec ne depasse pas les seuils specifies "
        FINAL_STATE=$OK
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
