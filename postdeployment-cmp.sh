#!/bin/bash
######################################################################
## POSTDEPLOYMENT SCRIPT FOR COMPUTE NODE                           ##
#####################################################################

echo "First copy all files from fuel to compute $1"
scp -rq files $1:/root/
echo "################################################################################# | tee -a /root/postdeployment.log"
ssh $1 'ab=`contrail-version | grep "2.20-mira1"`;if [ -z "$ab" ] ; then echo upgrde-vroute; fi' > /tmp/a
ab=`cat /tmp/a`
if [ ! -z "$ab" ]
then
    echo "update vrouter-agent,SSL certificate and change bond mode "
    ssh $1 bash /root/files/update_sources_list.sh | tee -a /root/postdeployment.log
    ssh $1 bash /root/files/upgrade_vrouter.sh | tee -a /root/postdeployment.log
    ssh $1 cp /root/files/ssl_certificate.pem /etc/contrail/ssl/private/
    #ssh $1 'echo "haproxy_ssl_cert_path=/etc/contrail/ssl/private/" >> /etc/contrail/contrail-vrouter-agent.conf'
    ssh $1 'ab=`grep haproxy_ssl_cert_path /etc/contrail/contrail-vrouter-agent.conf` ; if [ ! -z $ab ] ; then echo "there is already" ; else echo haproxy_ssl_cert_path=/etc/contrail/ssl/private/ >> /etc/contrail/contrail-vrouter-agent.conf;fi'
    ssh $1 sed -i 's/active-backup/balance-alb/g' /etc/network/interfaces.d/ifcfg-bond0
    ssh $1 "sed -i '/iface/a pre-up /sbin/ethtool -K eth0 tx off' /etc/network/interfaces.d/01-ifcfg-eth0"
    ssh $1 "sed -i '/iface/a pre-up /sbin/ethtool -K eth1 tx off' /etc/network/interfaces.d/01-ifcfg-eth1"
    ssh $1 '/sbin/ethtool -K eth0 tx off; /sbin/ethtool -K eth1 tx off'
    ssh $1 'ifdown bond0;ifup eth0;ifup eth1'
    ssh $1 'service supervisor-vrouter restart'
    ssh $1 contrail-status
    echo "contrail and network configuration done"
else
   echo "vrouter already upgraded"
fi

echo "#################################################################################"
echo "install Harddisk RAID check utility of HP | tee -a /root/postdeployment.log"
ssh $1 "dpkg -i /root/files/hpssacli-2.10-14.0_amd64.deb | tee -a /root/postdeployment.log"
sh $1 '/usr/sbin/hpssacli controller slot=1 array all show status | grep array'

echo "#################################################################################"
echo "Zabbix Agent installation and configuration | tee -a /root/postdeployment.log"
ssh $1 'dpkg -i /root/files/zabbix-agent_2.2.4-1+precise_amd64.deb | tee -a /root/postdeployment.log'
ssh $1 'cp /root/files/zabbix_agent.conf /etc/zabbix/'
ssh $1 'cp /root/files/userparameter_interfacestatus.conf /etc/zabbix/zabbix_agentd.d/'
ssh $1 'cp /root/files/userparameter_raidcheck.conf /etc/zabbix/zabbix_agentd.d/'
ssh $1 'cp /root/files/interfacestatus.v2.sh /usr/local/bin/'
ssh $1 'cp /root/files/zabbix_raidcheck.sh /usr/local/bin/'
ssh $1 'mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.org'
ssh $1 'ln -s /etc/zabbix/zabbix_agent.conf /etc/zabbix/zabbix_agentd.conf'
ssh $1 'service zabbix-agent restart'
ssh $1 'ab=`iptables -L | grep zabbix-agent`;if [ -z "$ab" ];then iptables -I INPUT 1 -s 10.135.165.17 -d 0.0.0.0/0 -p tcp --dport 10050 -j ACCEPT;iptables-save > /etc/iptables/rules.v4; else echo not-need-to-upgrade-iptables;fi'
ssh $1 'dpkg -i /root/files/molly-guard_0.4.4-2_all.deb | tee -a /root/postdeployment.log'

echo "################################################################################# | tee -a /root/postdeployment.log"
echo "Run MBSS script | tee -a /root/postdeployment.log"
ssh $1 'bash /root/files/mbss-Script-for-private-nodes-final.sh | tee -a /root/postdeployment.log'

echo "################################################################################# | tee -a /root/postdeployment.log"
echo "Add reliance-admin user and place its key | tee -a /root/postdeployment.log"
ssh $1 'useradd -s /bin/bash reliance-admin'
ssh $1 'mkdir /home/reliance-admin ; cp -r /root/files/.ssh /home/reliance-admin/ ; chown -R reliance-admin:reliance-admin /home/reliance-admin'

echo "################################################################################# | tee -a /root/postdeployment.log"
echo "MOS update packages on new node | tee -a /root/postdeployment.log"
ssh $1 'cp /etc/apt/sources.list /etc/apt/sources.list.org'
ssh $1 'cp /root/files/source-fuel-repo.list /etc/apt/sources.list; apt-get update'
ssh $1 'for i in `cat /root/files/mos-pkg-list`; do apt-get install $i ;done'
ssh $1 'for i in libvirt-bin nova-compute zabbix-agent supervisor-vrouter; do service $i restart;done'
ssh $1 'service ceilometer-agent-compute stop | tee -a /root/postdeployment.log'
ssh $1 'echo manual > /etc/init/ceilometer-agent-compute.override'

echo "################################################################################# | tee -a /root/postdeployment.log"
echo "Adding motd header | tee -a /root/postdeployment.log"
ssh $1 'cp /root/files/motd /root/files/motd1'
ssh $1 'mv /root/files/motd1 /etc/motd'

echo "################################################################################# | tee -a /root/postdeployment.log"
echo "Changing bash shell with Env Name:Hasta | tee -a /root/postdeployment.log"
ssh $1 bash /root/files/ps1.sh | tee -a /root/postdeployment.log

echo "#####################################################################"
echo "For CONSUL Agent deployment please run respective ansible script."

echo "#####################################################################"
echo "Delete disabled nova-network services"
ssh $1 'sh /root/files/delete_disabled_nova_net.sh'
echo "#####################################################################"

ssh $1 'echo  -e "\033[33;5;7mConsul Agent is not added to this node, have to run Ansible-Playbook for the same.\033[0m"| tee -a /root/postdeployment.log'

