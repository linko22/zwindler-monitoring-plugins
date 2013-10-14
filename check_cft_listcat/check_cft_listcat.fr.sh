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
#Script qui verifie que le catalogue ne s'approche pas de la taille limite.
#Il peut etre combine avec un script qui purge le catalogue en "event handler"
################################################################################
# 03/04/2012 : Premiere version
################################################################################
# 14/10/2013 : Modification des variables par defaut pour generalisation
################################################################################
TIMESTAMP=`date +%Y%m%d_%H%M%S`

CFTPATH="/Axway/Synchrony/Transfer_CFT"

. /etc/profile
PATH=$PATH:$HOME/bin:$CFTPATH/bin:$CFTPATH/scripts:$CFTPATH/runtime/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/usr/X11R6/bin:/home/axway/bin

export PATH
. $CFTPATH/home/profile

NBWARN=$1
if [[ -z $NBWARN ]] ; then NBWARN=8000 ; fi
NBCRIT=$2
if [[ -z $NBCRIT ]] ; then NBCRIT=9000 ; fi

#Fichier de log pour extract/debug
LOG=/tmp/check_cft_listcat.csv

NBUSED=`cftutil listcat | grep 'selected' | awk '{print $1}'`
PERFDATA=" | nbre=$NBUSED;$NBWARN;$NBCRIT;; "
RETCDE=$?

echo $TIMESTAMP\;$NBUSED >> $LOG

if [ $RETCDE -ne 0 ]
then
        echo "WARNING: Impossible de connaitre le nombre de transferts presents dans le catalogue CFT !!!!!!"
        exit 1
fi

if [ $NBUSED -gt $NBCRIT ]
        then
                echo "CRITICAL: Attention ${NBUSED} transferts presents dans le catalogue CFT, les process CFT s arretent si le catalogue est plein !!!!!! $PERFDATA"
                exit 2
fi

if [ $NBUSED -gt $NBWARN ]
        then
                echo "WARNING: Attention ${NBUSED} transferts presents dans le catalogue CFT, les process CFT s arretent si le catalogue est plein !!!!!! $PERFDATA"
                exit 1
        else
                echo "OK: $NBUSED transferts presents dans le catalogue CFT. $PERFDATA"
                exit 0
fi
