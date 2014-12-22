#!/s/sirsi/Unicorn/Bin/perl -w
####################################################
#
# Perl source file for project authority 
# Purpose:
# Method:
#
# Compares a update authority file against existing authorities.
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
# Created: Mon Dec 22 10:07:38 MST 2014
# Rev: 
#          0.0 - Dev. 
#
####################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
$ENV{'PATH'}  = qq{:/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/usr/bin:/usr/sbin};
$ENV{'UPATH'} = qq{/s/sirsi/Unicorn/Config/upath};
###############################################
my $UPDATE     = ""; # The authority file to report on. 
my $VERSION    = qq{0.0};

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: cat <file.flat> \| $0 [options]
authority.pl reports on the potential match points for authority updates.

 -x: This (help) message.

example: $0 -a"current.flat" -i"update.flat"
Version: $VERSION
EOF
    exit;
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

# Updates counts on marc record.
# param:  hash reference of statistics.
# param:  MARC Record lines as list.
# return: none.
sub computeScore
{
	my $stats = shift;
	foreach my $line (@_)
	{
		if ( $line =~ m/\.001\./ )
		{
			$stats->{'001'}++;
		}
		elsif ( $line =~ m/\.016\./ )
		{
			$stats->{'016'}++;
		}	
	}
}

init();
my @marcRecord = ();
my $stats = {};
while(<>)
{
	# Marks the start of a new MARC boundary
	if (m/\*\*\* DOCUMENT BOUNDARY \*\*\*/) 
	{
		$stats->{'count'}++;
		computeScore( $stats, @marcRecord ) if ( scalar( @marcRecord ) > 0 );
		@marcRecord = ();
	}
	push @marcRecord, $_;
}
print "Analysis:\n";
while( my ($k, $v) = each %$stats ) 
{
	format STDOUT =
@<<<<<<<  @>>>>>>
$k,$v
.
	write;
}
# EOF
