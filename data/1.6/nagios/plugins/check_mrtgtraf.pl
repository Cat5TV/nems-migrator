#!/usr/bin/perl -w

# By Alexander Silveröhrt 2012-08-18
# cocoon.is@gmail.com
# see ./scriptname -help for information on how to use this script.
# check mrtg bandwidth log files for bandwidth values.
# And compare those values with supplied WARNING and CRITICAL pairs thresholds.
# This script will return below values depending on, if any threshold were exceeded or not.
# then it will present detailed information about the result.
# %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# 1.0.2 Fixes and improvements by Robbie Ferguson for NEMS Linux

use POSIX;
use strict;
use Getopt::Long;
use Math::Round;

## use lib below needs path to directory that holds nagios included utils.pm ##
#use lib qw( /usr/local/nagios/libexec );
use lib "/usr/local/nagios/libexec";
#use lib utils.pm;
use utils qw(%ERRORS &print_revision &support &usage);
#%ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Globals
our($SCRIPT, $VERSION, %OPTS, $function_flag, $f_flag, $w_flag, $c_flag, $u_flag);
our($v_flag, $help_flag, $d_flag);

$SCRIPT = "check_mrtgtraf.pl";
$VERSION = "1.0.2";

GetOptions ("f|FUN|FUNCTION:s" => \$function_flag,
                "l|LOG|LOGfile:s" => \$f_flag,
                "w|warn|warning:s" => \$w_flag,
                "c|crit|critical:s" => \$c_flag,
		"u|un|UNIT:s" => \$u_flag,
                "v|version" => \$v_flag,
                "help" => \$help_flag,
                "d|debug" => \$d_flag);

my $FUNCTION = $function_flag;
my $MRTG_FILE = $f_flag;
my $WARNING_THRESHOLD = $w_flag;
my $CRITICAL_THRESHOLD = $c_flag;
my $THRESHOLD_UNIT = $u_flag;

my $VERSIONFLAG = $v_flag;
my $DEBUG = $d_flag;
my $HELP = $help_flag;

my @warningThresholdSplit;
my @criticalThresholdSplit;

my $splittedWarningThresholdIncoming;
my $splittedWarningThresholdOutgoing;
my $splittedCriticalThresholdIncoming;
my $splittedCriticalThresholdOutgoing;

my $mrtgLogFileColumn2_AVG_IncomingBytesCounter;
my $mrtgLogFileColumn3_AVG_OutgoingBytesCounter;
my $mrtgLogFileColumn4_MAX_IncomingBytesCounter;
my $mrtgLogFileColumn5_MAX_OutgoingBytesCounter;

my $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte;
my $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte;
my $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte;
my $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte;

my $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes;
my $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes;
my $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes;
my $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes;

my $mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte = 0;
my $mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte = 0;
my $mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte = 0;
my $mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte = 0;

##############################
### Some Default behaviour ###
##############################
if ($VERSIONFLAG)
{
        printf ("$VERSION\n");
        exit;
} 
if ($HELP)
{
        _usage();
}
if (!$FUNCTION)
{
	if ($DEBUG)
	{
        	printf("\nINFORMATIVE: No -function input supplied to script!! Using default -function AVG..\n");
	}
	$FUNCTION = "AVG";
}

##################################
## MAIN We run from here	##
##################################

## split warning and critical thresholds and assign it to a variable ##
@warningThresholdSplit = split(/,/, $WARNING_THRESHOLD);
@criticalThresholdSplit = split(/,/, $CRITICAL_THRESHOLD);

if ($DEBUG)
{
	printf("\nwarningThresholdSplit = @warningThresholdSplit\ncriticalThresholdSplit = @criticalThresholdSplit");
}

$splittedWarningThresholdIncoming = $warningThresholdSplit[0];
$splittedWarningThresholdOutgoing  = $warningThresholdSplit[1];
$splittedCriticalThresholdIncoming = $criticalThresholdSplit[0];
$splittedCriticalThresholdOutgoing  = $criticalThresholdSplit[1];;

## Check that we have both pairs <incoming>,<outgoing> if not we do what we can ##
## WARNING Checks ##
if ( (!$splittedWarningThresholdIncoming) && (!$splittedWarningThresholdOutgoing) )
{
	if ($DEBUG)
        {
                printf("\nNo Warning Threshold <incoming>,<outgoing> detected.! WARNING_THRESHOLD = $WARNING_THRESHOLD ..Exiting!\n");
        }	
	_usage();
}
elsif ( ($splittedWarningThresholdIncoming) && ($splittedWarningThresholdOutgoing) )
{
	if ($DEBUG)
        {
                printf("\nINFORMATIVE <incoming>,<outgoing> = pairs detected.! WARNING_THRESHOLD = $WARNING_THRESHOLD!\n");
        }	
}
elsif ( ( ($splittedWarningThresholdOutgoing) && (!$splittedWarningThresholdIncoming) ) || ( (!$splittedWarningThresholdOutgoing) && ($splittedWarningThresholdIncoming) ) )
{
	if ($DEBUG)
	{
                printf("\nINFORMATIVE: WarningThreshold should be supplied as a pair -w <incoming>,<outgoing>!!\n");
	}
        $splittedWarningThresholdOutgoing = $splittedWarningThresholdIncoming;
}
else
{
	## UNKNOWN error ##
	printf ("\nERROR: Something is wrong with the supplied WARNING_THRESHOLD. WARNING_THRESHOLD = $WARNING_THRESHOLD");
}

