#!/bin/bash

  # Clear the MySQL Database (replace with our blank DB from NEMS-Migrator)
  printf "Removing all NEMS NConf configuration... "
  systemctl stop mysql
  # Clear the MySQL Database (replace with our Clean DB from NEMS-Migrator)
  rm -rf /var/lib/mysql
  cp -Rp /root/nems/nems-migrator/data/mysql/NEMS-Clean /var/lib/
  chown -R mysql:mysql /var/lib/NEMS-Clean
  mv /var/lib/NEMS-Clean /var/lib/mysql
  systemctl start mysql
  echo "Done."

  echo "Importing Nagios3 Configs to NEMS NConf..."
  # Import Nagios3 configs into NConf's MySQL Database
  echo "  Importing: timeperiod" && /var/www/nconf/bin/add_items_from_nagios.pl -c timeperiod -f /etc/nagios3/global/timeperiods.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: misccommand" && /var/www/nconf/bin/add_items_from_nagios.pl -c misccommand -f /etc/nagios3/global/misccommands.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: checkcommand" && /var/www/nconf/bin/add_items_from_nagios.pl -c checkcommand -f /etc/nagios3/global/checkcommands.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: contact" && /var/www/nconf/bin/add_items_from_nagios.pl -c contact -f /etc/nagios3/global/contacts.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: contactgroup" && /var/www/nconf/bin/add_items_from_nagios.pl -c contactgroup -f /etc/nagios3/global/contactgroups.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: host-template" && /var/www/nconf/bin/add_items_from_nagios.pl -c host-template -f /etc/nagios3/global/host_templates.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: parent-host" && /var/www/nconf/bin/add_items_from_nagios.pl -c host -f /etc/nagios3/parent-hosts.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: host" && /var/www/nconf/bin/add_items_from_nagios.pl -c host -f /etc/nagios3/Default_collector/hosts.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: hostgroup" && /var/www/nconf/bin/add_items_from_nagios.pl -c hostgroup -f /etc/nagios3/Default_collector/hostgroups.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: host-dependency" && /var/www/nconf/bin/add_items_from_nagios.pl -c host-dependency -f /etc/nagios3/Default_collector/host_dependencies.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: service-template" && /var/www/nconf/bin/add_items_from_nagios.pl -c service-template -f /etc/nagios3/global/service_templates.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: service" && /var/www/nconf/bin/add_items_from_nagios.pl -c service -f /etc/nagios3/Default_collector/services.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: advanced-service" && /var/www/nconf/bin/add_items_from_nagios.pl -c advanced-service -f /etc/nagios3/Default_collector/advanced_services.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: servicegroup" && /var/www/nconf/bin/add_items_from_nagios.pl -c servicegroup -f /etc/nagios3/Default_collector/servicegroups.cfg 2>&1 | grep -E "ERROR"
  echo "  Importing: service-dependency" && /var/www/nconf/bin/add_items_from_nagios.pl -c service-dependency -f /etc/nagios3/Default_collector/service_dependencies.cfg 2>&1 | grep -E "ERROR"
  echo "Done."
