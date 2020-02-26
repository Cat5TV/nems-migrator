#!/usr/bin/php
<?php

############################################################################
#
# check_mssql - Checks various aspect of MSSQL servers
#
# Copyright (c) 2008 Gary Danko <gdanko@gmail.com>
# Version 0.7.1 Copyright (c) 2013 Nagios Enterprises, LLC (Nicholas Scott <nscott@nagios.com>)
# Version 0.8.0 - 0.8.2 Copyright (c) 2017 Nagios Enterprises, LLC (Jake Omann <jomann@nagios.com>)
#
# Notes:
#
#   Version 0.1.0 - 2008/08/14
#   Initial release. Accepts hostname, username, password, port,
#   database name, and an optional query to run.
#
#   Version 0.2.0 - 2008/08/15
#   You can now execute a query or stored procedure and report
#   on expected results. Queries should be simplistic since
#   only the first row is returned.
#
#   Version 0.2.2 - 2008/08/18
#   Nothing major. Just a couple of cosmetic fixes.
#
#   Version 0.5.0 - 2008/09/29
#   Major rewrite. No new functionality. RegEx added to
#   validate command line options.
#
#   Version 0.6.0 - 2008/10/23
#   Allows the user to specify a SQL file with --query
#
#   Version 0.6.3 - 2008/10/26
#   Removed the -r requirement with -q.
#
#   Version 0.6.4 - 2008/10/31
#   Fixed a bug that would nullify an expected result of "0"
#
#   Version 0.6.5 - 2008/10/31
#   Minor fix for better display of error output.
#
#   Version 0.6.6 - 2008/10/31
#   Prepends "exec " to --storedproc if it doesn't exist.
#
#   Version 0.6.7 - 2012/07/05
#   Enabled instances to be used
#
#   Version 0.6.8 - 2012/08/30
#   Enabled returning of perfdata
#   Warning and crits may be decimal values
#
#   Version 0.6.9 - 2013/01/03
#   Fixed minor exit code bug
#
#   Version 0.7.0 - 2013/04/16
#   Added ability to make ranges on query results
#
#   Version 0.7.1 - 2013/06/17
#   Fixed bug with query ranges
#
#   Version 0.7.2 - 2014/11/20
#   Fixed to comply with Nagios threshold guidelines
#
#   Version 0.7.3 - 2015/02/11
#   Patch from D.Berger
#   1. the warning/critical defaults weren't as documented,
#   2. the warning and critical variables would be referenced undefined if not provided on the command line
#   3. the output wouldn't (always) include OK/WARNING/CRITICAL due to bad logic
#   4. the query result perf data wouldn't include warning/critical thresholds
#
#   Version 0.7.4 - 2015/08/15
#   - Allow usernames with a '_'
#   - Enhanced output_msg
#   - Bug fix for database connection test
#
#   Version 0.7.5 - 2015/09/04
#   - Added support for multiple line output with a second query
#
#   Version 0.7.6 - 2015/09/07
#   - Added support for encoding --encode a query
#
#   Version 0.7.7 - 2015/09/10
#   - Bug fixes
#
#   Version 0.7.8 - 2015/10/05
#   - Added the option read parameter from a php file
#
#   Version 0.7.9 - 2016/05/26
#   - Changed from deprecated mssql functions to PDO
#
#   Version 0.8.0 - 2017/06/30
#   - Added regex check for valid values -W and -C
#   - Added suggestin to try adding packages "php-pdo and php-mssql" for Cent/RHEL and others
#   - Updated output of usage / copyright
#   - Updated the check for valid -w and -c to match -W and -C
#   - Gives perfdata whether or not you have -W or -C values defined
#   - Fixed bugs with warning/critical value PHP notices during perfdata creation when missing
#   - Fixed output for UNKNOWN states
#   - Fixed output messages for results showing "OK: CRITICAL:"
#   - Fixed issue with 0 warning/critical values
#   - Fixed issue with -W and -C not being passed to the query check threshold function
#
#   Version 0.8.1 - 2017/08/03
#   - Updated username regex to allow for domain usernames
#   - Removed instance option since it is never used
#   - Fixed port value not being given to the dsn string
#
#   Version 0.8.2 - 2017/08/08
#   - Added back in instance support for freetds instances
#
#   Version 0.8.3 - 2017/01/11
#   - Added proper stored procedure support (previous changelog entries were lying)
#   - Added --parameter switch to pass parameters to stored procedures.
#   - Fixed comments to be reflective of changes which occurred in previous versions.
#   - Changed threshold calculation to be more intuitive to future developers.
#
#   This plugin will check the general health of an MSSQL
#   server. It will also report the query duration and allows
#   you to set warning and critical thresholds based on the
#   duration.
#
#   Requires:
#       yphp_cli-5.2.5_1 *
#       yphp_mssql-5.2.5_1 *
#       freetds *
#
# License Information:
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
############################################################################

