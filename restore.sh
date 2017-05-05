#!/bin/bash

start=`date +%s`

# Don't allow the script to run if it's already running. May occur if your logs or config take longer than 5 minutes to backup.
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then
    echo "Process already running"
    exit
fi

if [[ $1 = "" ]]; then
  echo "Usage: sudo ./restore.sh /location/of/backup.nems"
  exit
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

	if [[ -e $1 ]]; then

		echo Let me be VERY clear here...
		echo This will WIPE OUT the configuration on this NEMS deployment.
		echo The configuration will be replaced with the one stored in your NEMS backup.
		echo ""
		echo Please do this on a fresh deployment of NEMS to prevent data loss.
		echo "I am not responsible for this script breaking everything you have done :)"
		echo Backup, backup, backup.
		
		echo ""
	 
		read -r -p "Are you sure you want to attempt restore? [y/N] " response
		if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then

				mkdir -p /tmp/nems_migrator_restore
				cd /tmp/nems_migrator_restore

				 tar -zxf $1

				 backupver=$(cat "/tmp/nems_migrator_restore/var/www/html/inc/ver.txt") 
				 ver=$(cat "/var/www/html/inc/ver.txt") 
				 
				 if [[ $backupver = "1.0" ]] || [[ $backupver = "1.1" ]]; then
				   echo Backup file is from NEMS $backupver. Proceeding.
				   service nagios3 stop
				   service mysql stop
				   
				   # I know I warned you, but I love you too much to let you risk it.
				   ./backup.sh > /dev/null 2>&1
				   cp -p /var/www/html/backup/backup.nems /root/
				   
				   if [[ -d "/tmp/nems_migrator_restore/var/lib/mysql" ]]; then
							 rm -rf /var/lib/mysql
							 # Replacing database directly with NEMS backup deprecated in NEMS 1.2 - now we instead import the configs to a fresh DB
							 # cp -Rp /tmp/nems_migrator_restore/var/lib/mysql /var/lib/
							 cp -Rp /root/nems/nems-migrator/data/mysql /var/lib/
							 
							 # Import nConf Configs
							   # Import Commands
							     /var/www/nconf/bin/add_items_from_nagios.pl -c checkcommand -f /root/nems/nems-migrator/data/nconf/check_wmi_plus.commands -x 1

							   # Import Hosts (Uncomment if you want the sample data added)
							     /var/www/nconf/bin/add_items_from_nagios.pl -c host -f /root/nems/nems-migrator/data/nconf/check_wmi_plus.hosts -x 1

							   # Import Services
							     /var/www/nconf/bin/add_items_from_nagios.pl -c service -f /root/nems/nems-migrator/data/nconf/check_wmi_plus.services -x 1
						 else 
							 echo "MySQL Database Missing. This is a critical error."
							 exit
					 fi
					 
				   if [[ -d "/tmp/nems_migrator_restore/etc/nagios3/Default_collector" ]]; then
							 rm -rf /etc/nagios3/Default_collector
							 cp -Rp /tmp/nems_migrator_restore/etc/nagios3/Default_collector /etc/nagios3/
						 else 
							 echo "Nagios Configuration Missing. This is a critical error."
							 exit
					 fi
					 
					 if [[ -d "/tmp/nems_migrator_restore/etc/nagios3/global" ]]; then
					     rm -rf /etc/nagios3/global
							 cp -Rp /tmp/nems_migrator_restore/etc/nagios3/global /etc/nagios3/
				   else 
							 echo "Nagios Configuration Missing. This is a critical error."
							 exit
					 fi
					 
					 if [[ $backupver == "1.0" ]]; then
					 	echo "Upgrading to newer version of NEMS: Please edit /etc/nagios3/resource.cfg to configure your settings."
					 else
						 if [[ -e "/tmp/nems_migrator_restore/etc/nagios3/resource.cfg" ]]; then
							 /usr/bin/php /root/nems/nems-migrator/resource-upgrade.php
						  else 
							 echo "Nagios Configuration Missing. This is a critical error."
							 exit
						 fi
					 fi
				   
				   
					 # NagVis maps are stored differently in NEMS 1.0
					 if [[ $backupver == "1.0" ]]; then
							nagvissrc="maps/"
						 else
							nagvissrc="etc/maps/"
					 fi
					 if [[ $ver == "1.0" ]]; then
							nagvisdest=""
						 else
							nagvisdest="etc/"
					 fi
				   if [[ -d "/tmp/nems_migrator_restore/etc/nagvis/$nagvissrc" ]]; then
						 rm -rf /etc/nagvis/$nagvisdest\maps
						 cp -Rp /tmp/nems_migrator_restore/etc/nagvis/$nagvissrc /etc/nagvis/$nagvisdest
				   else 
							 echo "NagVis failed. Your NagVis data is corrupt."
					 fi
					 
					 if [[ -d "/tmp/nems_migrator_restore/var/www/nconf/output" ]]; then
						 rm -rf /var/www/nconf/output/
						 cp -Rp /tmp/nems_migrator_restore/var/www/nconf/output /var/www/nconf/
				   else 
							 echo "NConf failed. Your NConf data is corrupt."
							 echo "You should be able to re-create it."
					 fi
					
				   
				   # This may cause errors, but at least it gives them the old logs.
				   cp -Rp /tmp/nems_migrator_restore/var/log/* /var/log
				   
				   service mysql start
				   service nagios3 start
				   
				   echo ""
				   echo I hope everything worked okay for you.
				   echo Please let me know if you had any trouble.
				   echo ""
				   echo PS - I saved a backup for you of the old config. /root/backup.nems
				   echo      ... just in case
				   echo ""
				   
				 else
				   echo Your backup file is either invalid, or an unsupported version. Aborted.
				 fi

				 rm -rf /tmp/nems_migrator_restore
				 
				 end=`date +%s`
				 runtime=$((end-start))

				 if [ -d /var/log/nems ]
					 then
						 echo $runtime > /var/log/nems/migrator-restore-runtime.log
					 else
						 mkdir /var/log/nems
						 echo $runtime > /var/log/nems/migrator-restore-runtime.log
				 fi
				 
		else
				echo Aborted.
		fi
		 
	else
	  echo $1 does not exist. Aborting.
	fi
	 
fi
