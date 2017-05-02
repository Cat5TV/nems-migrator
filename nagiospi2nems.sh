#!/bin/bash
# This tool exports your nagiospi configuration so it may be imported to NEMS 1.2+.
# If you encounter any problems, please let me know. http://baldnerd.com/nems/

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

  echo Preparing nagiospi for NEMS-Migrator Backup...

  # This line creates the directory tree and file that tells nems-migrator that this is NEMS 1.0, which was based on nagiospi
  test -d "/var/www/html/inc" || mkdir -p "/var/www/html/inc" && echo "1.0" > /var/www/html/inc/ver.txt

  # Create NEMS log folder so we don't get errors
  test -d "/var/log/nems/" || mkdir -p "/var/log/nems/"

  echo Running NEMS-Migrator backup...
  ./backup.sh

  echo Download the file from another computer: http://*NAGIOSPI-IP*/backup/backup.nems

  echo ""

fi
