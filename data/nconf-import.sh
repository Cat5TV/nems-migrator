#!/bin/bash
ver=$1
confdest=$2 # Importing from DESTINATION because we already imported the backup to the destination

  # Clear the MySQL Database (replace with our blank DB from NEMS-Migrator)
  printf "Creating a clean NEMS NConf configuration... "
  systemctl stop mysql
  # Clear the MySQL Database (replace with our Clean DB from NEMS-Migrator)
  rm -rf /var/lib/mysql/
  if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.4'")}') )); then
    cp -R /root/nems/nems-migrator/data/1.4/mysql/NEMS-Clean /var/lib
  else
    # legacy
    cp -R /root/nems/nems-migrator/data/mysql/NEMS-Clean /var/lib
  fi
  mv /var/lib/NEMS-Clean /var/lib/mysql
  chown -R mysql:mysql /var/lib/mysql
  systemctl start mysql
  echo "Done."

  echo "Importing Nagios Configs to NEMS NConf..."
  # Import Nagios configs into NConf's MySQL Database
  echo "Importing: timeperiod" && /var/www/nconf/bin/add_items_from_nagios.pl -c timeperiod -f $confdest/global/timeperiods.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: misccommand" && /var/www/nconf/bin/add_items_from_nagios.pl -c misccommand -f $confdest/global/misccommands.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: checkcommand" && /var/www/nconf/bin/add_items_from_nagios.pl -c checkcommand -f $confdest/global/checkcommands.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: contact" && /var/www/nconf/bin/add_items_from_nagios.pl -c contact -f $confdest/global/contacts.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: contactgroup" && /var/www/nconf/bin/add_items_from_nagios.pl -c contactgroup -f $confdest/global/contactgroups.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: host-template" && /var/www/nconf/bin/add_items_from_nagios.pl -c host-template -f $confdest/global/host_templates.cfg 2>&1 | grep -E "ERROR"
  #echo "Importing: parent-host" && /var/www/nconf/bin/add_items_from_nagios.pl -c host -f $confdest/parent-hosts.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: host" && /var/www/nconf/bin/add_items_from_nagios.pl -c host -f $confdest/Default_collector/hosts.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: hostgroup" && /var/www/nconf/bin/add_items_from_nagios.pl -c hostgroup -f $confdest/Default_collector/hostgroups.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: host-dependency" && /var/www/nconf/bin/add_items_from_nagios.pl -c host-dependency -f $confdest/Default_collector/host_dependencies.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: service-template" && /var/www/nconf/bin/add_items_from_nagios.pl -c service-template -f $confdest/global/service_templates.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: service" && /var/www/nconf/bin/add_items_from_nagios.pl -c service -f $confdest/Default_collector/services.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: advanced-service" && /var/www/nconf/bin/add_items_from_nagios.pl -c advanced-service -f $confdest/Default_collector/advanced_services.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: servicegroup" && /var/www/nconf/bin/add_items_from_nagios.pl -c servicegroup -f $confdest/Default_collector/servicegroups.cfg 2>&1 | grep -E "ERROR"
  echo "Importing: service-dependency" && /var/www/nconf/bin/add_items_from_nagios.pl -c service-dependency -f $confdest/Default_collector/service_dependencies.cfg 2>&1 | grep -E "ERROR"
  echo "Done."
