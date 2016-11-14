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
				   
				   rm -rf /etc/nagios3/Default_collector
				   cp -R /tmp/nems_migrator_restore/etc/nagios3/Default_collector /etc/nagios3/
				   
				   rm -rf /etc/nagios3/global
				   cp -R /tmp/nems_migrator_restore/etc/nagios3/global /etc/nagios3/
				   
				   rm /etc/nagios3/resource.cfg
				   cp /tmp/nems_migrator_restore/etc/nagios3/resource.cfg /etc/nagios3/
				   
				   service nagios3 start
				   echo ""
				   echo I hope everything worked okay for you. Please let me know if you had any trouble.
				   echo ""
				 else
				   echo Your backup file is either invalid, or an unsupported version. Aborted.
				 fi

				 end=`date +%s`

				 runtime=$((end-start))

#				rm -rf /tmp/nems_migrator_restore

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
