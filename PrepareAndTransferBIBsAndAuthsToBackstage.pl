#!/s/sirsi/Unicorn/Bin/perl -w
######################################################################################################################################
#
# Perl source file for project gh 
#
# Prepares authority files for Backstage Library Works (BSLW).
#    Copyright (C) 2020  Andrew Nisbet
#
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Created: Thu Jul 14 10:34:28 MDT 2016
# Rev: 
#          0.2 - Add dry run feature to speed up check files. 
#          0.1 - Bug in clean doesn't output entire line. FIXED. 
#          0.0 - Dev. 
#
##--------------------------------------------------------------------------
##Script filename.......: PrepareAndTransferBIBsAndAuthsToBackstage.pl
##Script description....: This script prepares and FTPs (sends) BIB and Authority MARC files to the Backstage Library Works FTP site.
##Script description....: Chris Stoddart - ILS Administrator
##Script created for....: Edmonton Public Library
##Script creation date..: 2014/02/01
##Script updated by.....: Chris Stoddart
##Script update date....: 2016/07/07
#####################################################################################################################################
use strict;
use Net::FTP;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;
##--------------------------------------------------------------------------
##set environment variables
##--------------------------------------------------------------------------
$ENV{'PATH'}  = qq{:/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/usr/bin:/usr/sbin};
$ENV{'UPATH'} = qq{/s/sirsi/Unicorn/Config/upath};
##--------------------------------------------------------------------------
my $VERSION            = qq{0.2};
chomp( my $BINCUSTOM   = `getpathname bincustom` );
my $PIPE               = "$BINCUSTOM/pipe.pl";
my $scriptrundate      = `date +"%Y%m%d"`;
$scriptrundate         =~ s/^\s+//;
$scriptrundate         =~ s/\s+$//;
my $formattedrundate   = `date +"%Y/%m/%d"`;
$formattedrundate      =~ s/^\s+//;
$formattedrundate      =~ s/\s+$//;
my $timetoday          = `date +%H:%M:%S`;
$timetoday             =~ s/^\s+//;
$timetoday             =~ s/\s+$//;
my $datetimestamptoday = `date +%Y%m%d%H%M%S`;
$datetimestamptoday    =~ s/^\s+//;
$datetimestamptoday    =~ s/\s+$//;
##my $DateCreatedStart = system "transdate -m-0"; #returns first day of current month
##my $DateCreatedStart = system "transdate -m-1"; #returns first day of prior month
##my $DateCreatedStart = system "transdate -o`date +"%Y%m%d"`-1";  #returns exactly one month from today's date
##my $DateCreatedEnd = system "transdate -d-0"; #returns today's date
##my $DateBIBCreatedStart = "20140410";
##my $DateBIBCreatedEnd = "20140916";
##my $DateBIBModifiedStart = "20140410";
##my $DateBIBModifiedEnd = "20141106";
##--------------------------------------------------------------------------
##Calculate start date for data criteria:
my $OneMonthAgoOfScriptRunDate = `transdate -o"$scriptrundate"-1`;
my $YearOneMonthAgo = substr($OneMonthAgoOfScriptRunDate,0,4);  #returns 4 digit year with century exactly one month from today's date
my $MonthOneMonthAgo = substr($OneMonthAgoOfScriptRunDate,4,2);  #returns 2 digit month exactly one month from today's date
my $DayOneMonthAgo = '20'; #use the 20th day of the month for start date of extraction of data
my $DateStart = $YearOneMonthAgo . $MonthOneMonthAgo . $DayOneMonthAgo;  #ANSI Date format Start Date for data criteria
##--------------------------------------------------------------------------
##Calculate end date for data criteria:
my $YearOneDayAgo = substr($scriptrundate,0,4);  #returns 4 digit year with century exactly one day from today's date
my $MonthOneDayAgo = substr($scriptrundate,4,2);  #returns 2 digit month exactly one day from today's date
my $DayOneDayAgo = '21'; #use the 20th day of the month for end date of extraction of data
my $DateEnd = $YearOneDayAgo . $MonthOneDayAgo . $DayOneDayAgo;  #ANSI Date format End Date for data criteria
##--------------------------------------------------------------------------
##PLEASE NOTE: CHANGE THE DATES FOR THE VARIABLES BELOW FOR EACH MONTHS RUN OF THIS SCRIPT:
##--------------------------------------------------------------------------
my $DateBIBCatalogedStart = "";
my $DateBIBCatalogedEnd   = "";
my $DateAuthCreatedStart  = "";
my $DateAuthCreatedEnd    = "";
my $DateAuthModifiedStart = "";
my $DateAuthModifiedEnd   = "";
##--------------------------------------------------------------------------
my $host = 'ftp.bslw.com';
##Note that the remote upload path is 'in' and 'out' seems to be the download path
my $login = 'tcnedm1';
my $passwd = 'tcnedm1';
my $emailrecipients = "ilsadmins\@epl.ca";
my $logfileemailsubject = "Prepare And Transfer BIB and Authority Files to BSLW FTP Site (Process Log) for Date: $formattedrundate";
my $scriptdatadirectory = qq{/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesForBackStage/${scriptrundate}};
my $ftp = '';
my $file = '';
my @files = ();
my $logfilename = "PrepareAndTransferBIBsAndAuthsToBackstage.log";
my $logfilepathandname = $scriptdatadirectory . '/' . $logfilename;
##-----------------------------------------------------------
#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [-d{YYYYMMDD,YYYYMMDD}Dfx]
Prepares authority extracts for Backstage Library Works (BSLW).

 -d: (REQUIRED) Date range selection. Range specified with start and end dates in ANSI format (YYYMMDD), and are comma ',' separated.
 -D: Dry run mode. Do everything but don't zip up the MARC files and email them to ILSadmins\@epl.ca.
 -f: FTP files to BSLW.
 -x: This (help) message.