$progname = "check_mssql";
$version = "0.8.3";
$warning = "";
$critical = "";
$output_msg = "";
$longquery = "";
$long_output = "";

// Parse the command line options
for ($i = 1; $i < $_SERVER['argc']; $i++) {
    $arg = $_SERVER["argv"][$i];
    switch($arg) {
        case '-h':
        case '--help':
            help();
        break;

        case '-V':
        case '--version':
            version();
        break;

        case '-H':
        case '--hostname':
            $db_host = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-u':
        case '-U':
        case '--username':
            $db_user = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-P':
        case '--password':
            $db_pass = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-F':
        case '--cfgfile':
            $db_cfgfile = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-I':
        case '--instance':
            $db_inst = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-p':
        case '--port':
            $db_port = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-d':
        case '--database':
            $db_name = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '--decode':
            $decode = true;
        break;

        case '--decodeonly':
            $decodeonly = true;
        break;

        case '--encode':
            $encode = true;
        break;

        case '-q':
        case '--query':
            $query = check_command_line_option($_SERVER["argv"][$i], $i);
            $querytype = "Query";
        break;

        case '-l':
        case '--longquery':
            $longquery = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-s':
        case '--storedproc':
            $storedproc = check_command_line_option($_SERVER["argv"][$i], $i);
            $querytype = "Stored Procedure";
        break;

        case '--parameters':
            $parameters = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-r':
        case '--result':
            $expected_result = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-W':
        case '--querywarning':
            $query_warning = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-C':
        case '--querycritical':
            $query_critical = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-w':
        case '--warning':
            $warning = check_command_line_option($_SERVER["argv"][$i], $i);
        break;

        case '-c':
        case '--critical':
            $critical = check_command_line_option($_SERVER["argv"][$i], $i);
        break;
    }
}

// Error out if mssql support is not present.
if (!extension_loaded('pdo_dblib')) {
    print "UNKNOWN: PDO MSSQL/DBLIB support is not installed on this server. Try adding packages php-pdo and php-mssql.\n";
    exit(3);
}

// If no options are set, display the help
if ($_SERVER['argc'] == 1) { 
    print "$progname: Could not parse arguments\n"; 
    usage(); 
    exit; 
}

// Read parameters like username and password from a file
if (isset($db_cfgfile)) {
    if (file_exists($db_cfgfile)) {
        include "$db_cfgfile";
    } else {
        print "UNKNOWN: $db_cfgfile does not exist.\n";
        exit(3);
    }
}

// Determine if the query is a SQL file or a text query
if (isset($query)) {
    if (file_exists($query)) {
        $query = file_get_contents($query);
    }
}

// Determine if the query is a SQL file or a text query
if (isset($longquery)) {
    if (file_exists($longquery)) {
        $longquery = file_get_contents($longquery);
    }
}

// Do not allow both -q and -s
if (isset($query) && isset($storedproc)) {
    print "UNKNOWN: The -q and -s switches are mutually exclusive. You may not select both.\n";
    exit(3);
}
else {
    if (isset($storedproc)) {
        if (isset($parameters)){
            $storedproc .= " " . $parameters;
        }
        $query = $storedproc;
    }
    unset($storedproc);
}


if (isset($query) and isset($decode)) {
    $query = urldecode($query);
}

if (isset($decodeonly)) {
    if (!isset($query)) {
        print "The --decodeonly switch requires a query -q/stored procedure -s.\n";
        exit(0);
    }
    print urldecode($query) . "\n";
    exit(0);
}

if (isset($encode)) {
    if (!isset($query)) {
        print "The --encode switch requires a query -q/stored procedure -s.\n";
        exit(0);
    }
    print str_replace('+', '%20', urlencode($query)) . "\n";
    exit(0); 
}

if (isset($longquery) and isset($decode)) {
    $longquery = urldecode($longquery);
}

// Add "exec" to the beginning of the stored proc if it doesnt exist.
if ($querytype === "Stored Procedure") {
    if (substr($query, 0, 5) != "exec ") {
        $query = "exec $query";
    }
}

