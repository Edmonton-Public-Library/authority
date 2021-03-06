#!/usr/bin/perl -w
####################################################
#
# Perl source file for project authority 
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
#          0.9.11_a - Removed example in usage note that refers to defunct -p.
#          0.9.11 - Added a trailing pipe to the authority keys output by -d.
#          0.9.1 - Add -d flag for outputting authority keys for authorities recommended
#                  for deletion, that is, given a list of authority IDs from vendor, output
#                  the authority keys based on a normalized look up of those IDs.
#          0.9.03 - Compute the age of the authority key and authority ID file and don't recreate if < 24 hours.
#          0.9.02 - Removed 'c' from opt line checking. There is nothing that uses it.
#          0.9.01 - Ensure only the fist 001 field is used when processing.
#          0.9 - Removed -c flag since we always want to check against normalized
#                authority IDs, except when the input file is a flat file ('-f'). 
#          0.8 - Output unmatched authority IDs untouched for create process. 
#          0.7 - Fix usage. 
#          0.6 - Verbose messaging. 
#          0.5 - Added count of not matched Auth IDs. 
#          0.4 - Added missing check for -t file. 
#          0.3 - Changed -f flag to -o for consistency. 
#          0.2 - Update comments and add flat file cleaning. 
#          0.1 - Done testing. 
#          0.0 - Dev. 
#
####################################################

use strict;
chomp($ENV{'HOME'} = `. ~/.bashrc; echo ~`);
open(my $IN, "<", "$ENV{'HOME'}/Unicorn/Config/environ") or die "$0: $! $ENV{'HOME'}/Unicorn/Config/environ\n";
while(<$IN>)
{
    chomp;
    my ($key, $value) = split(/=/, $_);
    $ENV{$key} = "$value";
}
close($IN);
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
# $ENV{'PATH'}  = qq{:/software/EDPL/Unicorn/Bincustom:/software/EDPL/Unicorn/Bin:/usr/bin:/usr/sbin};
# $ENV{'UPATH'} = qq{/software/EDPL/Unicorn/Config/upath};
###############################################
my $PRE_LOAD   = {}; # The authority file to report on. 
my $VERSION    = qq{0.9.11_a};

my $stats = {};

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: cat <file.flat> \| $0 [options]
authority.pl reports on the potential match points for authority updates.
It reports how closely an arbitrary flat file matches pre-existing authority
files. It also can repair files to improve authority matches and overcome 
Symphony's authority tools' short comings. When authorities are originally
loaded, any spaces are removed and alpha characters are upper cased.

When you get an authority back from the vendor, it is not always clear if it
is a new authority or a change to an existing authority. This scripts manages
both. If it detects that no authority exists in the current database, it leaves
the vendor's supplied record unaltered for the create process, which will give 
the authority an normalized authority ID and the vendor supplied 001 field. if the 
authority is modified by the vendor, the normalized version is used to find the
matching authority ID. authload then overlays all fields EXCEPT the 001 field.

Example: Backstage will supply an authid of 'nr 4392G99045'. When we load, Symphony 
will normalize it and its internal authority ID will be 'NR4392G99045'. 
If the authority comes back with a modification we will do another comparison and 
find that the normalized auth id exists, and its 001 is 'nr 4392G99045'.
If we created with the normalized version the 001 field would mis-leadingly show 'NR4392G99045'.
This would only be a problem if we had to back reference with BackStage, which has already happened.
The goal is to separate and normalize the update records leaving the un-recognized records unaltered.
This is safe except for when you don't compare with existing records. In that case the match rate drops
to 9% on a good day, and the rest of the un-recognized authority IDs will be created.

The '-d' flag takes the authority IDs on STDIN and then normalizes
the .001. field and perform a look up for the authority ID in the complete list of 
currently existing authorities, then output the corresponding authority key on STDOUT, 
or an warning message, it not found on STDERR. This feature is intended to be
used to identify the authority keys associated with deleted authorities.

Only authority IDs that are recognized on the system are normalized on
output; unrecognized records are output unaltered.

 -d      : Given a set of authority IDs on STDIN, find and output the corresponding
           authority keys to STDOUT. Intended to process deleted MARC records.
 -o      : Write output to standard out. Only works on data from standard in.
 -f<file>: Pre-load an authority flat file to test how closely the input matches,
           otherwise pre-load comparison is taken from 'selauthority -oKF \> AllAuthKeysAndIDs.lst'.
           The input file looks like '518203|XX518203        |', authority key and 
           authority ID separated by pipes.
 -v<all|..> : Verbose messages, anything other than 'all' doesn't report failed matches.
           Updates may have lots.
 -x      : This (help) message.

