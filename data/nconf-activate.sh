#!/usr/bin/php
<?php
  $ver = $argv[1];

  $user = 'nconf';
  $db   = 'nconf';
  $pass = 'nagiosadmin';
  $db_host = "localhost";

  $db_name = $db ;
  $db_user = $user ;
  $db_pass = $pass ;
  $hosts = array();

	$conn = @($GLOBALS["___mysqli_ston"] = mysqli_connect($db_host,  $db_user,  $db_pass));
	if($conn){
			mysqli_select_db($conn, $db_name);
			@((bool)mysqli_query($GLOBALS["___mysqli_ston"], "USE $db_name"));
			$dbserver = 'main';
			$conn->set_charset('utf8');
			@mysqli_query($GLOBALS["___mysqli_ston"], "SET NAMES utf8") ;
	} else {
		die('Database not available');
	}

  # Find all hosts
  $query = "SELECT * FROM `ConfigValues` WHERE `fk_id_attr` = 15";
  $result = @mysqli_query($GLOBALS["___mysqli_ston"], $query);
  if($result){ //if query executed without errors
      while($row=@mysqli_fetch_assoc($result)){
        $hosts[$row['fk_id_item']] = $row['attr_value'];
      }
  }

  if (count($hosts) > 0) {
    foreach ($hosts as $id=>$name) {
      printf("Connecting default monitor to $name...");
      $query = "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES ($id,1,26,0)"; // insert an association with default nagios monitor
      $result = @mysqli_query($GLOBALS["___mysqli_ston"], $query);
      if ($result) { echo ' Done.'; } else { echo ' Error.'; }
      echo PHP_EOL;
    }
  } else {
    echo 'I could not find any hosts. This may be an error (unless you actually have none).' . PHP_EOL;
  }

  # Activate Host Presets
  printf('Activating default host presets... ');
  # 5231, 5258, etc are the ID corresponding with the host preset, which can be found by enabling General Query Log and monitoring the insert command when saving the host presets
# /etc/mysql/mariadb.conf.d/50-server.cnf
  # 5481 however, is the ID of the NEMS host (default host)
  if ($ver >= 1.6) { // During 1.6 alpha, the ID was changed to 5340.
    $fk_id = 5340;
    $query = "INSERT INTO ItemLinks (fk_id_item, fk_item_linked2, fk_id_attr, cust_order) VALUES (5276, $fk_id, 81, 0), (5259, $fk_id, 81, 0), (5231, $fk_id, 81, 0), (5258, $fk_id, 81, 0);";
  } else if ($ver >= 1.5) { // NEMS host was re-created, changing the ID from 5286 to 5473, then in NEMS 1.6 branch it is 5481.
#    $query = "INSERT INTO ItemLinks (fk_id_item, fk_item_linked2, fk_id_attr, cust_order) VALUES (5276, 5473, 81, 0), (5259, 5473, 81, 0), (5231, 5473, 81, 0), (5258, 5473, 81, 0);";
    $query = "INSERT INTO ItemLinks (fk_id_item, fk_item_linked2, fk_id_attr, cust_order) VALUES (5276, 5481, 81, 0), (5259, 5481, 81, 0), (5231, 5481, 81, 0), (5258, 5481, 81, 0);";
  } else { // older version before NEMS host was re-created
    $query = "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES (5231,5286,81,0),(5258,5286,81,0),(5259,5286,81,0),(5276,5286,81,0);";
  }
  $result = @mysqli_query($GLOBALS["___mysqli_ston"], $query);
  if ($result) { echo ' Done.'; } else { echo ' Error.'; }
  echo PHP_EOL;

?>
