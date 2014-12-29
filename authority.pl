#!/usr/bin/perl -w
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
#          0.4 - Added missing check for -t file. 
#          0.3 - Changed -f flag to -o for consistency. 
#          0.2 - Update comments and add flat file cleaning. 
#          0.1 - Done testing. 
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
my $PRE_LOAD   = {}; # The authority file to report on. 
my $VERSION    = qq{0.4};

my $stats = {};

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: cat <file.flat> \| $0 [options]
authority.pl reports on the potential match points for authority updates.

 -c      : Compress.
 -o      : Write output to standard out. Only works on data from standard in.
 -p<file>: Pre-load an authority file to test how closely the input matches.
 -t<file>: Test results if pre-load is taken from 'selauthority -oK \| authdump -ki035'.
           The input file looks like '518203|XX518203        |', 
           authority key and authority ID separated by pipes.
 -x      : This (help) message.

examples : 
 cat update.flat | $0 -p"current.flat"
 cat update.flat | $0 -tAllAuthKeysAndIDs.lst
 cat update.flat | $0 -o \> fixed_authorities.flat
Version: $VERSION
EOF
    exit;
}

# Compression refers to removing white space and normalizing all
# alphabetic characters into upper case.
# param:  any string.
# return: input string with spaces removed and in upper case.
sub compress( $ )
{
	my $line = shift;
	$line =~ s/\s+//g;
	$line = uc $line;
	return $line;
}

# Returns the subfield of a given tag.
# param:  MARC tag.
# return: value stored in tag.
sub getAuthIDField( $ )
{
	my $line   = shift;
	my @record = split( '\|a', $line );
	if ( defined $record[1] )
	{
		my $line = trim( $record[1] );
		$line = compress( $line ) if ( $opt{'c'} );
		return $line;
	}
	return "";
}

# Goes through the flat record and parses out the authid.
# param:  array of MARC tags.
# return: <none>
sub getAuthId
{
	my $authId = "";
	my $tag    = "";
	my $t001   = "";
	my $t016   = "";
	foreach ( @_ )
	{
		# If we assume the authority id is in one of the following: 001, 016.
		chomp;
		if ( m/\.001\./ )
		{
			$t001 = getAuthIDField( $_ );
			# print STDERR "001='$t001' ";
			$authId = $t001;
			$tag = "001" if ( $t001 ne "" );
		}
		elsif ( m/\.016\./ )
		{
			$t016 = getAuthIDField( $_ );
		} 
	}
	if ( $t001 ne "" && $t016 ne "" && $t001 ne $t016 )
	{
		print STDERR "*warning: ambiguous authority id, 001='$t001', 016='$t016'\n";
		$stats->{'ambiguous ID'}++;
	}
	return ( $authId, $tag );
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'cop:t:x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	if ( $opt{'p'} )
	{
		# Initialize the counter for matches. If anything fails we still get valid '0'.
		$stats->{'match'} = 0;
		my $pre_auth = $opt{'p'};
		if ( -s $pre_auth )
		{
			my @marcRecord = ();
			open AUTH_FILE, "<$pre_auth" or die "**error opening '$pre_auth', $!\n";
			while (<AUTH_FILE>)
			{
				if (m/\*\*\* DOCUMENT BOUNDARY \*\*\*/) 
				{
					$stats->{'pre-auth count'}++;
					if ( scalar( @marcRecord ) > 0 )
					{
						my ( $authId, $tag ) = getAuthId( @marcRecord );
						if ( $authId eq "" )
						{
							$stats->{'pa_no_auth_id'}++;
						}
						else
						{
							$PRE_LOAD->{$authId} = $tag;
						}
					}
					@marcRecord = ();
				}
				push @marcRecord, $_;
			}
			close AUTH_FILE;
			# The last iteration of the while loop doesn't handle the last FLAT record, so do it here.
			if ( scalar( @marcRecord ) > 0 )
			{
				my ( $authId, $tag ) = getAuthId( @marcRecord );
				if ( $authId eq "" )
				{
					$stats->{'pa_no_auth_id'}++;
				}
				else
				{
					$PRE_LOAD->{$authId} = $tag;
				}
			}
		}
		else
		{
			print STDERR "**error: -p selected, but file is missing or empty.\n";
			usage();
		}
	} # End -p
	elsif ( $opt{'t'} ) # use '-p', or '-t'.
	{
		# Initialize the counter for matches. If anything fails we still get valid '0'.
		$stats->{'match'} = 0;
		my $pre_auth = $opt{'t'};
		if ( -s $pre_auth )
		{
			open AUTH_FILE, "<$pre_auth" or die "**error opening '$pre_auth', $!\n";
			while (<AUTH_FILE>)
			{
				my @record = split( '\|', $_ );
				# The key will be in the second field.
				if ( defined $record[1] )
				{
					$stats->{'pre-auth count'}++;
					my $authId = trim( $record[1] );
					# print STDERR "'$authId'\n";
					$PRE_LOAD->{ $authId } = $record[0];
				}
			}
			close AUTH_FILE;
		}
		else
		{
			print STDERR "**error: -t selected, but file is missing or empty.\n";
			usage();
		}
	}
}

