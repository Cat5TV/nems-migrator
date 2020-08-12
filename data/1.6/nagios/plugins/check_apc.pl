#!/usr/bin/perl -w
#
# check_apc.pl v2.2
#
# version history
#
# 2.2 added High Precision value for InputVoltage/OutputVoltage/OutputCurrent (thanks to @fbarton)
# 2.1 added power modules check
# 2.0 first release after fork  
#
# Nagios plugin script for checking APC Symmetra UPS.
#
# License: GPL v2
# Copyright (c) 2017 Davide "Argaar" Foschi
# Based on previous work by LayerThree B.V.
# Previous Author: Michael van den Berg
#

use strict 'vars';
no warnings 'uninitialized';
use Net::SNMP qw(ticks_to_time);;
use Switch;
use Getopt::Std;
use Time::Local;

# Command arguments
my %options=();
getopts("H:C:l:p:t:w:c:hu", \%options);

# Help message etc
(my $script_name = $0) =~ s/.\///;

my $help_info = <<END;
\n$script_name - v2.2

Nagios script to check status of an APC Symmetra Uninteruptable Power Supply.

Usage:
-H  Address of hostname of UPS (required)
-C  SNMP community string (required)
-l  Command (optional, see command list)
-p  SNMP port (optional, defaults to port 161)
-t  Connection timeout (optional, default 10s)
-w  Warning threshold (optional, see commands)
-c  Critical threshold (optional, see commands)
-h  Use High Precision values for InputVoltage/OutputVoltage/OutputCurrent
-u  Script / connection errors will return unknown rather than critical

Commands (supplied with -l argument):

    id
        The UPS model name (e.g. 'APC Smart-UPS 600') and interlan info about Firmware, CPU S/N and manufacturing date

    bat_status
        The status of the UPS batteries

    bat_capacity
        The remaining battery capacity expressed in percent of full capacity

    bat_temp
        The current internal UPS temperature expressed in Celsius

    bat_run_remaining
        The UPS battery run time remaining before battery exhaustion
        ** NB: thresholds must be expressed in minutes **

    bat_replace
        Indicates whether the UPS batteries need replacing

    bat_num_batt
        The number of external battery packs connected to the UPS

    bat_num_bad_batt
        The number of external battery packs connected to the UPS that are defective

    bat_act_volt
        The actual battery bus voltage in Volts
        ** NB: thresholds must be expressed in range as nearest values. ex: normal=220, warning=215:225, critical=210:230 **
        ** Additionally, the checks will look for Nominal Voltage (as returned by the UPS), and exit as CRITICAL if Actual Voltage is LOWER or Equal **
        
    power_modules
        The status of the Power Modules

    in_phase
        The current AC input phase

    in_volt
        The current utility line voltage in VAC
        ** NB: thresholds must be expressed in range as nearest values. ex: normal=220, warning=215:225, critical=210:230 **

    in_freq
        The current input frequency to the UPS system in Hz
        ** NB: thresholds must be expressed in range as nearest values. ex: normal=50, warning=45:55, critical=40:60 **

    out_status
        The current state of the UPS

    out_phase
        The current output phase

    out_volt
        The output voltage of the UPS system in VAC
        ** NB: thresholds must be expressed in range as nearest values. ex: normal=220, warning=215:225, critical=210:230 **

    out_freq
        The current output frequency of the UPS system in Hz
        ** NB: thresholds must be expressed in range as nearest values. ex: normal=50, warning=45:55, critical=40:60 **

    out_load
        The current UPS load expressed in percent of rated capacity

    out_current
        The current in amperes drawn by the load on the UPS

    comm_status
        The status of agent's communication with UPS.

No command is supplied, the script return OKAY with the UPS model information.

Example:
$script_name -H ups1.domain.local -C public -l bat_status
END

