#!/usr/bin/perl -w
####################################################
#
# Perl source file for project authority 
#
# Reports process success rates of the authority load.
#    Copyright (C) 2014  Andrew Nisbet
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
# Created: Mon May 16 12:46:04 MDT 2016
# Rev: 
#          0.0 - Dev. 
#
####################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

#
# authbot.sh is the driver program that loads authorities and BIB records from BSLW. 
# This application is a very specific application that reads the reports produced by
# authbot.sh and associated scripts and reports their success.
# 
# Staff have requested that this script report all the marc files that were loaded,
# number of records inside each of the MARC files, and finally the total that were
# successfully loaded.
#

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
$ENV{'PATH'}  = qq{:/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/usr/bin:/usr/sbin};
$ENV{'UPATH'} = qq{/s/sirsi/Unicorn/Config/upath};
###############################################
my $VERSION            = qq{0.0};
my $TEMP_DIR           = `getpathname tmp`;
chomp $TEMP_DIR;
my $TIME               = `date +%H%M%S`;
chomp $TIME;
my $DATE               = `date +%m/%d/%Y`;
chomp $DATE;
my @CLEAN_UP_FILE_LIST = (); # List of file names that will be deleted at the end of the script if ! '-t'.
my $BINCUSTOM          = `getpathname bincustom`;
chomp $BINCUSTOM;
my $PIPE               = "$BINCUSTOM/pipe.pl";
### Specific files to look for in the authority directory after authbot has run.
my $AUTHBOT_LOG        = "authbot.log";

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [options]
 Reports on the success of processes related to running authbot.sh. 
 This script parses and queries log results of other processes.
 
 -x: This (help) message.

examples : 
 $0 -x

Version: $VERSION
EOF
    exit;
}

# Removes all the temp files created during running of the script.
# param:  List of all the file names to clean up.
# return: <none>
sub clean_up
{
	foreach my $file ( @CLEAN_UP_FILE_LIST )
	{
		if ( $opt{'t'} )
		{
			printf STDERR "preserving file '%s' for review.\n", $file;
		}
		else
		{
			if ( -e $file )
			{
				unlink $file;
			}
			else
			{
				printf STDERR "** Warning: file '%s' not found.\n", $file;
			}
		}
	}
}

# Writes data to a temp file and returns the name of the file with path.
# param:  unique name of temp file, like master_list, or 'hold_keys'.
# param:  data to write to file.
# return: name of the file that contains the list.
sub create_tmp_file( $$ )
{
	my $name    = shift;
	my $results = shift;
	my $sequence= sprintf "%02d", scalar @CLEAN_UP_FILE_LIST;
	my $master_file = "$TEMP_DIR/$name.$sequence.$TIME";
	# Return just the file name if there are no results to report.
	return $master_file if ( ! $results );
	open FH, ">$master_file" or die "*** error opening '$master_file', $!\n";
	print FH $results;
	close FH;
	# Add it to the list of files to clean if required at the end.
	push @CLEAN_UP_FILE_LIST, $master_file;
	return $master_file;
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
}

init();


### code starts
# First order of business, parse the authbot log, if there isn't one then the authbot may not have run or
# the operator may have removed the files with the Makefile or command line 'rm'.
if ( not -s $AUTHBOT_LOG )
{
	printf STDERR "can't find authbot.sh log '$AUTHBOT_LOG'. It may have been cleaned up, or the script may not have run.\n";
	exit;
}
# parse the file for key information about what ran. Because processes clean up after themselves and some zip files contain 
# duplicate names as other zip files, we will rely on this log file for key data.

### code ends


if ( $opt{'t'} )
{
	printf STDERR "Temp files will not be deleted. Please clean up '%s' when done.\n", $TEMP_DIR;
}
else
{
	clean_up();
}
# EOF