# Trim function to remove whitespace from the start and end of the string.
# param:  string to trim.
# return: string without leading or trailing spaces.
sub trim( $ )
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

# Cleans the marc record of common problems.
# param:  Array of MARC tags for a single authority record.
# return: Array of trimmed strings.
sub clean
{
	my @record = ();
	my ( $authId, $tag ) = getAuthId( @_ );
	foreach my $line ( @_ )
	{
		if ( $line =~ m/\.($tag)\.\s+\|a/ )
		{
			$line = $& . $authId;
		}
		# $line = trim( $line ); # Trimming the line has no effect on flat load.
		print STDOUT $line . "\n" if ( $opt{'f'} ); # Write to stdout if requested.
		push @record, $line;
	}
	return @record;
}

# Counts the number of sub-fields in a repeatable field.
# param:  MARC tag.
# return: count.
sub countRepeatableFields( $ )
{
	my $line   = shift;
	my @record = split( '\|a', $line );
	my $count  = 0;
	foreach my $subField (@record)
	{
		$count++;
	}
	return $count;
}

# Updates counts on marc record.
# param:  hash reference of statistics.
# param:  MARC Record lines as list.
# return: none.
sub computeScore
{
	my $stats = shift;
	my $t001   = "";
	my $t016   = "";
	my $t035   = "";
	foreach my $line (@_)
	{
		chomp $line;
		if ( $line =~ m/\s$/ )
		{
			$stats->{'trailing white space'}++;
		}
		if ( $line =~ m/\.001\./ )
		{
			$stats->{'001'}++;
		}
		if ( $line =~ m/\.016\./ )
		{
			$stats->{'016'} += countRepeatableFields( $line );
		}
	}
}

sub process
{
	my @marcRecord = clean( @_ );
	computeScore( $stats, @marcRecord );
	# Test against the 'p're loaded authorities.
	if ( $opt{'p'} || $opt{'t'} )
	{
		my ( $authId, $tag ) = getAuthId( @marcRecord );
		if ( $authId eq "" )
		{
			$stats->{'up_no_auth_id'}++;
		}
		else
		{
			# print STDERR "check:'$authId' in \$PRE_LOAD\n";
			if ( defined $PRE_LOAD->{ $authId } )
			{
				$stats->{'match'}++;
			}
			else
			{
				print STDERR "*warning: failed to match '$authId'\n";
			}
		}
	}
}

init();

# 
my @marcRecord = ();

while(<>)
{
	# Marks the start of a new MARC boundary
	if (m/\*\*\* DOCUMENT BOUNDARY \*\*\*/) 
	{
		$stats->{'update-auth count'}++;
		if ( scalar( @marcRecord ) > 0 )
		{
			process( @marcRecord );
		}
		@marcRecord = ();
	}
	push @marcRecord, $_;
}
# The last iteration of the loop has data but no document marker to terminate it
# So do any data that may be left over from processing.
if ( scalar( @marcRecord ) > 0 )
{
	process( @marcRecord );
}
#########
# Output
print STDERR "Analysis:\n";
while( my ($k, $v) = each %$stats ) 
{
	format STDERR =
@>>>>>>>>>>>>>>>>>>>: @>>>>>>
$k,$v
.
	write STDERR;
}
print STDERR sprintf( "percent match: %0.2f\n", ($stats->{'match'} / $stats->{'update-auth count'}) * 100) if ( $stats->{'match'} && $stats->{'update-auth count'});
# EOF
