#!/bin/bash
#################################################################################
###
###  Script: install_ose.sh
###
###  Written By: Mark E Turlik  on  July 27, 2018
###
###  Decsription:  This script prompts the user for the Cluster GUID to be
###                used to host the OpenShift environment.  It subsequently
###                performs the entire OpenShift installation for the MITZICOM
###                deployment.
###
#################################################################################
clear
echo "################################################################"
echo "###"
echo "###  This script will create the OpenShift environment for ..."
echo "###"
echo "#################################################################"
echo

#----------------------------------------------------
#---  Only run the script if you are the root user
#----------------------------------------------------
if [ `whoami` != "root" ] ; then
   echo "You MUST run this script as the \"root\" user"
   echo " ... existing"
   exit
fi

#-----------------------------------------
#--- Prompt for the GUID of the Cluster
#-----------------------------------------
echo -n "Enter the Cluster GUID: "
read GUID

echo "#####################################################"
echo "### Save a copy of the original Ansible hosts file"
echo "#####################################################"
cp /etc/ansible/hosts /etc/ansible/hosts.ORIG

echo "#######################"
echo "### Get the ldap cert
echo "#######################"
cd /root
wget http://ipa.shared.example.opentlc.com/ipa/config/ca.crt -O /root/ipa-ca.crt

echo "##############################################################"
echo "### Add GUID environment variable to all host .bashrc files"
echo "##############################################################"
ansible localhost,all -m shell -a 'export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc'

echo "#############################################################"
echo "### Replace the entered GUID within the ODE hosts template
echo "#############################################################"
cp ../inventory/hosts.homework /etc/ansible/hosts
sed -i "s/GUID/$GUID/g" /etc/ansible/hosts

echo "##################################################################"
echo "###  Run the ansible prerequisite and deploy-cluster play-books"
echo "##################################################################"
ansible-playbook -f 20 /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -f 20 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

echo "############################################"
echo "### Verify Docker is running on all nodes"
echo "############################################"
ansible nodes -m shell -a"systemctl status docker | grep Active"

echo "###################################################################################"
echo "### Copy the .kube directory to allow system:admin access from the bastion host"
echo "###################################################################################"
ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"

echo "####################################################"
echo "### Verify that the environment is functioning ..."
echo "####################################################"
oc get nodes --show-labels
oc get pod --all-namespaces -o wide

echo "############################"
echo "### Synchronize the groups
echo "############################"
ansible localhost -m shell -a'scp ../inventory/groupsync.yaml master1.$GUID.internal:/etc/origin/master/groupsync.yaml --confirm'
ansible localhost -m shell -a'scp ../inventory/whitelist.yaml master1.$GUID.internal:/etc/origin/master/whitelist.yaml'
ansible master1.$GUID.internal -m shell -a'oc adm groups sync --sync-config=/etc/origin/master/groupsync.yaml --whitelist=/etc/origin/master/whitelist.yaml'