# OIDs for the checks
my $oid_upsBasicIdentModel              = ".1.3.6.1.4.1.318.1.1.1.1.1.1.0";     # DISPLAYSTRING
my $oid_upsAdvIdentFirmwareRevision     = ".1.3.6.1.4.1.318.1.1.1.1.2.1.0";     # DISPLAYSTRING
my $oid_upsAdvIdentDateOfManufacture    = ".1.3.6.1.4.1.318.1.1.1.1.2.2.0";     # DISPLAYSTRING
my $oid_upsAdvIdentSerialNumber         = ".1.3.6.1.4.1.318.1.1.1.1.2.3.0";     # DISPLAYSTRING
my $oid_upsBasicBatteryStatus           = ".1.3.6.1.4.1.318.1.1.1.2.1.1.0";     # INTEGER {unknown(1),batteryNormal(2),batteryLow(3)}
my $oid_upsAdvBatteryCapacity           = ".1.3.6.1.4.1.318.1.1.1.2.2.1.0";     # GAUGE
my $oid_upsAdvBatteryTemperature        = ".1.3.6.1.4.1.318.1.1.1.2.2.2.0";     # GAUGE
my $oid_upsAdvBatteryRunTimeRemaining   = ".1.3.6.1.4.1.318.1.1.1.2.2.3.0";     # TIMETICKS
my $oid_upsAdvBatteryReplaceIndicator   = ".1.3.6.1.4.1.318.1.1.1.2.2.4.0";     # INTEGER {noBatteryNeedsReplacing(1),batteryNeedsReplacing(2)}
my $oid_upsAdvBatteryNumOfBattPacks     = ".1.3.6.1.4.1.318.1.1.1.2.2.5.0";     # INTEGER
my $oid_upsAdvBatteryNumOfBadBattPacks  = ".1.3.6.1.4.1.318.1.1.1.2.2.6.0";     # INTEGER
my $oid_upsAdvBatteryNominalVoltage     = ".1.3.6.1.4.1.318.1.1.1.2.2.7.0";     # INTEGER
my $oid_upsAdvBatteryActualVoltage      = ".1.3.6.1.4.1.318.1.1.1.2.2.8.0";     # INTEGER
my $oid_upsBasicInputPhase              = ".1.3.6.1.4.1.318.1.1.1.3.1.1.0";     # INTEGER
my $oid_upsAdvInputLineVoltage          = ".1.3.6.1.4.1.318.1.1.1.3.2.1.0";     # GAUGE
my $oid_upsAdvInputHPLineVoltage	       = ".1.3.6.1.4.1.318.1.1.1.3.3.1.0";	    # GAUGE32
my $oid_upsAdvInputFrequency            = ".1.3.6.1.4.1.318.1.1.1.3.2.4.0";     # GAUGE
my $oid_upsBasicOutputStatus            = ".1.3.6.1.4.1.318.1.1.1.4.1.1.0";     # INTEGER {unknown(1),onLine(2),onBattery(3),onSmartBoost(4),timedSleeping(5),softwareBypass(6),
                                                                                # off(7),rebooting(8),switchedBypass(9),hardwareFailureBypass(10),sleepingUntilPowerReturn(11),onSmartTrim(12)}
my $oid_upsBasicOutputPhase             = ".1.3.6.1.4.1.318.1.1.1.4.1.2.0";     # INTEGER
my $oid_upsAdvOutputVoltage             = ".1.3.6.1.4.1.318.1.1.1.4.2.1.0";     # GAUGE
my $oid_upsAdvOutputHPVoltage		      = ".1.3.6.1.4.1.318.1.1.1.4.3.1.0";	    # GAUGE32
my $oid_upsAdvOutputFrequency           = ".1.3.6.1.4.1.318.1.1.1.4.2.2.0";     # GAUGE
my $oid_upsAdvOutputLoad                = ".1.3.6.1.4.1.318.1.1.1.4.2.3.0";     # GAUGE
my $oid_upsAdvOutputCurrent             = ".1.3.6.1.4.1.318.1.1.1.4.2.4.0";     # GAUGE
my $oid_upsAdvOutputHPCurrent		      = ".1.3.6.1.4.1.318.1.1.1.4.3.4.0";	    # GAUGE32
my $oid_upsDiagPMTableSize              = ".1.3.6.1.4.1.318.1.1.1.13.2.1.0";    # INTEGER
my $oid_upsDiagPMSerialNumPrefix        = ".1.3.6.1.4.1.318.1.1.1.13.2.2.1.5."; # DISPLAYSTRING (DISTINCT POWER MODULE SERIAL NUMBER)
my $oid_upsDiagPMStatusPrefix           = ".1.3.6.1.4.1.318.1.1.1.13.2.2.1.2."; # INTEGER {unknown (1),notInstalled (2),offOk (3),onOk (4),offFail (5),onFail (6),lostComm (7)} (DISTINCT POWER MODULE STATUS)
my $oid_upsCommStatus                   = ".1.3.6.1.4.1.318.1.1.1.8.1.0";       # INTEGER {ok(1),noComm(2)}

