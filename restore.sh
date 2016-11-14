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

				 ver=$(cat "/tmp/nems_migrator_restore/var/www/html/inc/ver.txt") 

				 if [[ $ver = "1.0" ]] || [[ $ver = "1.1" ]]; then
				   echo Backup file is from NEMS $ver. Proceeding.
				   service nagios3 stop
				   
				   # I know I warned you, but I love you too much to let you risk it.
				   ./backup.sh > /dev/null 2>&1
				   cp -p /var/www/html/backup/backup.nems /root/
				   
				   rm -rf /etc/nagios3/Default_collector
				   cp -Rp /tmp/nems_migrator_restore/etc/nagios3/Default_collector /etc/nagios3/
				   
				   rm -rf /etc/nagios3/global
				   cp -Rp /tmp/nems_migrator_restore/etc/nagios3/global /etc/nagios3/
				   
				   rm /etc/nagios3/resource.cfg
				   cp -p /tmp/nems_migrator_restore/etc/nagios3/resource.cfg /etc/nagios3/
				   
				   rm -rf /etc/nagvis/etc/maps
				   cp -Rp /tmp/nems_migrator_restore/etc/nagvis/etc/maps /etc/nagvis/etc/
				   
				   rm -rf /var/www/nconf/output/
				   cp -Rp /tmp/nems_migrator_restore/etc/nagvis/etc/maps /var/www/nconf/
				   
				   # This may cause errors, but at least it gives them the old logs.
				   cp -Rp /tmp/nems_migrator_restore/var/log/* /var/log
				   
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
