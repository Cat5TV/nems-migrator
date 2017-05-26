#!/usr/bin/php
<?php
  $user = 'nconf';
  $db   = 'nconf';
  $pass = 'nagiosadmin';
  $db_host = "localhost";

  $db_name = $db ;
  $db_user = $user ;
  $db_pass = $pass ;

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

  if (is_array($hosts)) {
    foreach ($hosts as $id=>$name) {
      printf("Connecting default monitor to $name...");
      $query = "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES ($id,1,26,0)"; // insert an association with default nagios monitor
      $result = @mysqli_query($GLOBALS["___mysqli_ston"], $query);
      if ($result) { echo ' Done.'; } else { echo ' Error.'; }
      echo PHP_EOL;
    }
  }

  # Activate Host Presets
  $query  = "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES (5231,5286,81,0)";
  $query .= "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES (5258,5286,81,0)";
  $query .= "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES (5259,5286,81,0)";
  $query .= "INSERT INTO ItemLinks (`fk_id_item`,`fk_item_linked2`,`fk_id_attr`,`cust_order`) VALUES (5276,5286,81,0)";
  $result = @mysqli_query($GLOBALS["___mysqli_ston"], $query);


?>
