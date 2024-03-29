#!/bin/env python
# Nagios compatible check that gathers information from a Redhat Cluster Suite
# state, the current node state and services state
################################################################################
# Author seems to be Frank Clements <frank @ sixthtoe.net>
# This version is a modified version of the initial script found at
# https://github.com/opinkerfi/nagios-plugins/blob/master/check_rhcs/check_rhcs
# No licence found in this version
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
# Denis GERMAIN <dt.germain @ gmail.com>
# 08/08/2013 - Changed the way local node is found. Use the "local" parameter 
#                  instead of hostname, because hosts can have multiple names
#              Corrected a CRITICAL state returned as 1 (WARNING state from 
#                  nagios POV)
#              Added a safeguard and print usage when no argument given
#              Added a safeguard when information of the local node aren't found
################################################################################
# In RHEL 5, there is a bug in clustat preventing non-root users to use clustat
# https://bugzilla.redhat.com/show_bug.cgi?id=531273
# You might need to use setuid on clustat to change this if rgmanager cannot be
# upgraded to 3.0.7+
# $chown root:nagios /usr/sbin/clustat
# $chmod u+s /usr/sbin/clustat

import xml.dom.minidom
import os
import sys, socket
import getopt

def usage():
    """
    Display usage information
    """
    print """
Usage: """ + sys.argv[0] + """ ([-s serviceName] | [-c])

-c, --cluster
   Gathers the overall cluster status for the local node
-s, --service
   Gets the stats of the named service
-Z, --suspended
   Checks whether there are any suspended services
-h, --help
   Display this
"""

def getQuorumState(dom):
    """
    Get the quorum state.  This is a single inline element which only 
    has attributes and no children elements.
    """
    quorumList = dom.getElementsByTagName('quorum')
    quorumElement = quorumList[0]

    return quorumElement.attributes['quorate'].value


def getClusterName(dom):
    """
    Get the name of the cluster from the clustat output.
    This assumes only a single cluster is running for the moment.
    """
    clusterList = dom.getElementsByTagName('cluster')
    clusterElement = clusterList[0]

    return clusterElement.attributes['name'].value


def getLocalNodeState(dom):
    """
    Get the state of the local node
    """
    nodesList = dom.getElementsByTagName('node')
    nodeState = {}
    
    for node in nodesList:
        if node.attributes['local'].value == "1":
            nodeState['name'] = node.attributes['name'].value
            nodeState['state'] = node.attributes['state'].value 
            nodeState['rgmanager'] = node.attributes['rgmanager'].value 

        elif node.attributes['qdisk'].value == "1":
            if node.attributes['state'].value != "1":
                print "CRITICAL: Quorum disk " + node.attributes['name'].value + " is unavailable!"
                sys.exit(2)   
  
    return nodeState


def getServiceState(dom, service):
    """ 
    Get the state of the named service
    """
    groupList = dom.getElementsByTagName('group')
    hostname = socket.gethostname()
    serviceState = {}
    for group in groupList:
        if group.attributes['name'].value in (service,"service:"+service,"vm:"+service):
            serviceState['owner'] = group.attributes['owner'].value
            serviceState['state'] = group.attributes['state_str'].value
            serviceState['flags'] = group.attributes['flags_str'].value
                 
    return serviceState


def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], 's:cZh', ['service=', 'cluster', 'supsended', 'help'])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    check_suspend = False
    typeCheck = None
    for o, a in opts:
        if o in ('-c', '--cluster'):
            typeCheck = 'cluster'
        if o in ('-s', '--service'):
            typeCheck = 'service'
            serviceName = a
        if o in ('-Z', '--suspended'):
            check_suspend = True
        if o in ('-h', '--help'):
            usage()
            sys.exit()

    if typeCheck == None:
        usage()
        sys.exit()

    try:
        clustatOutput = os.popen('/usr/sbin/clustat -fx')
        dom = xml.dom.minidom.parse(clustatOutput)
    except Exception, e:
        print "UNKNOWN: could not parse output of : '/usr/sbin/clustat -fx': ", e
        sys.exit(3)
    if typeCheck == 'cluster':

        # First we query for the state of the cluster itself.
        # Should it be found tha the cluste ris not quorate we alert and exit immediately
        cluster = getClusterName(dom)
        qState  = getQuorumState(dom)

        # There are some serious problems if the cluster is inquorate so we simply alert immediately!
        if qState != "1":
            print "CRITICAL: Cluster " + cluster + " is inquorate!"
            sys.exit(2)

        # Now we find the status of the local node from clustat.
        # We only care about the local state since this way we can tie the alert to the host.
        nodeStates = getLocalNodeState(dom) 
    if nodeStates == {}:
            print "UNKNOWN: Local node informations couldn't be found!"
	    sys.exit(3)
        if nodeStates['state'] != "1":
            print "WARNING: Local node state is offline!"
            sys.exit(1)
        elif nodeStates['rgmanager'] != "1":
            print "CRITICAL: RGManager service not running on " + nodeStates['name'] + "!"
            sys.exit(2) 
        else:
            print "OK: Cluster node " + nodeStates['name'] + " is online and cluster is quorate."
            sys.exit(0)

    elif typeCheck == 'service':
        serviceState = getServiceState(dom, serviceName)
        if serviceState['state'] != 'started':
            print "CRITICAL: Service " + serviceName + " on " + serviceState['owner'] + " is in " + serviceState['state'] + " state"
            sys.exit(2)
        elif check_suspend is True and serviceState['flags'] == 'frozen':
            print "WARNING: Service " + serviceName + " on " + serviceState['owner'] + " is in " + serviceState['flags'] + " state"
            sys.exit(1)
        else:
            print "OK: Service " + serviceName + " on " + serviceState['owner'] + " is in " + serviceState['state'] + " state"
            sys.exit(0)


if __name__ == "__main__":
    main()
