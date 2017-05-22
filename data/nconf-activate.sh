#!/bin/php
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
  $result = @mysqli_query($GLOBALS["___mysqli_ston"], $query) ;
  if($result){ //if query executed without errors
      while($row=@mysqli_fetch_assoc($result)){
        $host[$row['fk_id_item']] = $row['attr_value'];
      }
  }
