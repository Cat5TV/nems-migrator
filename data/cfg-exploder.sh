#!/usr/bin/env php
<?php
  // blow up checkcommands
  // This simply breaks a checkcommandsfile into separate files for each check_command. That way the importer can fail on one but will still continue to import the rest.
  if (!isset($argv) || !isset($argv[1]) || !isset($argv[2])) {
    exit('Usage: ' . $argv[0] . ' /path/checkcommands.cfg /tmp/path' . PHP_EOL);
  }
  if (!file_exists($argv[2])) mkdir($argv[2]);
  $data = file_get_contents($argv[1]);
  $dataArr = explode('}', $data);
  $v=0;
  if (is_array($dataArr)) {
    foreach ($dataArr as $block) {
      file_put_contents($argv[2].'/'.$v++.'.cfg',$block.PHP_EOL.'}');
    }
  }
?>