example:
  $0 -x
Usually you can do
  ./PrepareAndTransferBIBsAndAuthsToBackstage.pl -d20160619,20160719
  ./PrepareAndTransferBIBsAndAuthsToBackstage.pl -d20200123,20200225 -D
Or if you prefer to automatically send the files to BSLW then use the command below.
  ./PrepareAndTransferBIBsAndAuthsToBackstage.pl -f -d20160619,20160719
Version: $VERSION
EOF
    exit;
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'd:Dfx';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	if ( $opt{'d'} )
	{
		my @dates = split ',', $opt{'d'};
		if ( !$dates[0] or ! $dates[1] )
		{
			printf STDERR "** error invalid start and end date supplied '%s'. See usage -x for more information.\n", $opt{'d'};
			exit 0;
		}
		my $start = `echo "$dates[0]" | "$PIPE" -tc0`;
		if ( $start )
		{
			if ( $start =~ m/^\d{8}$/ )
			{
				chomp $start;
			}
			else
			{
				printf STDERR "** error invalid start date supplied '%s'. See usage -x for more information.\n", $dates[0];
				exit 0;
			}
		}
		my $end = `echo "$dates[1]" | "$PIPE" -tc0`;
		if ( $start )
		{
			if ( $end =~ m/^\d{8}$/ )
			{
				chomp $end;
			}
			else
			{
				printf STDERR "** error invalid end date supplied '%s'. See usage -x for more information.\n", $dates[1];
				exit 0;
			}
		}
		$DateBIBCatalogedStart = $start;
		$DateBIBCatalogedEnd = $end;
		$DateAuthCreatedStart = $start;
		$DateAuthCreatedEnd = $end;
		$DateAuthModifiedStart = $start;
		$DateAuthModifiedEnd = $end;
	}
	else
	{
		printf STDERR "** error you must supply a date range for this script to run. See -x for help.\n";
		exit 0;
	}
}

