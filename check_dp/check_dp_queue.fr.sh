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
#Script permettant de remonter le nombre de job en attente dans DataProtector
#############################################################################
#05/03/2012 - Permiere version
#############################################################################
#10/09/2012 - Ajout d'une alarme dans le cas ou on a plus de sessions en
#             que de lecteurs disponible => BUG DataProtector
#############################################################################
#25/10/2012 - Modification de l'alarme pour les sessions (mise a part)
#############################################################################

#Definition des variables Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

FINAL_STATE=$UNKNOWN
FINAL_COMMENT="Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que ton fonctionne bien comme il le devrait"

#Recuperation des arguments
if [[ $1 -eq "" ]] ; then
        WARNING_LIMIT=3
else
        WARNING_LIMIT=$1
fi
if [[ $2 -eq "" ]] ; then
        CRITICAL_LIMIT=5
else
        CRITICAL_LIMIT=$2
fi

PROGRESS=`/opt/omni/bin/omnistat | grep "In Progress" | wc -l`
RET_1=$?
QUEUED=`/opt/omni/bin/omnistat | grep "Queuing"  |wc -l`
RET_2=$?

PERFDATA=" | In_Progress=$PROGRESS;$WARNING_LIMIT;$CRITICAL_LIMIT Queued=$QUEUED;$WARNING_LIMIT;$CRITICAL_LIMIT"

if [[ $RET_1 -eq 0 ]] || [[ RET_2 -eq 0 ]] ; then
        if [[ QUEUED -gt $CRITICAL_LIMIT ]] ; then
                FINAL_COMMENT="CRITICAL : le nombre de sauvegardes en attente ($QUEUED) depasse le seuil critique specifie"
                FINAL_STATE=$CRITICAL
        elif [[ QUEUED -gt $WARNING_LIMIT ]] ; then
                FINAL_COMMENT="WARNING : le nombre de sauvegardes en attente ($QUEUED) depasse le seuil d'alerte specifie"
                FINAL_STATE=$WARNING
        else
                FINAL_COMMENT="OK : le nombre de sauvegardes en cours et en attente ($PROGRESS en cours + $QUEUED en attente) ne depasse pas les seuils specifies "
                FINAL_STATE=$OK
        fi
fi

if [[ $PROGRESS -gt $CRITICAL_LIMIT ]] ; then
        FINAL_COMMENT="CRITICAL : le nombre de sauvegardes en cours ($PROGRESS actives / 2 lecteurs) depasse le seuil d'alerte critique. Verifier les lecteurs!"
        FINAL_STATE=$CRITICAL
elif [[ $PROGRESS -gt $WARNING_LIMIT ]] ; then
        FINAL_COMMENT="WARNING : le nombre de sauvegardes en cours ($PROGRESS actives / 2 lecteurs) depasse le seuil d'alerte. Verifier les lecteurs!"
        FINAL_STATE=$WARNING
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