examples : 
 cat update.flat | $0 -o \> fixed_authorities.flat
To create a flat file with best match for loading authority UPDATES (normalized 001) use:
 cat new_changed_authorities.flat | $0 -v"all" -o \> fixed_authorities.flat
To create a flat file with best match for loading NEW authorities use:
 cat new_changed_authorities.flat | $0 -v"update" -o \> fixed_authorities.flat
Same thing but will suppress warnings about mismatched IDs, all other messages are 
printed to stdout.
To output the authority keys of records for deletion:
 cat delete.flat | $0 -d

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
		$line = compress( $line );
		return $line;
	}
	return "";
}

# Goes through the flat record and parses out the authid. Reports ambiguous 
# authority IDs but always prefers 001.
# param:  array of MARC tags.
# return: (authority id, tag) where tag is always 001.
sub getAuthId
{
	my $authId = "";
	my $tag    = "";
	my $t001   = "";
	my $t016   = "";
	my $first001 = 0; # in Symphony 'echo 906193 | authdump -ki001' will produce:
	# *** DOCUMENT BOUNDARY ***
	# FORM=PERSONAL
	# .000. |az n  c
	# .001. |aN94091369
	# .001. |aAMX-3455
	# .005. |a20031003052447.0
	# .008. |a940922n| acannaabn          |a aaa
	# .010. |an  94091369
	# .035. |a(OCoLC)oca03685773
	# .040. |aDLC|beng|cDLC|dPPi-MA
	# .100. 1 |aSuzuki, Pat
	# .400. 1 |aSuzuki, Chiyoko
	# .670. |aFlower drum song, 1959?:|blabel (Pat Suzuki)
	# .670. |aInternet Movie Database, Oct. 2, 2003|b(Pat Suzuki; b. Chiyoko Suzuki, Sept. 23, early 1930s, Cressy, Calif.)
	# .670. |aBio. and geneal. master index on GaleNet, Oct. 2, 2003|b(Suzuki, Pat, 1930?- ; Suzuki, Pat, 1931- ; Suzuki, Pat)
	# .675. |aContemp. theatre, film, and television, v. 1-49;|aVariety's ww in show business, 1989
	# but notice the 2 001 fields - even though 001 is non-repeating! $first001 signals that we ignore the second loading
	# on the first always just like BSLW requests and does themselves. Phone conversation Jan 7, 2015.
	foreach ( @_ )
	{
		# If we assume the authority id is in one of the following: 001, 016.
		chomp;
		if ( m/\.001\./ && $first001 == 0)
		{
			$t001 = getAuthIDField( $_ );
			$authId = $t001;
			$tag = "001" if ( $t001 ne "" );
			$first001++;
		}
		elsif ( m/\.016\./ )
		{
			$t016 = getAuthIDField( $_ );
		} 
	}
	if ( $t001 ne "" && $t016 ne "" && $t001 ne $t016 )
	{
		print STDERR "*warning: ambiguous authority id, 001='$t001', 016='$t016'\n" if ( $opt{'v'} );
		$stats->{'ambiguous ID'}++;
	}
	return ( $authId, $tag );
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'dof:v:x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	if ( $opt{'f'} )
	{
		# Initialize the counter for matches. If anything fails we still get valid '0'.
		$stats->{'match'} = 0;
		my $pre_auth = $opt{'f'};
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
							$stats->{'pre-auth no ID'}++;
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
					$stats->{'pre-auth no ID'}++;
				}
				else
				{
					$PRE_LOAD->{$authId} = $tag;
				}
			}
		}
		else
		{
			print STDERR "**error: -f selected, but file is missing or empty.\n";
			usage();
		}
	} # End -f
	else # We will create a list of authority key|IDs| for comparison.
	{
		# Initialize the counter for matches. If anything fails we still get valid '0'.
		$stats->{'match'} = 0;
		my $pre_auth = "AllAuthKeysAndIDs.lst";
		print STDERR "creating list of current authority keys and IDs. This could take some time. \n";
		if ( -s $pre_auth )
		{
			my $pre_auth_age = -M $pre_auth;
			print STDERR sprintf( "*Warning: using existing file '%s', aged  %0.1f days.\n", $pre_auth, $pre_auth_age );
		}
		else
		{
			`selauthority -oKF 2>/dev/null > $pre_auth`;
		}
		print STDERR "done.\n";
		if ( -s $pre_auth )
		{
			open AUTH_FILE, "<$pre_auth" or die "**error opening '$pre_auth', $!\n";
			while (<AUTH_FILE>)
			{
				my @record = split( '\|', $_ );
				# The ID will be in the second field.
				if ( defined $record[1] )
				{
					$stats->{'pre-auth count'}++;
					my $authId = trim( $record[1] );
					# Save the authority key as the value.
					$PRE_LOAD->{ $authId } = $record[0];
				}
			}
			close AUTH_FILE;
		}
		else
		{
			print STDERR "**error: '$pre_auth' file is missing or empty.\n";
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
sub normalizeAuthorityID
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
		if ( $line =~ m/FORM=/ )
		{
			$stats->{$'}++;
		}
		if ( $line =~ m/\.001\./ )
		{
			$stats->{'001'}++;
		}
		if ( $line =~ m/\.016\./ )
		{
			$stats->{'016'} += countRepeatableFields( $line );
		}
		if ( $line =~ m/\.010\./ )
		{
			$stats->{'010'}++;
		}
	}
}

# Process the authority record trying to match and record results.
# param:  authority record as a list of strings.
# return: 
sub process
{
	# Keep an unadulterated copy in case we don't find a match because it's a new authority.
	my @unalteredMarcRecord = ();
	foreach ( @_ )
	{
		push @unalteredMarcRecord, $_;
	}
	my @alteredMarcRecord = normalizeAuthorityID( @_ );
	computeScore( $stats, @alteredMarcRecord );
	my $isMatch = 0;
	# Test against the 'p're loaded authorities.
	my ( $authId, $tag ) = getAuthId( @alteredMarcRecord );
	if ( $authId eq "" )
	{
		$stats->{'update w/o auth id'}++;
	}
	else
	{
		# print STDERR "check:'$authId' in \$PRE_LOAD\n";
		if ( defined $PRE_LOAD->{ $authId } )
		{
			$stats->{'match'}++;
			$isMatch = 1;
			if ($opt{'d'})
			{
				print STDOUT $PRE_LOAD->{ $authId } . "|\n";
			}
		}
		else
		{
			print STDERR "*warning: failed to match '$authId'\n" if (( $opt{'v'} && $opt{'v'} eq "all" ) or $opt{'d'});
			$stats->{'no match'}++;
		}
	}
	# If requested we will output the record now. If the record matched existing auth_id it means
	# we have already loaded it. That means that Symphony has a normalized auth id, but the 001
	# tag will have a non-normalized field. Since we want all authorities that we have never seen 
	# before to be loaded from BackStage without modification. On next update we will have to 
	# reference the auth ID by the normalized version. Example: Backstage will supply an authid of
	# 'nr 4392G99045'. when we load that Symphony will normalize it and its internal auth id will be
	# 'NR4392G99045' (by selauthority) when it gets loaded. If the authority comes back with a modification
	# we will do another comparison and find that the normalized auth id exists, and its 001 is 'nr 4392G99045'.
	# If we created with the normalized version the 001 field would mis-leadingly show 'NR4392G99045'.
	# This would only be a problem if we had to back reference with BackStage, which has already happened.
	# The goal is to separate and normalize the update records leaving the un-recognized records unmolested.
	# This is safe except for when you don't compare with existing records. In that case the match rate drops
	# to 9% on a good day, and the rest of the un-recognized auth IDs will be created.
	if ( $opt{'o'} )
	{
		# There was no match so output the original record without modifications for creating authority with standard 001.
		if ( $isMatch == 0 ) 
		{
			foreach my $line ( @unalteredMarcRecord )
			{
				print STDOUT $line; # Write to stdout if requested, they have new lines already.
			}
		}
		else # There was a match so output the normalized authority ID for load matching.
		{
			foreach my $line ( @alteredMarcRecord )
			{
				print STDOUT $line . "\n"; # Write to stdout if requested.
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