// -r demands -q
if (isset($expected_result) && !isset($query)) {
    print "UNKNOWN: The -r switch requires the -q/-s switch. Please specify a query/stored procedure.\n";
    exit(3);
}

// Validate the hostname
if (isset($db_host)) {
    if (!preg_match("/^([a-zA-Z0-9-]+[\.])+([a-zA-Z0-9]+)$/", $db_host)) {
        print "UNKNOWN: Invalid characters in the hostname.\n";
        exit(3);
    }
} else {
    print "UNKNOWN: The required hostname field is missing.\n";
    exit(3);
}

// Validate the port
if (isset($db_port)) {
    if (!preg_match("/^([0-9]{4,5})$/", $db_port)) {
        print "UNKNOWN: The port field should be numeric and in the range 1000-65535.\n";
        exit(3);
    }
}

// Validate the username
if (isset($db_user)) {
    if (!preg_match("/^[a-zA-Z0-9-_\\\@]*$/", $db_user)) {
        print "UNKNOWN: Invalid characters in the username.\n";
        exit(3);
    }
} else {
    print "UNKNOWN: You must specify a username for this DB connection.\n";
    exit(3);
}

// Validate the password
if (empty($db_pass)) {
    print "UNKNOWN: You must specify a password for this DB connection.\n";
    exit(3);
}

$threshold_regex = "/^@?(~?(\d?\.?\d+)?\:?(\d?\.?\d+)?)$/";

// Validate the warning threshold
if ($warning != "" && !preg_match($threshold_regex, $warning)) {
    print "UNKNOWN: Invalid warning (-w | --warning) threshold.\n";
    exit(3);
}

// Validate the critical threshold
if ($critical != "" && !preg_match($threshold_regex, $critical)) {
    print "UNKNOWN: Invalid critical (-c | --critical) threshold.\n";
    exit(3);
}

// Validate the query warning threshold
if (isset($query_warning)) {
    if ($query_warning != "" && !preg_match($threshold_regex, $query_warning)) {
        print "UNKNOWN: Invalid warning (-W | --querywarning) threshold.\n";
        exit(3);
    }
}

// Validate the query critical threshold
if (isset($query_critical)) {
    if ($query_critical != "" && !preg_match($threshold_regex, $query_critical)) {
        print "UNKNOWN: Invalid query critical (-C | --querycritical) threshold.\n";
        exit(3);
    }
}

// Is warning greater than critical? Doesn't care about ranges
if (!empty($warning) && !empty($critical) && $warning > $critical) {
    $exit_code = 3;
    $output_msg = "UNKNOWN: warning value should be lower than critical value.\n";
    display_output($exit_code, $output_msg);
}

// Attempt to connect to the server
$time_start = microtime(true);

// make sure we have a database specified
if (empty($db_name)) {
    $exit_code = 3;
    $output_msg = "UNKNOWN: You must specify a database with the -q or -s switches.\n";
    display_output($exit_code, $output_msg);
}

$db_dsn_host = "host={$db_host}";
if (!empty($db_inst)) {
    $db_dsn_host .= "\\{$db_inst}";
} else if (!empty($port)) {
    $db_dsn_host .= ":{$db_port}";
}
$db_dsn = "dblib:{$db_dsn_host};dbname={$db_name}";
try {
    $connection = new PDO($db_dsn, $db_user, $db_pass);
} catch (PDOException $e) {
    $exit_code = 2;
    $output_msg = "CRITICAL: Could not connect to $db_dsn as $db_user (Exception: " . $e->getMessage() . ").\n";
    display_output($exit_code, $output_msg);
}

$time_end = microtime(true);
$query_duration = round(($time_end - $time_start), 6);

// Exit now if no query or stored procedure is specified
if (empty($query)) {
    $output_msg = "Connect time=$query_duration seconds.";
    $state = "OK";
    process_results($query_duration, $warning, $critical, $state, $output_msg);
}

$exit_code = 0;
$state = "OK";

// Attempt to execute the query/stored procedure
$time_start = microtime(true);
$pdo_query = $connection->prepare($query);
if (!$pdo_query->execute()) {
    $exit_code = 2;
    $output_msg = "CRITICAL: Could not execute the $querytype.\n";
    display_output($exit_code, $output_msg);
} else {
    $time_end = microtime(true);
    $query_duration = round(($time_end - $time_start), 6);
    $output_msg = "$querytype duration=$query_duration seconds.";
}

