#!/usr/bin/python
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
#Script permettant de remonter a Nagios les echecs des sessions a partir
#des datalists et d'un nombre de "runs" donne
#############################################################################
#24 octobre 2013 - Permiere version
#############################################################################
import os
import shutil
import string
import time
import datetime
import sys
import getopt

#Initialisation des constantes Nagios et DP
nagios_output={0: 'OK', 1: 'WARNING', 2: 'CRITICAL', 3: 'UNKNOWN'};

#Une fonction pour afficher de maniere propre mes tables en fin de traitement
def print_table(table):
        table.sort()
        for item in table:
                print item

def usage():
        """
        Affiche l information usage
        """
        print """
Usage: """ + sys.argv[0] + """ -d datalist [-n number_run] [-l number_days] [-s]

-d, --datalist
   Nom de la datalist definie dans DataProtector
-n, --number_run
   Nombre correspondant au X derniere sauvegarde pour la Datalist
-l, --last
   Specifie le nombre de jours par defaut pris en compte dans la commande omnidb
   Par defaut, 15 jours, mais il peut etre utile
         - de reduire ce nombre si la datalist doit tourner souvent
         - de l'augmenter si elle tourne rarement
   "-1" permet de prendre en compte l'ensemble des sessions presente dans l'IDB
   au risque qu'elles soient tres tres anciennes ;-)
-s, --strict
   Durcie les conditions d'affichage des erreurs.
         - Completed/Errors retourne WARNING au lieu de OK
         - Completed/Failure retourne CRITICAL au lieu de WARNING
-h, --help
   Affiche l'aide
"""


def open_report_file(filepath, datalist):
        #print filepath
        file_output = []
        #Lecture du fichier
        f = open(filepath, "r")
        line_number=len(f.readlines())
        #print line_number
        f = open(filepath, "r")

        current_line=0
        if line_number == 0:
                print nagios_output[3]+": Aucune session "+datalist+" dans l'IDB. Verifier le nom de la datalist ou augmentez le parametre last"
                sys.exit(3)
        for line in f:
                current_line = current_line + 1
                #print line
                #print current_line
                #print line_number
                #Suppression de l'espace dans "In Progress"
                line=line.replace("In Progress", "InProgress")
                if (current_line > 2):
                        splitted_line = line.split()
                        #Debug
                        #print line
                        #print splitted_line
                        file_output.append((splitted_line[0],splitted_line[2]))
        return file_output

def main():
        try:
                opts, args = getopt.getopt(sys.argv[1:], 'dnslh', ['datalist=', 'number_run=', 'strict', 'last=', 'help'])
        except getopt.GetoptError:
                usage()
                sys.exit(3)

        strict_mode = False
        datalist = ""
        last=" -last 15"
        number_run = 3
        for o, a in opts:
                if o in ('-d', '--datalist'):
                        datalist = a
                if o in ('-n', '--number_run'):
                        number_run = int(a)
                if o in ('-s', '--strict'):
                        strict_mode = True
                if o in ('-l', '--last'):
                        #Si on specifie -1, on supprime le parametre last
                        if int(a) == -1:
                                last=""
                        else:
                                last=" -last "+a
                if o in ('-h', '--help'):
                        usage()
                        sys.exit(3)

        if datalist == "":
                usage()
                sys.exit(3)

        #Lier des status DP a un status Nagios, plus ou moins stricte en fonction de la presence ou non du mode --strict
        if strict_mode:
                job_status_list={'Completed': 0, 'Completed/Errors': 1, 'Completed/Failure': 2, 'Failed': 2, 'Aborted': 2, 'InProgress': 3, 'Queuing': 3, 'InProgress/Error': 3}
        else:
                job_status_list={'Completed': 0, 'Completed/Errors': 0, 'Completed/Failure': 1, 'Failed': 2, 'Aborted': 2, 'InProgress': 3, 'Queuing': 3, 'InProgress/Error': 3}

        #Initialisation des variables
        local_path="/tmp/"

        #Initialisation des tables
        file_output=[]

        #Generation des commandes et des fichiers
        filename="check_dp_spec.py."+datalist+".output"
        report_command='/opt/omni/bin/omnidb -session'+last+' -datalist "'+datalist+'" &> '+local_path+filename+' 2> '+local_path+filename+'err'

        #Recuperation du fichier rapport
        #print report_command
        os_return=os.system(report_command)

        #Formattage du contenu de la commande
        file_output=open_report_file(local_path+filename, datalist)
        #Debug
        #print_table(file_output)

        if os_return != 0:
                print(nagios_output[3]+": Erreur lors du retour de la commande omnidb. Verifier l'IDB et le nom de la datalist et le log"+local_path+filename+"err")
                sys.exit(3)

        last_nagcode=3
        check_output=" erreur lors de l'execution du script"
        current_run=0
        last_nagcode_run=0
        flag_qip=False
        for backup_job in reversed(file_output):
                nagcode=job_status_list[backup_job[1]]
                #Debug
                #print backup_job
                #print nagcode
                #print number_run
                if nagcode < last_nagcode:
                        last_nagcode=nagcode
                        last_nagcode_run=current_run
                        last_backup_job_id=backup_job[0]
                current_run = current_run + 1

                #Cas Queuing ou InProgress, on va un cran plus loin, pour voir
                if last_nagcode == 3:
                        number_run = number_run + 1
                        flag_qip=True
                #Si on arrive a 0, c'est qu'il faut s'arreter la
                if current_run >= number_run:
                        break

        if last_nagcode == 0:
                check_output=" derniere sauvegarde OK : "+last_backup_job_id+" (N-"+str(last_nagcode_run)+")"
        if last_nagcode == 1:
                check_output=" derniere sauvegarde terminee avec des erreurs/echecs : "+last_backup_job_id+" (N-"+str(last_nagcode_run)+")"
        if last_nagcode == 2:
                check_output=" 100% d'echecs sur les "+str(current_run)+" derniers run (jusqu'au job "+last_backup_job_id+")"

        qip_output=""
        if flag_qip:
                qip_output=" SAUVEGARDE EN COURS, et"

        print nagios_output[last_nagcode]+":"+qip_output+check_output
        sys.exit(last_nagcode)

if __name__ == "__main__":
        main()