# Nagios exit codes
my $OKAY        = 0;
my $WARNING     = 1;
my $CRITICAL    = 2;
my $UNKNOWN     = 3;

# Command arguments and defaults
my $snmp_host           = $options{H};
my $snmp_community      = $options{C};
my $snmp_port           = $options{p} || 161;   # SNMP port default is 161
my $connection_timeout  = $options{t} || 10;    # Connection timeout default 10s
my $default_error       = (!defined $options{u}) ? $CRITICAL : $UNKNOWN;
my $high_precision      = (defined $options{h}) ? 1 : 0;
my $check_command       = $options{l};
my $critical_threshold  = $options{c};
my $warning_threshold   = $options{w};
my $session;
my $error;
my $exitCode;

# APCs have a maximum length of 15 characters for snmp community strings
if(defined $snmp_community) {$snmp_community = substr($snmp_community,0,15);}

# If we don't have the needed command line arguments exit with UNKNOWN.
if(!defined $options{H} || !defined $options{C}){
    print "$help_info\n --> Not all required options were specified. <--\n\n";
    exit $UNKNOWN;
}

# Setup the SNMP session
($session, $error) = Net::SNMP->session(
    -hostname   => $snmp_host,
    -community  => $snmp_community,
    -timeout    => $connection_timeout,
    -port       => $snmp_port,
    -translate  => [-timeticks => 0x0]
);

# If we cannot build the SMTP session, error and exit
if (!defined $session) {
    my $output_header = ($default_error == $CRITICAL) ? "CRITICAL" : "UNKNOWN";
    printf "$output_header: %s\n", $error;
    exit $default_error;
}