## Critical Threshold checks ##
if ( (!$splittedCriticalThresholdIncoming) && (!$splittedCriticalThresholdOutgoing) )
{
        if ($DEBUG)
        {       
                printf("\nNo Critical Threshold <incoming>,<outgoing> detected.! CRITICAL_THRESHOLD = $CRITICAL_THRESHOLD ..Exiting!\n");
        }       
        _usage();
}
elsif ( ($splittedCriticalThresholdIncoming) && ($splittedCriticalThresholdOutgoing) )
{
        if ($DEBUG)
        {       
                printf("\nINFORMATIVE <incoming>,<outgoing> = pairs detected.! CRITICAL_THRESHOLD = $CRITICAL_THRESHOLD!\n");
        }       
}
elsif ( ( ($splittedCriticalThresholdIncoming) && (!$splittedCriticalThresholdOutgoing) )  || ( ($splittedCriticalThresholdIncoming) && (!$splittedCriticalThresholdOutgoing) ) )
{
	if ($DEBUG)
	{
		printf("\nINFORMATIVE: Critical Threshold shold be supplied as a pair -c <incoming>,<outgoing>!!\n");
	}
	$splittedCriticalThresholdOutgoing = $splittedCriticalThresholdIncoming;
}
else
{
	## UKNOWN error ##
	printf ("\nERROR: Something is wrong with the supplied CRITICAL_THRESHOLD. CRITICAL_THRESHOLD = $CRITICAL_THRESHOLD");
	exit($ERRORS{'UNKNOWN'});
}

if ($DEBUG)
{
	printf("\nAfter correction splittedWarningThresholdIncoming = $splittedWarningThresholdIncoming, splittedWarningThresholdOutgoing = $splittedWarningThresholdOutgoing\nsplittedCriticalThresholdIncoming = $splittedCriticalThresholdIncoming, splittedCriticalThresholdOutgoing, $splittedCriticalThresholdOutgoing\n");
}

####################################################
### Here we convert supplied THRESHOLDS to bytes ###  
### But only if we got a unit to start with.	 ###
### Default is bytes				 ###
####################################################
if ($THRESHOLD_UNIT)
{
        if ($DEBUG)
        {
                printf ("\nPassed in THRESHOLD_UNIT = $THRESHOLD_UNIT");
        }
        if ( ($THRESHOLD_UNIT =~ /k|kilobyte/i) )
        {
		$splittedWarningThresholdIncoming = ($splittedWarningThresholdIncoming * 1024);
		$splittedWarningThresholdOutgoing = ($splittedWarningThresholdOutgoing * 1024);
		$splittedCriticalThresholdIncoming = ($splittedCriticalThresholdIncoming * 1024);
		$splittedCriticalThresholdOutgoing = ($splittedCriticalThresholdOutgoing * 1024);
        }
        elsif ( ($THRESHOLD_UNIT =~ /m|megabyte/i) )
        {
		$splittedWarningThresholdIncoming = ( ( ($splittedWarningThresholdIncoming * 1024) * 1024) );
		$splittedWarningThresholdOutgoing = ( ( ($splittedWarningThresholdOutgoing * 1024) * 1024) );
		$splittedCriticalThresholdIncoming = ( ( ($splittedCriticalThresholdIncoming * 1024) * 1024) );
		$splittedCriticalThresholdOutgoing = ( ( ($splittedCriticalThresholdOutgoing * 1024) * 1024) );
        }
        elsif ( ($THRESHOLD_UNIT =~ /g|gigabyte/i) )
        {
		$splittedWarningThresholdIncoming = ( ( ( ($splittedWarningThresholdIncoming * 1024) * 1024) * 1024) );
		$splittedWarningThresholdOutgoing = ( ( ( ($splittedWarningThresholdOutgoing * 1024) * 1024) * 1024) );
		$splittedCriticalThresholdIncoming = ( ( ( ($splittedCriticalThresholdIncoming * 1024) * 1024) * 1024) );
		$splittedCriticalThresholdOutgoing = ( ( ( ($splittedCriticalThresholdOutgoing * 1024) * 1024) * 1024) );
        }
        elsif ( ($THRESHOLD_UNIT =~ /t|terabyte/i) )
        {
		$splittedWarningThresholdIncoming = ( ( ( ( ($splittedWarningThresholdIncoming * 1024) * 1024) * 1024) * 1024) );
		$splittedWarningThresholdOutgoing = ( ( ( ( ($splittedWarningThresholdOutgoing * 1024) * 1024) * 1024) * 1024) );
		$splittedCriticalThresholdIncoming = ( ( ( ( ($splittedCriticalThresholdIncoming * 1024) * 1024) * 1024) * 1024) );
		$splittedCriticalThresholdOutgoing = ( ( ( ( ($splittedCriticalThresholdOutgoing * 1024) * 1024) * 1024) * 1024) );
        }
	else
	{
		if ($DEBUG)
		{
			printf ("\nNo THRESHOLD_UNIT match on passed in unit was found. We will try default bytes and trust that input was valid");
		}
	}

	if ($DEBUG)
	{
	printf("\n\nAfter unit conversion splittedWarningThresholdIncoming = $splittedWarningThresholdIncoming, splittedWarningThresholdOutgoing = $splittedWarningThresholdOutgoing\nsplittedCriticalThresholdIncoming = $splittedCriticalThresholdIncoming, splittedCriticalThresholdOutgoing, $splittedCriticalThresholdOutgoing\n");
	}

}

