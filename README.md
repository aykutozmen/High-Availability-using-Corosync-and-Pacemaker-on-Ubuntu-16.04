# High Availability using Corosync and Pacemaker on Ubuntu 16.04

Corosync is an open source program that provides cluster membership and messaging capabilities, often referred to as the messaging layer, to client servers.
Pacemaker is an open source cluster resource manager (CRM), a system that coordinates resources and services that are managed and made highly available by a cluster. In essence, Corosync enables servers to communicate as a cluster, while Pacemaker provides the ability to control how the cluster behaves.
All commands should be run with root privileges.

**Prerequisites:**
On two servers, run these commands, select the same timezone on both servers and see the **“NTP synchronized: yes”** line with **timedatectl** command.
```
  # apt-get update
  # dpkg-reconfigure tzdata
  # apt-get -y install ntp
  # timedatectl
```
Corosync uses UDP transport between ports 5404, 5405 and 5406 . If you are running a firewall, ensure that communication on those ports are allowed between the servers.

```
  # ufw allow 5404, 5405, 5406
```
Or
```
  # iptables -A INPUT  -i eth1 -p udp -m multiport --dports 5404,5405,5406 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
  # iptables -A OUTPUT  -o eth1 -p udp -m multiport --sports 5404,5405,5406 -m conntrack --ctstate ESTABLISHED -j ACCEPT
```
**Installation:**
On both servers install pacemaker. Corosync is dependency of corosync.
```
  # apt-get install pacemaker
```
On Server A:
```
  # apt-get install haveged
  # corosync-keygen
  # scp /etc/corosync/authkey root@server_B_ip:/etc/corosync/
```
On Server B:
```
  # chown root: /etc/corosync/authkey
  # chmod 400 /etc/corosync/authkey
```
On both servers:
```
  # vi /etc/corosync/corosync.conf
```
Make the changes and complete the missings related to these lines:
```
totem {
  version: 2
  cluster_name: my_new_cluster
  transport: udpu
  interface {
    ringnumber: 0
    bindnetaddr: private_binding_IP_address
    broadcast: yes
    mcastport: 5405
  }
}

quorum {
  provider: corosync_votequorum
  two_node: 1
}

nodelist {
  node {
    ring0_addr: server_A_private_IP_address
    name: primary
    nodeid: 1
  }
  node {
    ring0_addr: server_B_private_IP_address
    name: secondary
    nodeid: 2
  }
}

logging {
  to_logfile: yes
  logfile: /var/log/corosync/corosync.log
  to_syslog: yes
  timestamp: on
}
```
If private IP configuration is like this:
- [ ] Server A	: 192.168.1.101
- [ ] Server B	: 192.168.1.102
- [ ] Cluster IP	: 192.168.1.100

Then;
- [ ] private_binding_IP_address	: 192.168.1.255
- [ ] server_A_private_IP_address	: 192.168.1.101
- [ ] server_B_private_IP_address	: 192.168.1.102

On both servers:
```
  # mkdir -p /etc/corosync/service.d
  # vi /etc/corosync/service.d/pcmk
```
Insert these lines:
```
service {
  name: pacemaker
  ver: 1
}
```
```
  # vi /etc/default/corosync
```
Insert this line:
```
START=yes
```
```
  # service corosync start
  # service corosync restart
  # corosync-cmapctl | grep members
```
You should see both servers’ private IP addresses near the strings r(0) ip(….).
On both servers:
```
  # update-rc.d pacemaker defaults 20 01
  # service pacemaker start
  # crm status
```
On Server A:
```
  # crm configure property stonith-enabled=false
  # crm configure property no-quorum-policy=ignore
  # crm configure primitive virtual_public_ip ocf:heartbeat:IPaddr2 params ip="q.w.e.r" cidr_netmask="32" op monitor interval="10s" meta migration-threshold="2" failure-timeout="60s" resource-stickiness="100"
```
Replace “q.w.e.r” with cluster IP address for example: 192.168.1.100
**Verification and Management:**
```
  # crm status
  # ip addr list
```
You should see cluster IP address on one server.
**Change of primary node to secondary and secondary to primary:**
You can use these commands manually on both servers.
```
  # crm node standby secondary
  # crm node online primary
  # crm node standby primary
  # crm node online secondary
```
Or run the script named **change_node.sh** in order to float the cluster IP on the servers without any packet loss.