# Determine what we need to do based on the command input
if (!defined $options{l}) {  # If no command was given, just output the UPS model
    my $ups_model = query_oid($oid_upsBasicIdentModel);
    $session->close();
    print "$ups_model\n";
    exit $OKAY;
} else {    # Process the supplied command. Script will exit as soon as it has a result.
    switch($check_command){

        case "id" {
            my $ups_name = query_oid($oid_upsBasicIdentModel);
            my $ups_firmware = query_oid($oid_upsAdvIdentFirmwareRevision);
            my $ups_serial = query_oid($oid_upsAdvIdentSerialNumber);
            my $ups_manufactdate = query_oid($oid_upsAdvIdentDateOfManufacture);
            $session->close();
            print "OK: UPS Name: $ups_name, Firmware: $ups_firmware, Microproc S/N: $ups_serial, Manufacture Date: $ups_manufactdate\n";
            exit $OKAY;
        }
        case "bat_status" {
            my $bat_status = query_oid($oid_upsBasicBatteryStatus);
            $session->close();
            if ($bat_status==2) {
                print "OK: Battery Status is Normal\n";
                exit $OKAY;
            } elsif ($bat_status==3) {
                print "CRITICAL: Battery Status is LOW and the UPS is unable to sustain the current load.\n";
                exit $CRITICAL;
            } else {
                print "UNKNOWN: Battery Status is UNKNOWN.\n";
                exit $UNKNOWN;
            }
        }
        case "bat_capacity" {
            my $bat_capacity = query_oid($oid_upsAdvBatteryCapacity);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $bat_capacity <= $critical_threshold){
                    print "CRITICAL: Battery Capacity $bat_capacity% is LOWER or Equal than the critical threshold of $critical_threshold%";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $bat_capacity <= $warning_threshold){
                    print "WARNING: Battery Capacity $bat_capacity% is LOWER or Equal than the warning threshold of $warning_threshold%";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Battery Capacity is: $bat_capacity%";
                    $exitCode = $OKAY; 
                }
                print "|'Battery Capacity'=$bat_capacity".";$warning_threshold;$critical_threshold;0;100\n";
            }
            exit $exitCode;
        }
        case "bat_temp" {
            my $bat_temp = query_oid($oid_upsAdvBatteryTemperature);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold<$warning_threshold) {
                print "ERROR: Critical Threshold should be GREATER than Warning Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $bat_temp >= $critical_threshold){
                    print "CRITICAL: Battery Temperature $bat_temp°C is HIGHER or Equal than the critical threshold of $critical_threshold";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $bat_temp >= $warning_threshold){
                    print "WARNING: Battery Temperature $bat_temp°C is HIGHER or Equal than the warning threshold of $warning_threshold";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Battery Temperature is: $bat_temp°C";
                    $exitCode = $OKAY; 
                }
                print "|'Battery Temperature'=$bat_temp".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "bat_run_remaining" {
            my $bat_run_remaining = query_oid($oid_upsAdvBatteryRunTimeRemaining) / 6000; # Convert in minutes
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $bat_run_remaining <= $critical_threshold){
                    print "CRITICAL: Battery Remaining Time $bat_run_remaining minutes is LOWER or Equal than the critical threshold of $critical_threshold";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $bat_run_remaining <= $warning_threshold){
                    print "WARNING: Battery Remaining Time $bat_run_remaining minutes is LOWER or Equal than the warning threshold of $warning_threshold";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Battery Remaining Time is: $bat_run_remaining minutes";
                    $exitCode = $OKAY; 
                }
                print "|'Battery Remaining Time'=$bat_run_remaining".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "bat_replace" {
            my $bat_replace = query_oid($oid_upsAdvBatteryReplaceIndicator);
            $session->close();
            if ($bat_replace==2) {
                print "WARNING: Battery Rack NEED a replacement\n";
                exit $WARNING;
            } elsif ($bat_replace==1) {
                print "OK: Battery Rack doesn't need a replacement\n";
                exit $OKAY;
            }
        }
        case "bat_num_batt" {
            my $bat_num_batt = query_oid($oid_upsAdvBatteryNumOfBattPacks);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $bat_num_batt <= $critical_threshold){
                    print "CRITICAL: Battery Packs Connected $bat_num_batt is LOWER or Equal than the critical threshold of $critical_threshold";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $bat_num_batt <= $warning_threshold){
                    print "WARNING: Battery Packs Connected $bat_num_batt is LOWER or Equal than the warning threshold of $warning_threshold";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Battery Packs Connected is: $bat_num_batt";
                    $exitCode = $OKAY; 
                }
                print "|'Battery Packs Connected'=$bat_num_batt".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "bat_num_bad_batt" {
            my $bat_num_bad_batt = query_oid($oid_upsAdvBatteryNumOfBadBattPacks);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold<$warning_threshold) {
                print "ERROR: Critical Threshold should be GREATER than Warning Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $bat_num_bad_batt >= $critical_threshold){
                    print "CRITICAL: Battery Fault Count $bat_num_bad_batt is HIGHER or Equal than the critical threshold of $critical_threshold";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $bat_num_bad_batt >= $warning_threshold){
                    print "WARNING: Battery Fault Count $bat_num_bad_batt is HIGHER or Equal than the warning threshold of $warning_threshold";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Battery Fault Count is: $bat_num_bad_batt";
                    $exitCode = $OKAY; 
                }
                print "|'Battery Fault Count'=$bat_num_bad_batt".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "bat_act_volt" {
            my $bat_nom_volt = query_oid($oid_upsAdvBatteryNominalVoltage);
            my $bat_act_volt = query_oid($oid_upsAdvBatteryActualVoltage);
            $session->close();
            if ($bat_act_volt>$bat_nom_volt) {
                if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                    print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                    $exitCode = $UNKNOWN;
                } else {
                    if (defined $critical_threshold && $bat_act_volt <= $critical_threshold){
                        print "CRITICAL: Battery Actual Voltage ".$bat_act_volt."V is LOWER or Equal than the critical threshold of $critical_threshold";
                        $exitCode = $CRITICAL;
                    } elsif (defined $warning_threshold && $bat_act_volt <= $warning_threshold){
                        print "WARNING: Battery Actual Voltage ".$bat_act_volt."V is LOWER or Equal than the warning threshold of $warning_threshold";
                        $exitCode = $WARNING;
                    }else{
                        print "OK: Battery Actual Voltage is: ".$bat_act_volt."V";
                        $exitCode = $OKAY; 
                    }
                    print "|'Battery Actual Voltage'=$bat_act_volt".";$warning_threshold;$critical_threshold\n";
                }
            } else {
                print "CRITICAL: Battery Actual Voltage $bat_act_volt is LOWER or Equal than the minimum required Nominal Voltage of $bat_nom_volt";
                $exitCode = $CRITICAL;
                print "|'Battery Actual Voltage'=$bat_act_volt".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "power_modules" {
            my $pm_Count = query_oid($oid_upsDiagPMTableSize);
            my @exitCodes;
            my @exitStrings;
            for (my $i=1; $i <= $pm_Count; $i++) {
                my $out_status = query_oid($oid_upsDiagPMStatusPrefix . $i);
                my $out_serialnumber = query_oid($oid_upsDiagPMSerialNumPrefix . $i);
                my $string;
                switch($out_status) {
                    case "1" {  #unknown
                        $string = "Power Module $i, S/N: $out_serialnumber status UNKNOWN";
                        $exitCodes[$i] = $UNKNOWN;
                    }
                    case "2" {  #notInstalled
                        $string = "Power Module $i, S/N: ----- status NOT INSTALLED";
                        $exitCodes[$i] = $OKAY;
                    }
                    case "3" {  #offOk
                        $string = "Power Module $i, S/N: $out_serialnumber status OFF-OK";
                        $exitCodes[$i] = $WARNING;
                    }
                    case "4" {  #onOk
                        $string = "Power Module $i, S/N: $out_serialnumber status ON-OK";
                        $exitCodes[$i] = $OKAY;
                    }
                    case "5" {  #offFail
                        $string = "Power Module $i, S/N: $out_serialnumber status OFF-FAIL";
                        $exitCodes[$i] = $CRITICAL;
                    }
                    case "6" {  #onFail
                        $string = "Power Module $i, S/N: $out_serialnumber status ON-FAIL";
                        $exitCodes[$i] = $WARNING;
                    }
                    case "7" {  #lostComm
                        $string = "Power Module $i, S/N: $out_serialnumber status LOSTCOMM";
                        $exitCodes[$i] = $WARNING;
                    }
                }
                $exitStrings[$i-1] = $string;
            }
            $session->close();
            
            my $exit_status_warn_found = grep { /1/ } @exitCodes;
            my $exit_status_crit_found = grep { /2/ } @exitCodes;
            my $exit_status_unk_found = grep { /3/ } @exitCodes;
           
            if ($exit_status_crit_found>=1) {
                print "CRITICAL: ";
                $exitCode = $CRITICAL;
            } elsif ($exit_status_warn_found>=1) {
                $exitCode = $WARNING;
                print "WARNING: ";
            } elsif ($exit_status_unk_found>=1) {
                $exitCode = $UNKNOWN;
                print "UNKNOWN: ";
            } else {
                $exitCode = $OKAY;
                print "OK: ";
            }
            print join(' - ',@exitStrings)."\n";
            exit $exitCode;
        }
        case "in_phase" {
            my $in_phase = query_oid($oid_upsBasicInputPhase);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $in_phase <= $critical_threshold ){
                    print "CRITICAL: Input Phase Number $in_phase is LOWER or Equal of the critical threshold ($critical_threshold)";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $in_phase <= $warning_threshold ){
                    print "WARNING: Input Phase Number $in_phase is LOWER or Equal of the warning threshold ($warning_threshold)";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Input Phase Number is: $in_phase";
                    $exitCode = $OKAY; 
                }
                print "|'Input Phase Number'=$in_phase".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "in_volt" {
            my $in_volt;
            if ($high_precision) {
                $in_volt = query_oid($oid_upsAdvInputHPLineVoltage)/10;
            } else {
                $in_volt = query_oid($oid_upsAdvInputLineVoltage);
            }
            $session->close();
            my @crit_values = split(/:/, $critical_threshold);
            my @warn_values = split(/:/, $warning_threshold);
            if (defined $critical_threshold && defined $warning_threshold && ($crit_values[0]>$warn_values[0] || $crit_values[1]<$warn_values[1])) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && ($in_volt <= $crit_values[0] || $in_volt >= $crit_values[1]) ){
                    print "CRITICAL: Input Voltage ".$in_volt."V is OUT OF RANGE of the critical threshold ($critical_threshold)";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && ($in_volt <= $warn_values[0] || $in_volt >= $warn_values[1]) ){
                    print "WARNING: Input Voltage ".$in_volt."V is OUT OF RANGE of the warning threshold ($warning_threshold)";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Input Voltage is: ".$in_volt."V";
                    $exitCode = $OKAY; 
                }
                print "|'Input Voltage'=$in_volt".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "in_freq" {
            my $in_freq = query_oid($oid_upsAdvInputFrequency);
            $session->close();
            my @crit_values = split(/:/, $critical_threshold);
            my @warn_values = split(/:/, $warning_threshold);
            if (defined $critical_threshold && defined $warning_threshold && ($crit_values[0]>$warn_values[0] || $crit_values[1]<$warn_values[1])) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && ($in_freq <= $crit_values[0] || $in_freq >= $crit_values[1]) ){
                    print "CRITICAL: Input Frequency ".$in_freq."Hz is OUT OF RANGE of the critical threshold ($critical_threshold)";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && ($in_freq <= $warn_values[0] || $in_freq >= $warn_values[1]) ){
                    print "WARNING: Input Frequency ".$in_freq."Hz is OUT OF RANGE of the warning threshold ($warning_threshold)";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Input Frequency is: ".$in_freq."Hz";
                    $exitCode = $OKAY; 
                }
                print "|'Input Frequency'=$in_freq".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "out_status" {
            my $out_status = query_oid($oid_upsBasicOutputStatus);
            my $out_status_code = {4 => 'onSmartBoost',5 => 'timedSleeping',6 => 'softwareBypass',8 => 'rebooting',9 => 'switchedBypass',11 => 'sleepingUntilPowerReturn',12 => 'onSmartTrim'};
            $session->close();
            switch($out_status) {
                case "1" {  #unknown
                    print "UNKNOWN: UPS running status is unknown\n";
                    exit $UNKNOWN;
                }
                case "2" {  #onLine
                    print "OK: UPS is Running on GridLine\n";
                    exit $OKAY;
                }
                case "3" {  #onBattery
                    print "CRITICAL: UPS is Running on BATTERY\n";
                    exit $CRITICAL;
                }
                case "7" {  #off
                    print "CRITICAL: UPS is OFF\n";
                    exit $CRITICAL;
                }
                case "10" {  #hardwareFailureBypass
                    print "CRITICAL: UPS is BYPASS due to HARDWARE FAILURE\n";
                    exit $CRITICAL;
                }
                else {
                    print "WARNING: UPS running status is $out_status_code->{$out_status}\n";
                    exit $WARNING;
                }
            }
        }
        case "out_phase" {
            my $out_phase = query_oid($oid_upsBasicOutputPhase);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $out_phase <= $critical_threshold ){
                    print "CRITICAL: Output Phase Number $out_phase is LOWER or Equal of the critical threshold ($critical_threshold)";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $out_phase <= $warning_threshold ){
                    print "WARNING: Output Phase Number $out_phase is LOWER or Equal of the warning threshold ($warning_threshold)";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Output Phase Number is: $out_phase";
                    $exitCode = $OKAY; 
                }
                print "|'Output Phase Number'=$out_phase".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "out_volt" {
            my $out_volt;
            if ($high_precision) {
                $out_volt = query_oid($oid_upsAdvOutputHPVoltage)/10;
            } else {
                $out_volt = query_oid($oid_upsAdvOutputVoltage);
            }
            $session->close();
            my @crit_values = split(/:/, $critical_threshold);
            my @warn_values = split(/:/, $warning_threshold);
            if (defined $critical_threshold && defined $warning_threshold && ($crit_values[0]>$warn_values[0] || $crit_values[1]<$warn_values[1])) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && ($out_volt <= $crit_values[0] || $out_volt >= $crit_values[1]) ){
                    print "CRITICAL: Output Voltage ".$out_volt."V is OUT OF RANGE of the critical threshold ($critical_threshold)";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && ($out_volt <= $warn_values[0] || $out_volt >= $warn_values[1]) ){
                    print "WARNING: Output Voltage ".$out_volt."V is OUT OF RANGE of the warning threshold ($warning_threshold)";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Output Voltage is: ".$out_volt."V";
                    $exitCode = $OKAY; 
                }
                print "|'Output Voltage'=$out_volt".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "out_freq" {
            my $out_freq = query_oid($oid_upsAdvOutputFrequency);
            $session->close();
            my @crit_values = split(/:/, $critical_threshold);
            my @warn_values = split(/:/, $warning_threshold);
            if (defined $critical_threshold && defined $warning_threshold && ($crit_values[0]>$warn_values[0] || $crit_values[1]<$warn_values[1])) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && ($out_freq <= $crit_values[0] || $out_freq >= $crit_values[1]) ){
                    print "CRITICAL: Output Frequency ".$out_freq."Hz is OUT OF RANGE of the critical threshold ($critical_threshold)";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && ($out_freq <= $warn_values[0] || $out_freq >= $warn_values[1]) ){
                    print "WARNING: Output Frequency ".$out_freq."Hz is OUT OF RANGE of the warning threshold ($warning_threshold)";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Output Frequency is: ".$out_freq."Hz";
                    $exitCode = $OKAY; 
                }
                print "|'Output Frequency'=$out_freq".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "out_load" {
            my $out_load = query_oid($oid_upsAdvOutputLoad);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold<$warning_threshold) {
                print "ERROR: Critical Threshold should be GREATER than Warning Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $out_load >= $critical_threshold){
                    print "CRITICAL: Output Load $out_load% is HIGHER or Equal than the critical threshold of $critical_threshold";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $out_load >= $warning_threshold){
                    print "WARNING: Output Load $out_load% is HIGHER or Equal than the warning threshold of $warning_threshold";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Output Load is: $out_load%";
                    $exitCode = $OKAY; 
                }
                print "|'Output Load'=$out_load".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "out_current" {
            my $out_current;
            if ($high_precision) {
                $out_current = query_oid($oid_upsAdvOutputHPCurrent)/10;
            } else {
                $out_current = query_oid($oid_upsAdvOutputCurrent);
            }
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold<$warning_threshold) {
                print "ERROR: Critical Threshold should be GREATER than Warning Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $out_current >= $critical_threshold){
                    print "CRITICAL: Output Current ".$out_current."A is HIGHER or Equal than the critical threshold of $critical_threshold";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $out_current >= $warning_threshold){
                    print "WARNING: Output Current ".$out_current."A is HIGHER or Equal than the warning threshold of $warning_threshold";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Output Current is: ".$out_current."A";
                    $exitCode = $OKAY; 
                }
                print "|'Output Current'=$out_current".";$warning_threshold;$critical_threshold\n";
            }
            exit $exitCode;
        }
        case "comm_status" {
            my $comm_status = query_oid($oid_upsCommStatus);
            $session->close();
            if ($comm_status==1) {
                print "OK: UPS Agent is Online\n";
                exit $OKAY;
            } elsif ($comm_status==2) {
                print "CRITICAL: UPS Agent isn't responding\n";
                exit $CRITICAL;
            }
        } else {
            print "$script_name - '$check_command' is not a valid comand\n";
            exit $UNKNOWN;
        }

    }
}

sub query_oid {
# This function will poll the active SNMP session and return the value
# of the OID specified. Only inputs are OID. Will use global $session 
# variable for the session.
    my $oid = $_[0];
    my $response = $session->get_request(-varbindlist => [ $oid ],);

    # If there was a problem querying the OID error out and exit
    if (!defined $response) {
        my $output_header = ($default_error == $CRITICAL) ? "CRITICAL" : "UNKNOWN";
        printf "$output_header: %s\n", $session->error();
        $session->close();
        exit $default_error;
    }

    return $response->{$oid};
}

# The end. We shouldn't get here, but in case we do exit unknown
print "UNKNOWN: Unknown script error\n";
exit $UNKNOWN;