#################################################################
### call the function that retrieves the log values from MRTG ###
#################################################################

($mrtgLogFileColumn2_AVG_IncomingBytesCounter, $mrtgLogFileColumn3_AVG_OutgoingBytesCounter, $mrtgLogFileColumn4_MAX_IncomingBytesCounter, $mrtgLogFileColumn5_MAX_OutgoingBytesCounter) = _getMrtgLogFileValues($MRTG_FILE, $DEBUG);

######################################################################
### Calculate if we want to show the printouts in Kbytes or Mbytes ###
######################################################################

### If column2 bytes value is larger than 1 Mb ###
if ( ( ($mrtgLogFileColumn2_AVG_IncomingBytesCounter / 1024) / 1024) > 1)
{
	$mrtgLogFileColumn2_AVG_IncomingBytesToMbyte = nearest(.01, ( ($mrtgLogFileColumn2_AVG_IncomingBytesCounter / 1024) / 1024) );
	$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte = 1;
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn2_AVG_IncomingBytesToMbyte = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte");
        }
}
else 
{
	$mrtgLogFileColumn2_AVG_IncomingBytesToKbytes = nearest(.01, ($mrtgLogFileColumn2_AVG_IncomingBytesCounter / 1024) );
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn2_AVG_IncomingBytesToKbytes = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes");
        }
}
### If column3 bytes value is larger than 1 Mb ###
if ( ( ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter / 1024) / 1024) > 1)
{
	$mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte = nearest(.01, ( ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter / 1024) / 1024) );
	$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte = 1;
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn3_AVG_OutgoingBytesToMbyte = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte");
        }
}
else
{
	$mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes = nearest(.01, ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter / 1024) );
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn3_AVG_OutgoingBytesToKbytes = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes");
        }
}
### If column4 bytes value is larger than 1 Mb ###
if ( ( ($mrtgLogFileColumn4_MAX_IncomingBytesCounter / 1024) / 1024) > 1)
{
	$mrtgLogFileColumn4_MAX_IncomingBytesToMbyte = nearest(.01, ( ($mrtgLogFileColumn4_MAX_IncomingBytesCounter / 1024) / 1024) );
	$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte = 1;
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn4_MAX_IncomingBytesToMbyte = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte");
        }
}
else
{
	$mrtgLogFileColumn4_MAX_IncomingBytesToKbytes = nearest(.01, ($mrtgLogFileColumn4_MAX_IncomingBytesCounter / 1024) );
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn4_MAX_IncomingBytesToKbytes = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes");
        }
}
### If column5 bytes value is larger than 1 Mb ###
if ( ( ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter / 1024) / 1024) > 1)
{
	$mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte = nearest(.01, ( ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter / 1024) / 1024) );
	$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte = 1;
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn5_MAX_OutgoingBytesToMbyte = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte");
        }
}
else
{
	$mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes = nearest(.01, ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter / 1024) );
	if ($DEBUG)
        {
		printf("\nmrtgLogFileColumn5_MAX_OutgoingBytesToKbytes = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes");
        }
}
#printf ("\n");

