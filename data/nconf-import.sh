#!/bin/bash
ver=$1
confdest=$2 # Importing from DESTINATION because we already imported the backup to the destination

 # Make sure permissions are correct so configs can be written via browser.
 chown -R www-data:www-data /var/www/html/nconf/

  # Clear the MySQL Database (replace with our blank DB from NEMS-Migrator)
  printf "Creating a clean NEMS NConf configuration... "
  systemctl stop mysql
  # Clear the MySQL Database (replace with our Clean DB from NEMS-Migrator)
  rm -rf /var/lib/mysql/
  if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.6'")}') )); then
    printf "Using v1.6 defaults... "
    cp -R /root/nems/nems-migrator/data/1.6/mysql/NEMS-Clean /var/lib
  elif (( $(awk 'BEGIN {print ("'$ver'" >= "'1.5'")}') )); then
    printf "Using v1.5 defaults... "
    cp -R /root/nems/nems-migrator/data/1.5/mysql/NEMS-Clean /var/lib
  elif (( $(awk 'BEGIN {print ("'$ver'" >= "'1.4'")}') )); then
    printf "Using v1.4 defaults... "
    cp -R /root/nems/nems-migrator/data/1.4/mysql/NEMS-Clean /var/lib
  else
    # legacy
    printf "Using legacy defaults... "
    cp -R /root/nems/nems-migrator/data/mysql/NEMS-Clean /var/lib
  fi
  mv /var/lib/NEMS-Clean /var/lib/mysql
  chown -R mysql:mysql /var/lib/mysql
  systemctl start mysql
  echo "Done."

  echo "Importing Nagios Configs to NEMS NConf..."
  # Import Nagios configs into NConf's MySQL Database
  printf -- "\e[37mImporting:\e[97m timeperiod\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c timeperiod -f $confdest/global/timeperiods.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m misccommand\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c misccommand -f $confdest/global/misccommands.cfg 2>&1 | grep -E "ERROR"
  # Do not import check commands directly from the cfg in NEMS 1.5+ - these come from the database itself, otherwise arg variables (names, count) get lost since they are not part of nagios conf
  # Instead, we'll need to break apart the NEMS 1.5+ config so we can try one at a time
  if (( $(awk 'BEGIN {print ("'$ver'" < "'1.5'")}') )); then
    # Legacy support (NEMS 1.4.1 and before)
    printf -- "\e[37mImporting:\e[97m checkcommand\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c checkcommand -f $confdest/global/checkcommands.cfg 2>&1 | grep -E "ERROR"
  else
    # NEMS 1.5+
    # Blow up the config file
    tmpdir=`mktemp -d -p /tmp/`
    /root/nems/nems-migrator/data/cfg-exploder.sh $confdest/global/checkcommands.cfg $tmpdir
    cd $tmpdir
    printf -- "\e[37mImporting:\e[97m checkcommand\033[0m\n"
    echo ""
    echo "NOTE: Don't worry if you see several checkcommands aborted."
    echo "      This simply means they are already in the database."
    echo ""
    sleep 2
    for f in *.cfg; do /var/www/nconf/bin/add_items_from_nagios.pl -c checkcommand -f $f 2>&1 | grep -E "ERROR"; done
    rm -rf $tmpdir
  fi
  printf -- "\e[37mImporting:\e[97m contact\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c contact -f $confdest/global/contacts.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m contactgroup\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c contactgroup -f $confdest/global/contactgroups.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m host-template\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c host-template -f $confdest/global/host_templates.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m host\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c host -f $confdest/Default_collector/hosts.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m hostgroup\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c hostgroup -f $confdest/Default_collector/hostgroups.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m host-dependency\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c host-dependency -f $confdest/Default_collector/host_dependencies.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m service-template\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c service-template -f $confdest/global/service_templates.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m service\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c service -f $confdest/Default_collector/services.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m advanced-service\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c advanced-service -f /tmp/reconcile-advanced-services.cfg 2>&1 | grep -E "ERROR" && rm /tmp/reconcile-advanced-services.cfg
  printf -- "\e[37mImporting:\e[97m servicegroup\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c servicegroup -f $confdest/Default_collector/servicegroups.cfg 2>&1 | grep -E "ERROR"
  printf -- "\e[37mImporting:\e[97m service-dependency\033[0m\n" && /var/www/nconf/bin/add_items_from_nagios.pl -c service-dependency -f $confdest/Default_collector/service_dependencies.cfg 2>&1 | grep -E "ERROR"
  echo "Done."