// Run query for multiple line output
if ($longquery) {
    $pdo_longquery = $connection->prepare($longquery);
    if ($pdo_longquery->execute()) {
        $longrows = $pdo_longquery->fetchALL(PDO::FETCH_ASSOC);
        foreach($longrows as $row) {
            foreach ($row as $col => $val) {
                $long_output .= $val . ' ';
            }
            $long_output = rtrim($long_output);
            $long_output .= "\n";
        }
    } else {
        $long_output = "Long Output Query Failed\n";
    }
}

$result_perf_data = null;
if ($querytype === "Query" || $querytype === "Stored Procedure") {
    $rows = $pdo_query->fetchAll(PDO::FETCH_ASSOC);
    foreach ($rows as $row) {
        foreach ($row as $col => $val) {
            $query_result = $val;
            $column_name = $col;
            $output_msg .= " $querytype result=$query_result";
        }
    }

    // Add perfdata even if we don't have W/C values defined
    $result_perf_data .= "'{$column_name}'={$query_result};";

    // Check against -W (warning) threshold
    if (isset($query_warning)) {
        $result_perf_data .= "{$query_warning};";
        switch (check_nagios_threshold($query_warning, $query_result))
        {
            case 3:
                $exit_code = 3;
                $state = "UNKNOWN";
                $output_msg = "In range threshold START:END, START must be less than or equal to END";
            case 1:
                $state = "WARNING";
                $exit_code = 1;
                $output_msg = "$querytype result $query_result was higher than $querytype warning threshold $query_warning.";
        }
    }

    // Check against -C (critical) threshold
    if (isset($query_critical)) {
        $result_perf_data .= "{$query_critical}";
        switch (check_nagios_threshold($query_critical, $query_result))
        {
            case 3:
                $exit_code = 3;
                $state = "UNKNOWN";
                $output_msg = "In range threshold START:END, START must be less than or equal to END";
            case 1:
                $exit_code = 2;
                $state = "CRITICAL";
                $output_msg = "$querytype result $query_result was higher than $querytype critical threshold $query_critical.";
        }
    }

    // Check for an expected result
    if (isset($expected_result) && !(isset($query_warning) || isset($query_critical))) {
        if ($query_result == $expected_result) {
           $output_msg = "$querytype results matched \"$query_result\", $querytype duration=$query_duration seconds.";
        } else {
            $exit_code = 2;
            $state = "CRITICAL";
            $output_msg = "$querytype expected \"$expected_result\" but got \"$query_result\".";
        }
    }
}

process_results($query_duration, $warning, $critical, $state, $output_msg, $exit_code, $result_perf_data, $long_output);

//-----------//
// Functions //
//-----------//

// Function to validate a command line option
function check_command_line_option($option, $i) {
    // If the option requires an argument but one isn't sent, bail out
    $next_offset = $i + 1;
    if (!isset($_SERVER['argv'][$next_offset]) || substr($_SERVER['argv'][$next_offset], 0, 1) == "-") {
            print "UNKNOWN: The \"$option\" option requires a value.\n";
    exit(3);
    } else {
            ${$option} = $_SERVER['argv'][++$i];
            return ${$option};
    }
}

// Function to process the results
function process_results($query_duration, $warning, $critical, $state, $output_msg, $exit_code = null, $result_perf_data=null, $long_output=null) {
    
    if (!$query_duration) {
        $response['result_code'] = 3;
        $response['output'] = "UNKNOWN: Could not perform query";
    } 
    
    $result_code = 0;
    if ($exit_code == null) {
        $result_prefix = "OK:";
    }
    
    if (!empty($warning)) {
        switch (check_nagios_threshold($warning, $query_duration)) {
            case 3:
                $exit_code = 3;
                $state = "UNKNOWN";
                $output_msg = "ERROR: In range threshold START:END, START must be less than or equal to END";
            case 1:
                $state = "WARNING";
                $exit_code = 1;
        }
    }
    
    if (!empty($critical)) {
        switch (check_nagios_threshold($critical, $query_duration)) {
            case 3:
                $exit_code = 3;
                $state = "UNKNOWN";
                $output_msg = "ERROR: In range threshold START:END, START must be less than or equal to END";
            case 1:
                $state = "CRITICAL";
                $exit_code = 2;
        }
    }

    $statdata = "$state: $output_msg";
    $perfdata = "query_duration={$query_duration}s;{$warning};{$critical}";
    if ($result_perf_data !== NULL) {
        $perfdata .= " $result_perf_data";
    }
    $output_msg = "{$statdata}|{$perfdata}\n{$long_output}";
    display_output($exit_code, $output_msg);
}