############################################################################################
### See if we exceeded any warning or critical threshold and return the STATUS to nagios ###
############################################################################################
if ($FUNCTION eq "AVG")
{	
	### If column 2(AVG) "incoming bytes counter" is larger than incoming warning threshold ###
	if ( ($mrtgLogFileColumn2_AVG_IncomingBytesCounter > $splittedWarningThresholdIncoming) && ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter < $splittedWarningThresholdOutgoing) )
	{	
		if ($DEBUG)
        	{
			printf("IF-1");
        	}

		### If column 2(AVG) "incoming bytes counter" is larger than Critical warning threshold ###
		if ($mrtgLogFileColumn2_AVG_IncomingBytesCounter > $splittedCriticalThresholdIncoming)
		{ 
			if ($DEBUG)
        		{
				printf("IF-2");
        		}
			### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
        			{	
					printf("IF-3");
        			}
printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
        			{	
					printf("IF-4");
        			}
printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
        			{	
					printf("IF-5");
        			}
printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
        			{	
					printf("IF-6");
        			}
printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}	
		else  ### If column 2(AVG) "incoming bytes counter" is NOT larger than Critical warning threshold ###
		{
			if ($DEBUG)
        		{
				printf("IF-7");
        		}
 
			### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
        			{	
					printf("IF-8");
        			}

printf ("Traffic WARNING: AVG. in exceeds WARNING Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
        			{	
					printf("IF-9");
        			}

printf ("Traffic WARNING: AVG. in exceeds WARNING Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
        			{	
					printf("IF-10");
        			}

printf ("Traffic WARNING: AVG. in exceeds WARNING Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			}
			
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
        			{	
					printf("IF-11");
        			}

printf ("Traffic WARNING: AVG. in exceeds WARNING Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			}
		}
		
	}
	## If column 3(AVG) "Outgoing bytes counter" is larger than outgoing warning threshold ##
	elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter > $splittedWarningThresholdOutgoing) && ($mrtgLogFileColumn2_AVG_IncomingBytesCounter < $splittedWarningThresholdIncoming) ) 
	{
		if ($DEBUG)
        	{	
			printf("IF-12");
        	}
		### If column 3(AVG) "Outgoing bytes counter" is larger than Critical warning threshold ###
		if ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter > $splittedCriticalThresholdOutgoing)
		{
			if ($DEBUG)
    			{	
				printf("IF-13");
        		}
 
			### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
        			{	
					printf("IF-14");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
        			{	
					printf("IF-15");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
        			{	
					printf("IF-16");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
        			{	
					printf("IF-17");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}	
		else  ### If column 3(AVG) "Outgoing bytes counter" is NOT larger than Critical warning threshold ###
		{
			if ($DEBUG)
        		{	
				printf("IF-18");
        		}

			### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
        			{	
					printf("IF-19");
        			}

printf ("Traffic WARNING: AVG. out exceeds WARNING Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
        			{	
					printf("IF-20");
        			}

printf ("Traffic WARNING: AVG. out exceeds WARNING Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
        			{	
					printf("IF-21");
        			}

printf ("Traffic WARNING: AVG. out exceeds WARNING Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			}
			
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
        			{	
					printf("IF-22");
        			}

printf ("Traffic WARNING: AVG. out exceeds WARNING Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			}
		}
		
	}
############
############
	### If column 2(AVG) "incoming bytes counter" exceeds incoming warning threshold AND ###
	### column 3(AVG) "Outgoing bytes counter" exceeds outgoing warning threshold	       ###
	elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesCounter > $splittedWarningThresholdIncoming) && ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter > $splittedWarningThresholdOutgoing) )
	{
		if ($DEBUG)
        	{	
			printf("IF-23");
        	}

		### If column 2(AVG) "incoming bytes counter" is exceeding incoming Critical threshold AND ###
		### column 3(AVG) "Outgoing bytes counter" IS NOT exceeding Outgoing Critical threshold	###
		if ( ($mrtgLogFileColumn2_AVG_IncomingBytesCounter > $splittedCriticalThresholdIncoming) && ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter < $splittedCriticalThresholdOutgoing) )
		{
			if ($DEBUG)
        		{	
				printf("IF-24");
        		}

		 	### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
        			{	
					printf("IF-25");
        			}

printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
        			{	
					printf("IF-26");
        			}

printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
        			{	
					printf("IF-27");
        			}

printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
        			{	
					printf("IF-28");
        			}

printf ("Traffic CRITICAL: AVG. in exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}
		### If column 2(AVG) "incoming bytes counter" is NOT exceeding incoming warning threshold AND 	###
		### column 3(AVG) "Outgoing bytes counter" IS exceeding Outgoing warning threshold			###
		elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter > $splittedCriticalThresholdOutgoing) && ($mrtgLogFileColumn2_AVG_IncomingBytesCounter < $splittedCriticalThresholdIncoming) ) 
		{
			if ($DEBUG)
        		{	
				printf("IF-29");
        		}

			### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
        			{	
					printf("IF-30");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
        			{	
					printf("IF-31");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold in. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
        			{	
					printf("IF-32");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
        			{	
					printf("IF-33");
        			}

printf ("Traffic CRITICAL: AVG. out exceeds CRITICAL Threshold out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}
		### If column 2(AVG) "incoming bytes counter" is exceeding incoming warning threshold AND  ###
                ### column 3(AVG) "Outgoing bytes counter" IS exceeding Outgoing warning threshold         ###
                elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesCounter > $splittedCriticalThresholdOutgoing) && ($mrtgLogFileColumn2_AVG_IncomingBytesCounter > $splittedCriticalThresholdIncoming) )
                {
				if ($DEBUG)
        			{	
					printf("IF-34");
        			}

                        ### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
                        ### This is for fine tuned presentation only ###
                        if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
                        {
					if ($DEBUG)
      	  			{	
						printf("IF-35");
        				}

printf ("Traffic CRITICAL: AVG. in and AVG. out exceeds CRITICAL Threshold in and out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
                                exit($ERRORS{'CRITICAL'});
                        } ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
                        elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) )
                        {
					if ($DEBUG)
      	  			{	
						printf("IF-36");
        				}

printf ("Traffic CRITICAL: AVG. in and AVG. out exceeds CRITICAL Threshold in and out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
                                exit($ERRORS{'CRITICAL'});
                        }
                        ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
                        elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
                        {
					if ($DEBUG)
      	  			{	
						printf("IF-37");
        				}

printf ("Traffic CRITICAL: AVG. in and AVG. out exceeds CRITICAL Threshold in and out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
                                exit($ERRORS{'CRITICAL'});
                        }

                        else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
                        {
					if ($DEBUG)
      	  			{	
						printf("IF-38");
        				}

printf ("Traffic CRITICAL: AVG. in and AVG. out exceeds CRITICAL Threshold in and out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
                                exit($ERRORS{'CRITICAL'});
                        }
                }
		else  ### column 2(AVG) "incoming bytes counter" AND column 3(AVG) "Outgoing bytes counter" IS NOT exceeding incoming and outgoing CRITICAL threshold AND ###
		{
			if ($DEBUG)
      	  	{	
				printf("IF-39");
        		}

			### If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
      	  		{	
					printf("IF-40");
        			}

printf ("Traffic WARNING: AVG. in and AVG. out exceeds WARNING Threshold in and out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			} ### If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
      	  		{	
					printf("IF-41");
        			}

printf ("Traffic WARNING: AVG. in and AVG. out exceeds WARNING Threshold in and out.  AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			} 
			### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
      	  		{	
					printf("IF-42");
        			}

printf ("Traffic WARNING: AVG. in and AVG. out exceeds WARNING Threshold in and out. AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			}
			else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
      	  		{	
					printf("IF-43");
        			}

printf ("Traffic WARNING: AVG. in and AVG. out exceeds WARNING Threshold in and out. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			}
		}
	}
############
############
	else	### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are not exeeding warning thresholds ###
	{
		if ($DEBUG)
      	{	
			printf("IF-44");
        	}

		## If column 2(AVG) "incoming bytes counter" is larger than 1 Mbyte and column3(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte 
		### This is for fine tuned presentation only ###
		if ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
        	{
			if ($DEBUG)
      	  	{	
				printf("IF-45");
        		}

printf ("Traffic OK: AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
			exit($ERRORS{'OK'});		
		} ## If column3(AVG) "outgoing bytes counter" is larger than 1 Mbyte and column2(AVG) "outgoing bytes counter" is NOT larger than 1 Mbyte##
		elsif ( ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) ) 
		{
			if ($DEBUG)
      	  	{	
				printf("IF-46");
        		}

printf ("Traffic OK: AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
			exit($ERRORS{'OK'});
		} ## Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are larger than 1 Mbyte
		elsif ( ($mrtgLogFileColumn2_AVG_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn3_AVG_OutgoingBytesIsLargerThan1Mbyte) )
		{
			if ($DEBUG)
      	  	{	
				printf("IF-47");
        		}

printf ("Traffic OK: AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToMbyte Mbyte/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToMbyte Mbyte/s.");
			exit($ERRORS{'OK'});
		}
		else ### Both column 2(AVG) "incoming bytes counter" AND column3(AVG) "outgoing bytes counter" are smaller than 1 Mbyte ###
		{
			if ($DEBUG)
      	  	{	
				printf("IF-48");
        		}

printf ("Traffic OK: AVG. in = $mrtgLogFileColumn2_AVG_IncomingBytesToKbytes Kbytes/s, AVG. out = $mrtgLogFileColumn3_AVG_OutgoingBytesToKbytes Kbytes/s.");
			exit($ERRORS{'OK'});
		}
	}
}
if ($FUNCTION eq "MAX")
{	
	### If column 4(MAX) "incoming bytes counter" IS larger than incoming warning threshold AND ###
	### If column 5(MAX) "outgoing bytes counter" IS NOT larger than warning threshold ###
	if ( ($mrtgLogFileColumn4_MAX_IncomingBytesCounter > $splittedWarningThresholdIncoming) && ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter < $splittedWarningThresholdOutgoing) )
	{
		if ($DEBUG)
		{	
			printf("IF-49");
        	}

		### If column 4(MAX) "incoming bytes counter" is larger than Critical warning threshold ###
		if ($mrtgLogFileColumn4_MAX_IncomingBytesCounter > $splittedCriticalThresholdIncoming)
		{
			if ($DEBUG)
      	  	{	
				printf("IF-50");
        		}

			### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
      		  	{	
					printf("IF-51");
        			}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
      		  	{	
					printf("IF-52");
        			}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
      		  	{	
					printf("IF-53");
        			}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
      		  	{	
					printf("IF-54");
        			}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}	
		else  ### If column 4(MAX) "incoming bytes counter" is NOT larger than Critical warning threshold ###
		{
			if ($DEBUG)
			{	
				printf("IF-55");
        		}

			### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
      		  	{	
					printf("IF-56");
        			}

printf ("Traffic WARNING: MAX. in exceeds WARNING Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
      		  	{	
					printf("IF-57");
        			}

printf ("Traffic WARNING: MAX. in exceeds WARNING Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
      		  	{	
					printf("IF-58");
        			}

printf ("Traffic WARNING: MAX. in exceeds WARNING Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			}
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
      		  	{	
					printf("IF-59");
        			}

printf ("Traffic WARNING: MAX. in exceeds WARNING Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			}
		}
		
	}
	## If column 5(MAX) "Outgoing bytes counter" IS larger than outgoing warning threshold AND ##
	## If column 4(MAX) "incoming bytes counter" IS NOT larger than incoming warning threshold ##
	elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter > $splittedWarningThresholdOutgoing) && ($mrtgLogFileColumn4_MAX_IncomingBytesCounter < $splittedWarningThresholdIncoming) ) 
	{
		if ($DEBUG)
      	{	
			printf("IF-60");
        	}

		### If column 5(MAX) "Outgoing bytes counter" is larger than Critical warning threshold ###
		if ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter > $splittedCriticalThresholdOutgoing)
		{
			if ($DEBUG)
			{	
				printf("IF-61");
			}

			### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
				{	
					printf("IF-62");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
				{	
					printf("IF-63");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
				{	
					printf("IF-64");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
				{	
					printf("IF-65");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}	
		else  ### If column 5(MAX) "Outgoing bytes counter" is NOT larger than Critical warning threshold ###
		{
			if ($DEBUG)
			{	
				printf("IF-65");
			}

			### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
				{	
					printf("IF-66");
				}

printf ("Traffic WARNING: MAX. out exceeds WARNING Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
				{	
					printf("IF-67");
				}

printf ("Traffic WARNING: MAX. out exceeds WARNING Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
				{	
					printf("IF-68");
				}

printf ("Traffic WARNING: MAX. out exceeds WARNING Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			}
			
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
				{	
					printf("IF-69");
				}

printf ("Traffic WARNING: MAX. out exceeds WARNING Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			}
		}
		
	}
############
### !!!  ###	
############
	### If column 4(MAX) "incoming bytes counter" exceeds incoming warning threshold AND ###
	### column 5(MAX) "Outgoing bytes counter" exceeds outgoing warning threshold	     ###
	elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesCounter > $splittedWarningThresholdIncoming) && ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter > $splittedWarningThresholdOutgoing) )
	{
		if ($DEBUG)
		{	
			printf("IF-70");
		}
	
		### If column 4(MAX) "incoming bytes counter" is exceeding incoming Critical threshold AND ###
		### column 5(MAX) "Outgoing bytes counter" IS NOT exceeding Outgoing Critical threshold	###
		if ( ($mrtgLogFileColumn4_MAX_IncomingBytesCounter > $splittedCriticalThresholdIncoming) && ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter < $splittedCriticalThresholdOutgoing) )
		{
			if ($DEBUG)
			{	
				printf("IF-71");
			}

		 	### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
				{	
					printf("IF-72");
				}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
				{	
					printf("IF-73");
				}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
				{	
					printf("IF-74");
				}

printf ("Traffic CRITICAL: MAX. in exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
				{	
					printf("IF-75");
				}

printf ("Traffic CRITICAL: MAX. in exceeds WARNING Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}
		### If column 4(MAX) "incoming bytes counter" is NOT exceeding incoming warning threshold AND 	###
		### column 5(MAX) "Outgoing bytes counter" IS exceeding Outgoing warning threshold			###
		elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter > $splittedCriticalThresholdOutgoing) && ($mrtgLogFileColumn4_MAX_IncomingBytesCounter < $splittedCriticalThresholdIncoming) ) 
		{
			if ($DEBUG)
			{	
				printf("IF-76");
			}

			### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
				{	
					printf("IF-77");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
				{	
					printf("IF-78");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold in. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
				{	
					printf("IF-79");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'CRITICAL'});
			}
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
				{	
					printf("IF-80");
				}

printf ("Traffic CRITICAL: MAX. out exceeds CRITICAL Threshold out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'CRITICAL'});
			}
		}
### If column 4(MAX) "incoming bytes counter" is exceeding incoming warning threshold AND  ###
                ### column 5(MAX) "Outgoing bytes counter" IS exceeding Outgoing warning threshold         ###
                elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesCounter > $splittedCriticalThresholdOutgoing) && ($mrtgLogFileColumn4_MAX_IncomingBytesCounter > $splittedCriticalThresholdIncoming) )
                {
				if ($DEBUG)
				{	
					printf("IF-81");
				}

                        ### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
                        ### This is for fine tuned presentation only ###
                        if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
                        {
					if ($DEBUG)
					{	
						printf("IF-82");
					}

printf ("Traffic CRITICAL: MAX. in and MAX. out exceeds CRITICAL Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
                                exit($ERRORS{'CRITICAL'});
                        } ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
                        elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) )
                        {
					if ($DEBUG)
					{	
						printf("IF-83");
					}

printf ("Traffic CRITICAL: MAX. in and MAX. out exceeds CRITICAL Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
                                exit($ERRORS{'CRITICAL'});
                        }
                        ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
                        elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
                        {
					if ($DEBUG)
					{	
						printf("IF-84");
					}

printf ("Traffic CRITICAL: MAX. in and MAX. out exceeds CRITICAL Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
                                exit($ERRORS{'CRITICAL'});
                        }
                        else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
                        {
					if ($DEBUG)
					{	
						printf("IF-85");
					}

printf ("Traffic CRITICAL: MAX. in and MAX. out exceeds CRITICAL Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
                                exit($ERRORS{'CRITICAL'});
                        }
                }
		### column 4(MAX) "incoming bytes counter" is NOT exceeding incoming CRITICAL threshold AND 	###
		### column 5(MAX) "Outgoing bytes counter" IS NOT exceeding Outgoing CRITICAL threshold		###
		else  
		{
			if ($DEBUG)
			{	
				printf("IF-86");
			}

			### If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			### This is for fine tuned presentation only ###
			if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        		{
				if ($DEBUG)
				{	
					printf("IF-87");
				}

printf ("Traffic WARNING: MAX. in and MAX. out exceeds WARNING Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			} ### If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
			{
				if ($DEBUG)
				{	
					printf("IF-88");
				}
printf ("Traffic WARNING: MAX. in and MAX. out exceeds WARNING Threshold in and out.  MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			} 
			### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte ###
			elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
			{
				if ($DEBUG)
				{	
					printf("IF-89");
				}
printf ("Traffic WARNING: MAX. in and MAX. out exceeds WARNING Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
				exit($ERRORS{'WARNING'});
			}
			else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
			{
				if ($DEBUG)
				{	
					printf("IF-90");
				}
printf ("Traffic WARNING: MAX. in and MAX. out exceeds WARNING Threshold in and out. MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
				exit($ERRORS{'WARNING'});
			}
		}

	}
############
### !!!  ###	
############
	else	### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are not exeeding warning thresholds ###
	{
		if ($DEBUG)
		{	
			printf("IF-91");
		}
		## If column 4(MAX) "incoming bytes counter" is larger than 1 Mbyte and column5(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte 
		### This is for fine tuned presentation only ###
		if ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  (!$mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
        	{
			if ($DEBUG)
			{	
				printf("IF-92");
			}
print ("Traffic OK: MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
			#exit $ERRORS{'OK'};
			exit($ERRORS{'OK'});		
		} ## If column5(MAX) "outgoing bytes counter" is larger than 1 Mbyte and column4(MAX) "outgoing bytes counter" is NOT larger than 1 Mbyte##
		elsif ( ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) && (!$mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) ) 
		{
			if ($DEBUG)
			{	
				printf("IF-93");
			}
printf ("Traffic OK: MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
			exit($ERRORS{'OK'});
		} ## Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are larger than 1 Mbyte
		elsif ( ($mrtgLogFileColumn4_MAX_IncomingBytesIsLargerThan1Mbyte) &&  ($mrtgLogFileColumn5_MAX_OutgoingBytesIsLargerThan1Mbyte) )
		{
			if ($DEBUG)
			{	
				printf("IF-94");
			}
printf ("Traffic OK: MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToMbyte Mbyte/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToMbyte Mbyte/s.");
			exit($ERRORS{'OK'});
		}
		else ### Both column 4(MAX) "incoming bytes counter" AND column5(MAX) "outgoing bytes counter" are smaller than 1 Mbyte ###
		{
			if ($DEBUG)
			{	
				printf("IF-95");
			}
printf ("Traffic OK: MAX. in = $mrtgLogFileColumn4_MAX_IncomingBytesToKbytes Kbytes/s, MAX. out = $mrtgLogFileColumn5_MAX_OutgoingBytesToKbytes Kbytes/s.");
			exit($ERRORS{'OK'});
		}
	}
}

else
{
	# Default will be FUNCTION AVERAGE.
                
}
sub _getMrtgLogFileValues
{
        ### _getMrtgLogFileValues($MRTG_FILE, $DEBUG) -> $_[0] = $MRTG_FILE

        my $FILEPATH="$_[0]";
        open MRTGFILE, "<$FILEPATH" or die $!;
        my @mrtgFileLineToColumnSplit;
        my @readLine;
        my $getIp;
        my $i = 0;
	my $mrtgLogFileSecondLine;
	my $mrtgLogFileColumn2_AVG_IncomingBytesCounter;
	my $mrtgLogFileColumn3_AVG_OutgoingBytesCounter;
        my $mrtgLogFileColumn4_MAX_IncomingBytesCounter;
        my $mrtgLogFileColumn5_MAX_OutgoingBytesCounter;
	my $numberOfLines = 0;
	my $debug = $_[1];

        while ($readLine[$i] = <MRTGFILE>)
        {
		if ( ($numberOfLines == 1) ) 
		{
                	### First split the second line up into 5 columns based on "space" ###
                	@mrtgFileLineToColumnSplit = split(/ /, $readLine[$i]);
	
			$mrtgLogFileColumn2_AVG_IncomingBytesCounter = ($mrtgFileLineToColumnSplit[1] * 8);
			$mrtgLogFileColumn3_AVG_OutgoingBytesCounter = ($mrtgFileLineToColumnSplit[2] * 8);
			$mrtgLogFileColumn4_MAX_IncomingBytesCounter = ($mrtgFileLineToColumnSplit[3] * 8);
			$mrtgLogFileColumn5_MAX_OutgoingBytesCounter = ($mrtgFileLineToColumnSplit[4] * 8);
			if ($debug)
			{
				 printf("\nreadLine[$i] = $readLine[$i]");
printf ("\nmrtgLogFileColumn2_AVG_IncomingBytesCounter = $mrtgLogFileColumn2_AVG_IncomingBytesCounter");
printf ("\nmrtgLogFileColumn3_AVG_OutgoingBytesCounter = $mrtgLogFileColumn3_AVG_OutgoingBytesCounter");
printf ("\nmrtgLogFileColumn4_MAX_IncomingBytesCounter = $mrtgLogFileColumn4_MAX_IncomingBytesCounter");
printf ("\nmrtgLogFileColumn5_MAX_OutgoingBytesCounter = $mrtgLogFileColumn5_MAX_OutgoingBytesCounter");
			}	
					
		}

                $i++;
		$numberOfLines++;
        }
        close MRTGFILE;
	
        return ($mrtgLogFileColumn2_AVG_IncomingBytesCounter, $mrtgLogFileColumn3_AVG_OutgoingBytesCounter, $mrtgLogFileColumn4_MAX_IncomingBytesCounter, $mrtgLogFileColumn5_MAX_OutgoingBytesCounter);
}

sub _usage
{
print << "USAGE"; 
\n$SCRIPT $VERSION
Usage: $SCRIPT -|--f|F|FUN|function|FUNCTION <AVG|MAX> -|--l|L|log|LOG|logfile|LOGFILE <path to MRTG log file>        
                        -|--w|W|warn|WARN|warning|WARNING Warning threshold in bytes <incoming>,<outgoing>
                        -|--c|C|crit|CRIT|critical|CRITICAL critical threshold in bytes <incoming>,<outgoing>
			-|--u|un|UNIT <kb|mb|gb|tb> unit for <incoming>,<outgoing> thresholds 
                        -|--v|V|VERSION |version -|--he|HE|help|HELP -|--d|D|DEBUG|debug [debug]

			./$SCRIPT -F MAX -L /scripts/test.log -w 9,9 -c 9999999999,999999999
			./$SCRIPT -FUNC MAX -LOG /scripts/test.log -WARN 1048576,2097152 -CRIT 2097152,3145728
			./$SCRIPT -function MAX -logfile /scripts/test.log -warning 1048576 -critical 2097152 --debug
			./$SCRIPT -F AVG -L /scripts/test.log -w 9,9 -c 9999999999,999999999
                        ./$SCRIPT -FUNCT AVG -LOG /scripts/test.log -WARN 1048576,2097152 -CRIT 2097152,3145728
			./$SCRIPT -function AVG -logfile /scripts/test.log -warning 1048576 -critical 2097152 --debug 
			./$SCRIPT -FUNCT AVG -LOG /scripts/test.log -WARN 100,100 -CRIT 200,2000 -u kilobytes
			./$SCRIPT -FUNCT AVG -LOG /scripts/test.log -WARN 100,100 -CRIT 200,2000 -u megabytes
			./$SCRIPT -FUNCT AVG -LOG /scripts/test.log -WARN 100,100 -CRIT 200,2000 -u gigabytes
			./$SCRIPT -FUNCT AVG -LOG /scripts/test.log -WARN 100,100 -CRIT 200,2000 -u terabytes
                        ./$SCRIPT --help
                        ./$SCRIPT --version

-|--f|F|FUN|FUNCTION|function   Can be either AVG or MAX. where AVG = "The average incoming transfer rate in bytes per second"
                                AND MAX = "The maximum incoming transfer rate in bytes per second since last MRTG poll"
                                (DEFAULT AVG)

-|--w|W|warn|WARN|warning|WARNING       This will tell Nagios when to send a WARNING message.
					WARNING Threshold expects bytes input as default(unless you use the -u flag) and needs to be supplied as 
					a "warning threshold pair" <incoming>,<outgoing>. 
					If there is only one value passed in it will use that value in both pairs.
                                        (NO DEFAULT)

-|--c|C|crit|CRIT|critical|CRITICAL     This will tell Nagios when to send a CRITICAL message.
					CRITICAL Threshold expects bytes input as default(unless you use the -u flag) and needs to be supplied as 
					a "critical threshold pair" <incoming>,<outgoing>.
					If there is only one value passed in it will use that value in both pairs.
                                        (NO DEFAULT)

-|--|u|un|UNIT                  If you don't want to pass in WARNING and CRITICAL threshold pairs using default "bytes input" then use this flag to    
                                change it to suit your need. This script understands Kilobytes, Megabytes, Gigabytes and Terabytes.
                                Input is regexped so can be anything from <k|kilobytes> or <m|megabytes> or <g|gigabytes> or <t|terabytes>. 
				If this flag is not used THEN scripts expects input for WARNING and CRITICAL thresholds to be in bytes.

-d|D|DEBUG|debug        : Enable debugging (DEFAULT disabled)

-|--he|HE|help|HELP     Prints this help screen

-|--v|V|VERSION|version Prints program version

			INFO: WARNING THRESHOLDS must be exceeded before any checks are done on CRITICAL THRESHOLDS!
			Also only use the debug flag from the CLI Nagios will be very confused by it.
			If you find any BUGs or have a suggestion on a feature or improvments then please drop a line to cocoon.is\@gmail.com
			
			IMPORTANT!! For this scripts to work with Nagios! This script needs to be able to find nagios supplied utils.pm file.
			Edit this file at the top of the file change "use lib qw( /usr/local/nagios/libexec );" to point to where you Nagios
			installation installed utils.pm.	
			IF you get errors looking like
			"Global symbol "%ERRORS" requires explicit package name" Then it is a sure sign that your path to utils.pm is wrong.
 
USAGE
   exit 1;
}
