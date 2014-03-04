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
############################################################################
#Script a placer en crontab pour inscrire qui est le maitre du cluster sur le serveur Nagios
#Ex pour le cluster production :
#      */5 * * * * /appli/scripts/check_cluster_takeover_client.sh production
#PREREQUIS : faire un echange de cle SSH entre chaque noeuds et le serveur nagios

source /root/.bash_profile

#A MODIFIER !!! A MODIFIER !!! A MODIFIER !!!
IP_NAGIOS=1.1.1.1

if [[ -z $1 ]] ; then
        echo "Il faut absolument donner le nom du cluster en argument"
        exit 1
fi
CLUSTER_NAME=$1
NAGIOS_FILE=/tmp/check_cluster_takeover_${CLUSTER_NAME}
NODE_NODEMASTER=`uname -n`
MASTER=0
MASTER=`/sbin/ifconfig | grep -e "eth.:0" | wc -l`
if [[ $MASTER -ne 0 ]] ; then
        ssh nagios@${IP_NAGIOS} "echo ${NODE_NODEMASTER} >> ${NAGIOS_FILE}"
fi
