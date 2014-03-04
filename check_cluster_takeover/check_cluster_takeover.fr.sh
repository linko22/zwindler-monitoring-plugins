#!/bin/bash
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
#Check permettant d'avertir sur la console quand un cluster heartbeat vient de changer de noeud
################################################################################
#Ce script se base sur la presence d'un fichier /tmp/[nom_du_cluster]
#Il compare simplement les entrees dans le fichier et verifie qu'il n'y ait
#qu'un seul nom dans le X dernieres entrees
#Le fichier en question doit donc etre regulierement alimente par le noeud
#maitre de la facon suivante : [DATE];[HOSTNAME_NOEUD_MAITRE];

#Constantes Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

FINAL_STATE=$UNKNOWN
FINAL_COMMENT="Une erreur dans le script ou un echec de la commande empeche la verification, merci de verifier que tout fonctionne bien comme il le devrait"

#Variables a modifier en fonction du contexte
WARNING_LIMIT=1
CRITICAL_LIMIT=1
HISTORY=12
ENABLE_PERFDATA=0
CLUSTER_MASTER_LOG_PATH=/tmp/

#Recuperation des arguments
if [[ $1 == "-v" ]]; then
        echo "Activation du verbose mode"
        echo
        VERBOSE=1
        shift
fi

if [[ -n $1 ]] ; then
        CLUSTER_MASTER_LOG_PATH=${CLUSTER_MASTER_LOG_PATH}check_cluster_takeover_$1
        shift
else
        echo "UNKNOWN : Erreur dans les arguments"
        exit $UNKNOWN
fi

if [[ -n $1 ]] ; then
        WARNING_LIMIT=$1
fi
if [[ -n $2 ]] ; then
        CRITICAL_LIMIT=$2
fi
if [[ -n $3 ]] ; then
        HISTORY=$3
fi

#Execution du script a proprement parler
LINE_NUMBER=`cat $CLUSTER_MASTER_LOG_PATH | wc -l`
if [[ ! -f $CLUSTER_MASTER_LOG_PATH ]] || [[ $LINE_NUMBER -eq 0 ]] ; then
        FINAL_COMMENT="WARNING : attention, le fichier $CLUSTER_MASTER_LOG_PATH n'existe pas ou est vide => pas d'info sur le cluster"
        FINAL_STATE=$WARNING
fi
#Ici on recuppere supprime tous les doublons dans le fichier
UNIQUE=`tail -${HISTORY} $CLUSTER_MASTER_LOG_PATH | uniq | wc -l`
#Le nombre de bascule est egal au resultat precedent - 1
TAKEOVER=`echo "$UNIQUE - 1" | bc`
TIMERANGE=`echo "$HISTORY * 5" | bc`
MESSAGE="$TAKEOVER bascule(s) dans l'intervalle de temps determine ($TIMERANGE minutes)"

if [[ TAKEOVER -ge CRITICAL_LIMIT ]] ; then
        FINAL_COMMENT="CRITICAL : Attention, $MESSAGE"
        FINAL_STATE=$CRITICAL
elif [[ TAKEOVER -ge WARNING_LIMIT ]] ; then
        FINAL_COMMENT="WARNING : Attention, $MESSAGE"
        FINAL_STATE=$WARNING
else
        FINAL_COMMENT="OK : $MESSAGE"
        FINAL_STATE=$OK
fi

#Fin du script
if [[ $VERBOSE -eq 1 ]] ; then
        echo "Variables :"
        #Ajouter en fin de ligne les variables a afficher en mode verbose
        for i in WARNING_LIMIT CRITICAL_LIMIT HISTORY CLUSTER_MASTER_LOG_PATH LINE_NUMBER TAKEOVER
        do
                echo -n "$i : "
                eval echo \$${i}
        done
        echo
fi

echo ${FINAL_COMMENT}
exit $FINAL_STATE