// Seems to return 0 for OK, 1 for warn/crit (depending on threshold), 3 for UNKNOWN.
function check_nagios_threshold($threshold, $value) {
    $inside = ((substr($threshold, 0, 1) == '@') ? true : false);
    $range = str_replace('@','', $threshold);
    $parts = explode(':', $range);
    
    if (count($parts) > 1) {
        $start = $parts[0];
        $end = $parts[1];
    } else {
        $start = 0;
        $end = $range;
    }

    if (substr($start, 0, 1) == "~") {
        $start = -999999999;
    }
    if ($end == "") {
        $end = 999999999;
    }
    if ($start > $end) {
        return 3;
    }

    if($start <= $value && $value <= $end) {
        return $inside;
    }
    else {
        return !$inside;
    }
}

// Function to display the output
function display_output($exit_code, $output_msg) {
    print $output_msg;
    exit($exit_code);
}

// Function to display usage information
function usage() {
    global $progname, $version;
    print <<<EOF
Usage: $progname -H <hostname> --username <username> --password <password>
       [--port <port> | --instance <instance>] [--database <database>] 
       [--query <"text">|filename] [--storeproc <"text">] [--result <text>] 
       [--warning <warn time>] [--critical <critical time>] [--help] [--version]
       [--querywarning <integer>] [--querycritical <integer>]

EOF;
}

// Function to display copyright information
function copyright() {
    global $progname, $version;
    print <<<EOF

Copyright (c) 2008 Gary Danko (gdanko@gmail.com)
              2012 Nagios Enterprises - Nicholas Scott (nscott@nagios.com)
              2017 Nagios Enterprises - Jake Omann (jomann@nagios.com)

EOF;
}

// Function to display detailed help
function help() {
    global $progname, $version;
    print "$progname, $version\n";
    print <<<EOF

This plugin checks various aspect of an MSSQL server. It will also
execute queries or stored procedures and return results based on
query execution times and expected query results.

Options:
    -h, --help          Print detailed help screen.
    -V, --version       Print version information.
    -H, --hostname      Hostname of the MSSQL server.
    -U, --username      Username to use when logging into the MSSQL server.
    -P, --password      Password to use when logging into the MSSQL server.
    -F, --cfgfile       Read parameters from a php file, e. g.
    -I, --instance      Optional MSSQL Instance. (Overrides port)
    -p, --port          Optional MSSQL server port. (Default is 1433)
    -d, --database      Optional DB name to connect to. 
    -q, --query         Optional query or SQL file to execute on MSSQL server.
    -l, --longquery     Optional query or SQL file to execute on MSSQL server.
                        The query is used for multiple line output only.
                        By default Nagios will only read the first 4 KB.
                        (MAX_PLUGIN_OUTPUT_LENGTH)
    --decode            Reads the query -q in urlencoded format. Useful if
                        special characters are in your query.
    --decodeonly        Decode the query -q
                        Prints the decoded query string and exits.
    --encode            Encodes the query -q
                        Prints urlencoded query and exits.
    -s, --storedproc    Optional stored procedure to execute on MSSQL server.
    --parameters        Optional parameters to pass to the stored procedure.
                        Assumes a comma-delimited list. Ignored if -s isn't set.
    -r, --result        Expected result from the specified query, requires -q.
                        The query pulls only the first row for comparison,
                        so you should limit yourself to small, simple queries.
    -w, --warning       Warning threshold in seconds on duration of check 
    -c, --critical      Critical threshold in seconds on duration of check
    -W, --querywarning  Query warning threshold
    -C, --querycritical Query critical threshold

Example: $progname -H myserver -U myuser -P mypass -q /tmp/query.sql -c 10 -W 2 -C 5
Example: $progname -H myserver -U myuser -P mypass -q "SELECT COUNT(*) FROM mytable" -r "632" -c 10 -W 2 -C 5

Note: Warning and critical threshold values should be formatted via the
Nagios Plugin guidelines. See guidelines here:
https://nagios-plugins.org/doc/guidelines.html#THRESHOLDFORMAT

Examples:   10          Alerts if value is > 10
            30:         Alerts if value < 30
            ~:30        Alerts if value > 30
            30:100      Alerts if 30 > value > 100
            @10:200     Alerts if 30 >= value <= 100
            @10         Alerts if value = 10

EOF;
    copyright();
    exit(0);
}

// Function to display version information
function version() {
    global $version;
    print <<<EOF
$version

EOF;
    exit(0);
}
