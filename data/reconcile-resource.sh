#!/usr/bin/php
<?php
  # This script is used to consolidate settings in config files.
  # For example, as NEMS evolves, config settings in the resource.cfg file may be added.
  # Traditional "replacement" of the config file would result in those new settings missing.
  # So this script consolidates the data between the source (backup.nems) and destination (resource.cfg).

  echo "reconcile-resource... " . PHP_EOL;

  $resourcesrc = $argv[1];
  $resourcedest = $argv[2];

  $source = '/tmp/nems_migrator_restore' . $resourcesrc . '/resource.cfg';
  $dest   = $resourcedest . '/resource.cfg';

  $data = new stdClass();
  if (file_exists($source)) $data->source = file($source);
  if (file_exists($dest)) { $data->dest = file($dest); } else { echo 'ERROR. Is this NEMS?' . PHP_EOL; exit(); }

  if (isset($data->source) && is_array($data->source)) {
    foreach ($data->source as $line) {
      $line = trim($line);
      if (substr($line,0,1) == '$') {
        $import = new stdClass();
        echo '  Importing: ' . $line . PHP_EOL;
        $tmp = explode('$',$line);
        // Check if user actually has a dollar sign in their password and append if yes
          $append='';
          $check=3; // starting key is 3 for the check
          while (isset($tmp[$check])) {
            $append .= '$' . $tmp[$check];
            unset($tmp[$check]);
            $check++; // it's dynamic, in case they have many $$ in their Pa$$word.
          }
        $tmp[3] = explode('=',$tmp[2]);
        $import->variable = $tmp[1];
        $import->value = $tmp[3][1] . $append;
        foreach ($data->dest as $line=>$destdata) {
          if (substr($destdata,0,(2+strlen($import->variable))) == '$' . $import->variable . '$') {
            // Only replace if it's not USER1/USER2 (NEMS system paths) to prevent a user setting breaking NEMS if paths are different
            if ($import->variable != 'USER1' && $import->variable != 'USER2') {
              // Replace the matching line in the destination
              $data->dest[$line] = '$' . $import->variable . '$=' . $import->value . PHP_EOL;
            }
          }
        }
      }
    }
    file_put_contents($dest,$data->dest);
    echo 'Consolidation complete.';
  } else {
    echo 'No data source found. Leaving NEMS-SST configuration as is.';
  }
  echo PHP_EOL;
?>
