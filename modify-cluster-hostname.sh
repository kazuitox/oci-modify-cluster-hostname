#!/bin/sh
subnet_id=
compartment_id=

test -f ./hostlist  && /bin/rm ./hostlist
test -f ./hosts.tmp  && /bin/rm ./hosts.tmp
test -f ./hosts.new  && /bin/rm ./hosts.new
test -f ./hostfile.rdma  && /bin/rm ./hostfile.rdma
test -f ./hostfile.tcp  && /bin/rm ./hostfile.tcp

grep role=compute /etc/ansible/hosts | sed 's/ansible_....=//g' | awk '{print $2","$1}' | sort -V > ./hostlist
NUM_NODES=`wc -l ./hostlist | awk '{print $1}'`
HOST_DIGIT=`wc -l hostlist | awk '{print $1}'  | wc -L`
NEW_HOSTNAME_PREFIX="hpc-node"
START=`grep -n "\[compute\]" /etc/ansible/hosts | awk -F: '{print $1+1}'`
END=`grep -n "\[nfs\]" /etc/ansible/hosts | awk -F: '{print $1-1}'`
cat /etc/ansible/hosts | sed ${START},${END}d > ansible.hosts.tmp

if [ ${HOST_DIGIT} -lt 3 ]; then
 DIGIT=2
elif [ $HOST_DIGIT -eq 3 ]; then
 DIGIT=3
else
 exit 1
fi

for i in `seq -f %0${DIGIT}g 1 ${NUM_NODES}`
do

 NUMBER=`echo $i | sed 's/0//g'`
 IP=`cat ./hostlist | sed -n  ${NUMBER}p | cut -d , -f 1`
 OLD_HOSTNAME=`cat ./hostlist | sed -n  ${i}p | cut -d , -f 2`
 NEW_HOSTNAME=${NEW_HOSTNAME_PREFIX}-${i}
 MGMT_IP=`ssh ${IP} ifconfig eno2 |grep inet | awk '{print $2}'`
 RDMA_IP=`ssh ${IP} ifconfig enp94s0f0 |grep inet | awk '{print $2}'`
 DOMAIN=`ssh ${IP} host ${MGMT_IP} | awk '{print $5}' | cut -d. -f 2- | sed 's/.$//'`

 ## create hosts file
 echo -e "${MGMT_IP}\t${NEW_HOSTNAME} ${NEW_HOSTNAME}.${DOMAIN}" >> hosts.tmp
 echo -e "${RDMA_IP}\t${NEW_HOSTNAME}-rdma ${NEW_HOSTNAME}-rdma.local.rdma" >> hosts.tmp
 sort -k 2 ./hosts.tmp > ./hosts.new

 ## create new ansible hosts
 ANSIBLE_HOST="${NEW_HOSTNAME} ansible_host=${IP} ansible_user=opc role=compute"
 INSERT=`expr ${NUMBER} + 3`
 sed -i ${INSERT}i"${ANSIBLE_HOST}" ./ansible.hosts.tmp

 ## create hostfile file
 echo "${NEW_HOSTNAME}-rdma.local.rdma" >> hostfile.rdma
 echo "${NEW_HOSTNAME}.${DOMAIN}" >> hostfile.tcp

 ## change Instance Display Name
 INSTANCE_ID=$(oci compute instance list --compartment-id ${compartment_id} --display-name ${OLD_HOSTNAME} --query 'data[0]."id"' --raw-output)
 oci compute instance update  --instance-id ${INSTANCE_ID} ${NEW_HOSTNAME}

 ## change FQDN of Private IP and VNIC Display Name
 VNIC_ID=$(oci network private-ip list --subnet-id ${subnet_id} --ip-address ${MGMT_IP}  --query 'data[0]."vnic-id"' --raw-output)
 oci network vnic update --vnic-id ${VNIC_ID} --hostname-label ${NEW_HOSTNAME}
 oci network vnic update --vnic-id ${VNIC_ID} --display-name ${NEW_HOSTNAME}

done

## Replace /etc/hosts and hostfile.* file
cat ./hosts.tmp | grep -v rdma | while read line
do

 IP=`echo $line | awk '{print $1}'`
 HOSTNAME=`echo $line | awk '{print $2}'`
 HOSTNAMES=`echo $line | awk '{print $2" "$3}'`
 echo -e "127.0.0.1\tlocalhost localhost.localdomain localhost4 localhost4.localdomain4" > ./hosts.${HOSTNAME}
 echo -e "::1\t\tlocalhost localhost.localdomain localhost6 localhost6.localdomain6" >> ./hosts.${HOSTNAME}
 echo -e "${IP}\t${HOSTNAMES}" >> ./hosts.${HOSTNAME}
 echo "# BEGIN ANSIBLE MANAGED BLOCK" >> ./hosts.${HOSTNAME}
 cat ./hosts.new >> ./hosts.${HOSTNAME}
 echo "# END ANSIBLE MANAGED BLOCK" >> ./hosts.${HOSTNAME}
 scp ./hosts.${HOSTNAME} ${IP}:/var/tmp/hosts
 ssh ${IP} sudo cp -p /etc/hosts /etc/hosts.org 
 ssh ${IP} sudo mv /var/tmp/hosts /etc/hosts

 for file in hostfile.rdma hostfile.tcp
 do
  scp ./${file} ${IP}:/var/tmp
  ssh ${IP} sudo cp -p /etc/opt/oci-hpc/${file} /etc/opt/oci-hpc/${file}.org
  ssh ${IP} sudo mv /var/tmp/${file} /etc/opt/oci-hpc/${file}
 done

done

## Replace /etc/ansible/hosts file
NFS_SERVER_ROW=`grep -n "\[nfs\]" /etc/ansible/hosts | awk -F: '{print $1+1}'`
OLD_NFS_SERVER=`sed -n ${NFS_SERVER_ROW}p ./ansible.hosts.tmp`
NFS_NFS_SERVER_NAME=`paste -d , hostlist hostfile.tcp | grep ${OLD_NFS_SERVER} | awk -F,  '{print $3}' | awk -F. '{print $1}'`
sed -i "s/${OLD_NFS_SERVER}/${NFS_NFS_SERVER_NAME}/" ./ansible.hosts.tmp
sudo cp -p /etc/ansible/hosts /etc/ansible/hosts.org
sudo cp ./ansible.hosts.tmp /etc/ansible/hosts

## change hostname
ansible-playbook ./change-hostname.yml