init();

if (! -d ${scriptdatadirectory}) {
  system "mkdir -p ${scriptdatadirectory}";
  }
chdir "$scriptdatadirectory";
##--------------------------------------------------------------------------
open LOGFILE,">>$logfilepathandname" or die "Open failed: $!\n";
print LOGFILE "Program Start: Prepare And Transfer BIBs And Auths To Backstage...\n";
print LOGFILE "Program Processing Date/Time: $formattedrundate $timetoday\n";
##--------------------------------------------------------------------------
print LOGFILE "Program Log File Path and Filename: ${logfilepathandname}\n";
print LOGFILE "Current Local Directory: ${scriptdatadirectory}\n";
##--------------------------------------------------------------------------
print LOGFILE '---- Start Script Variables ----' . "\n";
print LOGFILE '$scriptrundate: ' . $scriptrundate . "\n";
print LOGFILE '$OneMonthAgoOfScriptRunDate: ' . $OneMonthAgoOfScriptRunDate . "\n";
print LOGFILE '$YearOneMonthAgo: ' . $YearOneMonthAgo . "\n";
print LOGFILE '$MonthOneMonthAgo: ' . $MonthOneMonthAgo . "\n";
print LOGFILE '$DayOneMonthAgo: ' . $DayOneMonthAgo . "\n";
print LOGFILE '$DateStart: ' . $DateStart . "\n";
print LOGFILE '$YearOneDayAgo: ' . $YearOneDayAgo . "\n";
print LOGFILE '$MonthOneDayAgo: ' . $MonthOneDayAgo . "\n";
print LOGFILE '$DayOneDayAgo: ' . $DayOneDayAgo . "\n";
print LOGFILE '$DateEnd: ' . $DateEnd . "\n";
print LOGFILE '---- Below are the dates used for this upload: ----' . "\n";
print LOGFILE '$DateBIBCatalogedStart: ' . $DateBIBCatalogedStart . "\n";
print LOGFILE '$DateBIBCatalogedEnd: ' . $DateBIBCatalogedEnd . "\n";
print LOGFILE '$DateAuthCreatedStart: ' . $DateAuthCreatedStart . "\n";
print LOGFILE '$DateAuthCreatedEnd: ' . $DateAuthCreatedEnd . "\n";
print LOGFILE '$DateAuthModifiedStart: ' . $DateAuthModifiedStart . "\n";
print LOGFILE '$DateAuthModifiedEnd: ' . $DateAuthModifiedEnd . "\n";
print LOGFILE '---- End Script Variables ----' . "\n";
##--------------------------------------------------------------------------
print LOGFILE "Get BIB records...\n";
##--------------------------------------------------------------------------
##prepare BIB file and exclude records containing "ON ORDER" in 092 or 099 tags
##the command lines below are intended to retrieve catalog keys for the criteria AND for only newly created and modified title records:
##`selcatalog -p">$DateBIBCreatedStart<$DateBIBCreatedEnd" -oC > ${scriptrundate}_CatalogKeys_DateCreatedModifiedRecords.lst 2>> ${logfilepathandname}`;
`selcatalog -q">$DateBIBCatalogedStart<$DateBIBCatalogedEnd" -oC > ${scriptrundate}_CatalogKeys_DateCreatedModifiedRecords.lst 2>> ${logfilepathandname}`;
##`selcatalog -r">$DateBIBModifiedStart<$DateBIBModifiedEnd" -oC >> ${scriptrundate}_CatalogKeys_DateCreatedModifiedRecords.lst 2>>${logfilepathandname}`;
`cat ${scriptrundate}_CatalogKeys_DateCreatedModifiedRecords.lst | sort | uniq > ${scriptrundate}_CatalogKeys_DateCreatedModifiedRecords_Sort_Uniq.lst`;
##--------------------------------------------------------------------------
##the system command line below is intended to retrieve catalog keys for the criteria minus any date criteria:
`cat ${scriptrundate}_CatalogKeys_DateCreatedModifiedRecords_Sort_Uniq.lst | selcatalog -iC -e'092,099' -oCe 2>>${logfilepathandname} | grep -v 'ON ORDER' > ${scriptrundate}_Catalog_NoONORDER.lst 2>>${logfilepathandname}`;
##--------------------------------------------------------------------------
print LOGFILE "Record Count of BIB records without ON ORDER text in Tag 092 or 099...\n";
`cat ${scriptrundate}_Catalog_NoONORDER.lst | wc -l >> ${logfilepathandname}`;
`cat ${scriptrundate}_Catalog_NoONORDER.lst | cut -d'|' -f1 > ${scriptrundate}_NoONORDER_catkeys.lst`;
##--------------------------------------------------------------------------
##exclude records containing "ILL" or "NOF" in 245 tags - selection is separate from the above catalog selection - both results are cat'd together and then sorted and uniq'd
`cat ${scriptrundate}_NoONORDER_catkeys.lst | selcatalog -iC -e'245' -oeC > ${scriptrundate}_Catalog_Tag245.lst 2>>${logfilepathandname}`;
##--------------------------------------------------------------------------
`cat ${scriptrundate}_Catalog_Tag245.lst | egrep -v -e '(ILL|NOF)' > ${scriptrundate}_Catalog_NoILL_NoNOF.lst 2>>${logfilepathandname}`;
##--------------------------------------------------------------------------
print LOGFILE "Record Count of BIB records without ILL or NOF text in Tag 245...\n";
`cat ${scriptrundate}_Catalog_NoILL_NoNOF.lst | wc -l >> ${logfilepathandname}`;
`cat ${scriptrundate}_Catalog_NoILL_NoNOF.lst | cut -d'|' -f2 > ${scriptrundate}_NoILL_NoNOF_catkeys.lst`;
##--------------------------------------------------------------------------
##concatenate catalog keys for no ON ORDER, no ILL and no NOF records - sort and Unique catalog keys in order to prepare for catalogdump API command
`cat ${scriptrundate}_NoILL_NoNOF_catkeys.lst | sort | uniq > ${scriptrundate}_ReadyForCatalogdump_catkeys.lst 2>>${logfilepathandname}`;
print LOGFILE "Record Count of BIB records without ON ORDER, ILL or NOF text AFTER sort and uniq...\n";
`cat ${scriptrundate}_ReadyForCatalogdump_catkeys.lst | wc -l >> ${logfilepathandname}`;
##--------------------------------------------------------------------------
##create Bibliographic Records MARC file for output to be sent to BackStage for processing
print LOGFILE "Sending catalog keys to the catalogdump API command to prepare the BIB MARC file for BackStage...\n";
##`cat ${scriptrundate}_ReadyForCatalogdump_catkeys.lst | catalogdump -kf035 -om > ${scriptrundate}_EPL_Catalog_Records.mrc 2>>${logfilepathandname}`;
##This next line is modified to output the UTF-8 characters, as discussed at COSUGI 2015.
##`cat ${scriptrundate}_ReadyForCatalogdump_catkeys.lst | catalogdump -kf035 -om > ${scriptrundate}_EPL_Catalog_Records.mrc 2>>${logfilepathandname}`;
`cat ${scriptrundate}_ReadyForCatalogdump_catkeys.lst | catalogdump -kf035 -om 2>>${logfilepathandname} | convMarc -tu > ${scriptrundate}_EPL_Catalog_Records.mrc 2>>${logfilepathandname}`;
##--------------------------------------------------------------------------
##create marcanalyze and flat files:
`cat ${scriptrundate}_EPL_Catalog_Records.mrc | marcanalyze -lt > ${scriptrundate}_EPL_Catalog_Records_marcanalyze.txt 2>>${logfilepathandname}`;
`cat ${scriptrundate}_EPL_Catalog_Records.mrc | flatskip -im -aLCSH -of 2>>${logfilepathandname} | nowrap.pl > ${scriptrundate}_EPL_Catalog_Records.flat 2>>${logfilepathandname}`;
##--------------------------------------------------------------------------
if ( $opt{'D'} )
{
    `cp ${scriptrundate}_EPL_Catalog_Records.mrc catalog_records.mrc`;
}
##compress Catalog MARC file for upload to Backstage
print LOGFILE "Compressing the BIB MARC file for transfer to the BackStage FTP site...\n";
`gzip -f ${scriptrundate}_EPL_Catalog_Records.mrc > ${scriptrundate}_EPL_Catalog_Records.mrc.gz 2>>${logfilepathandname}`;
print LOGFILE `gzip -l ${scriptrundate}_EPL_Catalog_Records.mrc.gz`; 
##--------------------------------------------------------------------------
##prepare Authority file and include the Authority ID in a 035 Tag:
print LOGFILE "Sending authority keys to the authdump API command to prepare the Authorities MARC file for BackStage...\n";
`selauthority -c">$DateAuthCreatedStart<$DateAuthCreatedEnd" -oK > ${scriptrundate}_EPL_Authority_Records_created.lst 2>>${logfilepathandname}`;
`selauthority -m">$DateAuthModifiedStart<$DateAuthModifiedEnd" -oK > ${scriptrundate}_EPL_Authority_Records_modified.lst 2>>${logfilepathandname}`; 
##concatenate both created and modified keys - then sort and uniq keys for final keys list:
`cat ${scriptrundate}_EPL_Authority_Records_created.lst ${scriptrundate}_EPL_Authority_Records_modified.lst > ${scriptrundate}_EPL_Authority_Records_NotUniq.lst`;
`cat ${scriptrundate}_EPL_Authority_Records_NotUniq.lst | sort | uniq > ${scriptrundate}_EPL_Authority_Records.lst`;
##--------------------------------------------------------------------------
##create Authority Records MARC file for output to be sent to BackStage for processing
##`cat ${scriptrundate}_EPL_Authority_Records.lst | authdump -ki035 2>>${logfilepathandname} | flatskip -a'LCSH' -if -om > ${scriptrundate}_EPL_Authority_Records.mrc 2>>$logfilepathandname`;
##`cat ${scriptrundate}_EPL_Authority_Records.lst | authdump -ki001 2>>${logfilepathandname} | flatskip -a'LCSH' -if -om > ${scriptrundate}_EPL_Authority_Records.mrc 2>>$logfilepathandname`;
##`cat ${scriptrundate}_EPL_Authority_Records.lst | authdump -ki001 2>>${logfilepathandname} | convMarc -tu 2>>${logfilepathandname} | flatskip -a'LCSH' -if -om > ${scriptrundate}_EPL_Authority_Records.mrc 2>>$logfilepathandname`;
#`cat ${scriptrundate}_EPL_Authority_Records.lst | authdump -ki001 2>>${logfilepathandname} | convMarc -tu > ${scriptrundate}_EPL_Authority_Records.mrc 2>>$logfilepathandname`;
`cat ${scriptrundate}_EPL_Authority_Records.lst | authdump -ki001 2>>${logfilepathandname} | flatskip -a'LCSH' -if -om > ${scriptrundate}_EPL_Authority_Records.mrc 2>>$logfilepathandname`;
##--------------------------------------------------------------------------
##create marcanalyze and flat files:
`cat ${scriptrundate}_EPL_Authority_Records.mrc | marcanalyze -lt > ${scriptrundate}_EPL_Authority_Records_marcanalyze.txt 2>>${logfilepathandname}` ;
`cat ${scriptrundate}_EPL_Authority_Records.mrc | flatskip -im -aLCSH -of 2>>${logfilepathandname} | nowrap.pl > ${scriptrundate}_EPL_Authority_Records.flat 2>>${logfilepathandname}`;
##--------------------------------------------------------------------------
if ( $opt{'D'} )
{
    # make a copy of the authority marc file and send as results for dry run.
    `cp ${scriptrundate}_EPL_Authority_Records.mrc authority_records.mrc`;
    `echo -e "Please find MARC files for authorities dated: $DateAuthCreatedStart to $DateAuthCreatedEnd\nSigned: PrepareAndTransferBIBsAndAuthsToBackstage.pl\n" | mailx -s"Authority files for BSLW $DateAuthCreatedStart to $DateAuthCreatedEnd" -a authority_records.mrc -a catalog_records.mrc andrew.nisbet\@epl.ca`;
}
##compress Authority MARC file for upload to Backstage
print LOGFILE "Compressing the Authority MARC file for transfer to the BackStage FTP site...\n";
`gzip -f ${scriptrundate}_EPL_Authority_Records.mrc > ${scriptrundate}_EPL_Authority_Records.mrc.gz 2>>${logfilepathandname}`;
print LOGFILE `gzip -l ${scriptrundate}_EPL_Authority_Records.mrc.gz`; 
##--------------------------------------------------------------------------
##if the send file was created, then proceed to FTP files:
if ( $opt{'f'} )
{
	$datetimestamptoday = `date +%Y%m%d%H%M%S`;
	print LOGFILE "Attempting to FTP the files to the Backstage FTP site...\n";
	print LOGFILE "$datetimestamptoday - Transfer BIBs and Auths to BackStage Library Works...\n";
	#if ($ftp = Net::FTP->new($host, Debug => 3)) {
	if ($ftp = Net::FTP->new($host)) 
	{
		if ($ftp->login("$login","$passwd")) 
		{
			$ftp->pasv();
			$ftp->binary();
			$ftp->cwd("/in") or die "Cannot change working remote FTP directory ", $ftp->message;
			print LOGFILE "$datetimestamptoday - Current Remote FTP Directory: $ftp->pwd()\n";
			print LOGFILE "$datetimestamptoday - FTPLogin: $login  FileXferMode: passive binary\n";
			#@files = <${scriptdatadirectory}/*.mrc>;
			@files = <${scriptdatadirectory}/*.mrc.gz>;
			foreach $file (@files) 
			{
				print LOGFILE "$datetimestamptoday - FTP PUT File: $file...\n";
				if ($ftp->put("$file")) 
				{
					print LOGFILE "$datetimestamptoday - FTP PUT File status=DONE\n";
				}
				else 
				{
					print LOGFILE "$datetimestamptoday - FTP PUT File status=ERROR\n";
					print LOGFILE "$datetimestamptoday - $ftp->message\n";
				}
			}
			$ftp->quit;
		}
		else 
		{
			print LOGFILE "$datetimestamptoday - ERROR: unable to LOGIN to FTP server\n";
		}
	}
	else 
	{
		print LOGFILE "$datetimestamptoday - ERROR: unable to CONNECT to FTP server\n";
	}
}
##--------------------------------------------------------------------------
$formattedrundate = `date +"%Y/%m/%d"`;
$formattedrundate =~ s/^\s+//;
$formattedrundate =~ s/\s+$//;
$timetoday = `date +%H:%M:%S`;
$timetoday =~ s/^\s+//;
$timetoday =~ s/\s+$//;
##--------------------------------------------------------------------------
print LOGFILE "Program Finish: Prepare And Transfer BIBs And Auths To Backstage...\n";
print LOGFILE "Program Processing Finish Date/Time: $formattedrundate $timetoday\n";
print LOGFILE "Script execution complete!\n";
close LOGFILE;
##--------------------------------------------------------------------------
##check if file exists and has a non-zero filesize
if (-s $logfilepathandname) 
{
	`cat $logfilepathandname | mailx -s \"$logfileemailsubject\" \"$emailrecipients\"`;
}
##--------------------------------------------------------------------------
