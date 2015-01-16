#!/bin/bash
###########################################################################################
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
# Processes all the MARC files in the directory into flat files for testing and loading.
#
############################################################################################
export HOME=/s/sirsi/Unicorn/EPLwork/anisbet/Authorities
export LANG=en_US.UTF-8
export SHELL=/bin/bash

TOUCH_FILE=./._marc_.txt
LAST_RUN=0
LAST_RUN_DATE=""

# Test for the customer directory and cd there.
if [ -e $HOME ]
then
	cd $HOME
else
	echo "**error: invalid configuration. '$HOME' doesn't exist."
	exit 1
fi

# If we have run before we left a touch file here. The last modified 
# time stamp is used to determine when we last ran, so we can look for
# newer files.
if [ -e $TOUCH_FILE ]
then
	# LAST_RUN=`stat -c %Y $TOUCH_FILE`
	perl -e 'print ((stat("._marc_.txt"))[9]);' > tmp.$$
	LAST_RUN=`cat tmp.$$`
	# LAST_RUN_DATE=`stat -c %y $TOUCH_FILE`
else
	echo "no $TOUCH_FILE found, will process all MARC files in directory."
fi

# Here we will get a list of all the new MARC files and process them.
# If you want to re-process any MARC file like foo.MRC, just type the following:
# touch foo.MRC
# ./prepmarc.sh
if ls *.MRC >/dev/null
then
	declare -a marcFiles=(`ls *.MRC`)
	marcFileCount=0

	## now loop through the above array
	for file in "${marcFiles[@]}"
	do
		perl -e 'print ((stat("'$file'"))[9]);' > tmp.$$
		myFileTime=`cat tmp.$$`
		# echo "comparing $LAST_RUN -lt $myFileTime"
		if (( "$LAST_RUN" < "$myFileTime" ))
		then
			echo "Found a fresh MARC file: '$file'. Processing..."
			marcFileCount=$[$marcFileCount +1]
			cat $file | flatskip -im -aMARC -of 2>>log.txt >$file.flat
			cat $file.flat | ./authority.pl -v"all" -o >$file.fix.flat 2>>log.txt
			echo "$marcFileCount files done."
		fi
	done
	if [[ $marcFileCount -gt 0 ]]
	then
		echo "$marcFileCount new fresh MARC files found since last check." 
	fi
fi # No failed customers found.
rm tmp.$$
# Touch the file so the next time it runs we can compare which files were added after we run now.
touch $TOUCH_FILE
