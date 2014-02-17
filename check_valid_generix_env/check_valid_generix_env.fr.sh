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
################################################################################
# Script permettant de verifier tout un tas de petites choses qui font foirer
# un environnement Generix
################################################################################
# 20/05/2013 : Premiere version
################################################################################
#Mode debug
#set -vx
#Constantes Nagios
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

FINAL_STATE=$UNKNOWN

#Valeur par defaut de variable.
#Pas de pitie, pas de tendresse => 1 erreur = CRITICAL
WARNING_LIMIT=0
CRITICAL_LIMIT=1
ENABLE_PERFDATA=1

#On prend uniquement les fichiers modifies depuis les 30 derniers jours
DATE_MOD="-mtime -30"
ERRORS=0
#ERRORS=`expr $ERRORS + 1`

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
        echo "Usage : $0 [-v] ENV_PATH [DATE_MOD] [WARNING_LIMIT CRITICAL_LIMIT]"
        exit 1
else
        ENV_PATH=$1
        shift
fi
#cd $ENV_PATH

if [[ -n $1 ]] ; then
        #On part du principe que si on met 0, c'est qu'on veut verifier tous les fichiers
        if [[ $1 == "0" ]]; then
                DATE_MOD=""
        else
        #Dans le cas contraire, on prend le nombre de jours
                DATE_MOD="-mtime -"$1
        fi
        shift
fi
if [[ -n $1 ]] ; then
        WARNING_LIMIT=$1
fi
if [[ -n $2 ]] ; then
        CRITICAL_LIMIT=$2
fi

#TODO Creer un fichier temporaire unique
TEMP_FILE="/tmp/check_valid_generix_env_`basename $ENV_PATH`"

#Fonction de verification du format texte DOS/Unix
#Retourne 0 si Unix
#Retourne 1 si DOS
function text_dos_unix(){
    #Pour chaque fichier en entree, on verifie d'abord que c'est bien un fichier texte
    #Ensuite on verifie qu'on a pas de CRLF
    FILE=$1
    if [[ `file $FILE | grep text` ]]; then
        file $FILE | grep text | grep -v CRLF > /dev/null
        return $?
    fi
}

#Fonction de verification des fichiers exe generix
#Retourne 0 si OK
#Retourne different de 0 si KO
function exe_ok(){
        #Pour chaque fichier en entree, on verifie d'abord que c'est bien un binaire
        #Ensuite on verifie qu'il fonctionne
        if [[ `file $1 | grep "LSB executable"` ]]; then
                $1 -version > /dev/null
                return $?
        fi
}

#Execution du script a proprement parler
if [[ ! -d $ENV_PATH ]]; then
        FINAL_COMMENT="UNKNOWN : Chemin non trouve"
else
                #Verification des fichiers vitaux
                for FILE in $ENV_PATH/generix.ini $ENV_PATH/site/cnxtab.txt $ENV_PATH/site/elements.ini; do
                        if [[ ! -f $FILE ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT $FILE absent; " ; fi
                        `text_dos_unix $FILE`
                        if [[ $? -eq 1 ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT conf $FILE au format DOS; " ; fi
                done

                #Verification des dossiers
                FOLDERS=`grep "=ap/" $ENV_PATH/generix.ini | awk '{ FS = "=ap/" ; print $2 }' | sort | uniq -u`
                for i in $FOLDERS; do
                        if [[ ! -d $ENV_PATH/$i ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT dossier $ENV_PATH/$i manquant; " ; fi
                done

                #Verification des shells
                find -P $ENV_PATH/shell -mount -type f $DATE_MOD > $TEMP_FILE
                for i in `cat $TEMP_FILE`; do
                        `text_dos_unix $i`
                        if [[ $? -eq 1 ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT script $i au format DOS; " ; fi
                done

                #Verification des exe (scripts), puis des exe (binaires generix)
                find -P $ENV_PATH/exe -mount -type f $DATE_MOD > $TEMP_FILE
                for i in `cat $TEMP_FILE`; do
                        `text_dos_unix $i`
                        if [[ $? -ne 0 ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT script $i au format DOS; " ; fi
                done
                for i in `cat $TEMP_FILE`; do
                        `exe_ok $i`
                        if [[ $? -ne 0 ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT binaire $i mal transfere; " ; fi
                done

                #Verification des maquettes
                find -P $ENV_PATH/langue -mount -type f $DATE_MOD > $TEMP_FILE
                for i in `grep -e "\.maq$" $TEMP_FILE`; do
                        `text_dos_unix $i`
                        if [[ $? -ne 0 ]]; then ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT maquette $i au format DOS; " ; fi
                done

		#Verification des liens p-XXXX.ksh
		for i in `find -P $ENV_PATH/shell -name "p-*.ksh" -type f`; do
			ERRORS=`expr $ERRORS + 1`; FINAL_COMMENT="$FINAL_COMMENT lien symbolique $i mal cree; " ;
		done
		
        if [[ $ERRORS -ge $CRITICAL_LIMIT ]]; then
                FINAL_STATE=$CRITICAL
                FINAL_COMMENT="CRITICAL : Nombre d'erreur(s) $ERRORS : $FINAL_COMMENT"
        else
                FINAL_STATE=$OK
                FINAL_COMMENT="OK : Nombre d'erreur(s) = $ERRORS"
        fi
fi

#Generation des PERFDATA si c'est applicable
if [[ $ENABLE_PERFDATA -eq 1 ]] ; then
                CHECK_VALUE="nb_erreurs=$ERRORS"
        PERFDATA=" | $CHECK_VALUE;$WARNING_LIMIT;$CRITICAL_LIMIT;"
fi

#Fin du script
if [[ $VERBOSE -eq 1 ]] ; then
        echo "Variables :"
        #Ajouter en fin de ligne les variables a afficher en mode verbose
        for i in ENV_PATH DATE_MOD TEMP_FILE WARNING_LIMIT CRITICAL_LIMIT
        do
                echo -n "$i : "
                eval echo \$${i}
        done
        echo
fi

echo ${FINAL_COMMENT}${PERFDATA}
exit $FINAL_STATE
