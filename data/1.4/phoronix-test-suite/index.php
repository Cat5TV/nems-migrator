<?php
  echo '<h1>Phoronix Test Suite for NEMS Linux</h1><h2>Weekly Benchmarks</h2>';

  $logs = array_diff(scandir('.'), array('..', '.', 'index.php'));
  if (is_array($logs) && count($logs) > 0) {
    rsort($logs);
    echo '<ul>' . PHP_EOL;
    foreach ($logs as $log) {
      echo '  <li><a href="./' . $log . '">' . date('F j, Y',strtotime($log)) . '</a></li>' . PHP_EOL;
    }
    echo '</ul>' . PHP_EOL;
  } else {
    echo 'Your NEMS Linux server is too new.<br />Benchmarks will be generated within 7 days (assuming you leave it running 24/7).<br />Please check back soon.';
  }
?>
