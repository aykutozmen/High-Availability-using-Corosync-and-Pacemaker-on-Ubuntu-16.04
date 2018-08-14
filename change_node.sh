#!/bin/bash

# Private IP address of the server is assumed to have static IP address configuration.
# Public IP address of the server is assumed to have dynamic IP address configuration with dhcp.

Static_Interface_Name=`cat /etc/network/interfaces | grep iface | grep -v lo | grep static | awk '{print $2}'`
Public_Interface_Name=`cat /etc/network/interfaces | grep -v lo | grep auto | grep -v $Static_Interface_Name | awk '{print $2}'`
Node_Static_IP=`ifconfig | grep -A1 $Static_Interface_Name | tail -1 | awk '{print $2}' | cut -d':' -f 2`
Cluster_IP_Exists=`ip addr list | grep inet | grep -v inet6 | grep -v "127.0.0.1" | grep -v "$Node_Static_IP" | grep -v $Public_Interface_Name | awk '{print $2}' | cut -d'/' -f 1 | wc -l`
Cluster_IP=`ip addr list | grep inet | grep -v inet6 | grep -v "127.0.0.1" | grep -v "$Node_Static_IP" | grep -v $Public_Interface_Name | awk '{print $2}' | cut -d'/' -f 1`
Corosync_Application_Full_Path=`which corosync-cmapctl`
Crm_Application_Full_Path=`which crm`
Cluster_Member_Count=`$Corosync_Application_Full_Path | grep members | cut -d'.' -f 7 | uniq | wc -l`
Cluster_Members=`$Corosync_Application_Full_Path | grep members | grep "r(0)" | cut -d' ' -f 5 | cut -d'(' -f 2 | tr -d ')'`

while true
do
	if [ $Cluster_IP_Exists -eq 1 ]
	then
		echo "THIS NODE IS PRIMARY. This node has cluster IP Address: "$Cluster_IP
		echo "Cluster has "$Cluster_Member_Count" members. Cluster Members: "$Cluster_Members
		echo
		read -p "Do you want to change primary node? [yY/nN] " Answer
		Flag=1
	else
		echo "THIS NODE IS NOT PRIMARY."
	        echo "Cluster has "$Cluster_Member_Count" members. Cluster Members: "$Cluster_Members
		echo
		read -p "Do you want to change primary node? [yY/nN] " Answer
		Flag=2
	fi
	
	case $Answer in
		[Yy]*)
			if [ $Flag -eq 1 ]
			then
				$Crm_Application_Full_Path node standby primary
				$Crm_Application_Full_Path node online secondary
				Cluster_IP_Exists=`ip addr list | grep inet | grep -v inet6 | grep -v "127.0.0.1" | grep -v "$Node_Static_IP" | grep -v $Public_Interface_Name | awk '{print $2}' | cut -d'/' -f 1 | wc -l`
				if [ $Cluster_IP_Exists -eq 0 ]
				then
					echo "Success. Check for cluster IP on the other node with 'ip addr list' command."
				else
					echo "Fail!..."
				fi
			else
				$Crm_Application_Full_Path node standby secondary
				$Crm_Application_Full_Path node online primary
                Cluster_IP_Exists=`ip addr list | grep inet | grep -v inet6 | grep -v "127.0.0.1" | grep -v "$Node_Static_IP" | grep -v $Public_Interface_Name | awk '{print $2}' | cut -d'/' -f 1 | wc -l`
                if [ $Cluster_IP_Exists -eq 1 ]
                then
                    echo "Fail!..."
                else
                    echo "Success. Check for cluster IP on this node with 'ip addr list' command."
                fi
			fi
			break
			;;
		[Nn]*)
			echo "No changes have been done."
			break
			;;
		*)
			echo "Please answer y/Y or n/N."
			;;
	esac
done

	

