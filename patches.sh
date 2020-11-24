#!/bin/bash
# This file is a failsafe patch to supplement fixes.sh
# If something happens to break nems-scripts, I can use this file to patch it
# since it gets called from a different git repository

# Because this script gets called by backup.sh, it will run every 5 minutes.

# Don't allow the script to run if it's already running. May occur if your logs or config tak$
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then
    echo "Process already running"
    exit
fi


if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

  # Grab some git versions
  nems_scripts=`cd /usr/local/share/nems/nems-scripts && git rev-parse HEAD`

  # Fix NEMS 1.3.1 git update issue with nems-scripts
  if [[ $nems_scripts == "8dc6bc9d08b5ac9a37e4d1ed54f548cd79f1f488" ]]; then
    echo "Fixing NEMS 1.3.1 git repository for nems-scripts..."
    cd /usr/local/share/nems/
    rm -rf /usr/local/share/nems/nems-scripts/
    git clone https://github.com/Cat5TV/nems-scripts
    echo "Done."
  fi;

fi;

# This is ONLY a failsafe: If quickfix has been running > 120 minutes, it's pretty apparent something is wrong, so do a git pull in case a patch has been issued
quickfix=`/usr/local/bin/nems-info quickfix`
if [[ $quickfix == 1 ]]; then
  if [[ $(find "/var/run/nems-quickfix.pid" -mmin +120 -print) ]]; then
    kill `cat /var/run/nems-quickfix.pid` && rm /var/run/nems-quickfix.pid
    cd /usr/local/share/nems/nems-scripts && git pull
  fi
fi
# Do the same for fixes
fixes=`/usr/local/bin/nems-info fixes`
if [[ $fixes == 1 ]]; then
  if [[ $(find "/var/run/nems-fixes.pid" -mmin +120 -print) ]]; then
    kill `cat /var/run/nems-fixes.pid` && rm /var/run/nems-fixes.pid
    cd /usr/local/share/nems/nems-scripts && git pull
  fi
fi
