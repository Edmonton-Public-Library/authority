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
# Version:
# 1.2 - Added pipe from flatskip to Bincustom/nowrap.pl.
# 1.1 - Added code append to a single fix.flat file, and remove before the process starts.
#       Fixed comments. Added code to remove old fix.flat if there are more than on new
#       MARC files.
# 1.0 - initial release.
#
############################################################################################
export HOME=/s/sirsi/Unicorn/EPLwork/anisbet/Authorities
export LANG=en_US.UTF-8
export SHELL=/bin/bash
export NAME="[prepmarc.sh]"
export BIN_CUSTOM=`getpathname bincustom`
TOUCH_FILE=./._marc_.txt
LAST_RUN=0
LAST_RUN_DATE=""

# Test for the customer directory and cd there.
if [ -e $HOME ]
then
	cd $HOME
else
	echo "$NAME **error: invalid configuration. '$HOME' doesn't exist."
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
	echo "$NAME no $TOUCH_FILE found, will process all MARC files in directory."
fi

# Here we will get a list of all the new MARC files and process them.
# If you want to re-process any MARC file like foo.MRC, just type the following:
# touch foo.MRC
# ./prepmarc.sh
marcFileCount=0

declare -a marcFiles=(`ls *.MRC`)

echo "$NAME cleaning out old files"
# ...clean out the fix.flat file, it's a temp file any way.
if [ -s fix.flat ]; then
	rm fix.flat
fi
if [ -s log.txt ]; then
	rm log.txt
fi

## now loop through the above array
for file in "${marcFiles[@]}"
do
	perl -e 'print ((stat("'$file'"))[9]);' > tmp.$$
	myFileTime=`cat tmp.$$`
	# echo "comparing $LAST_RUN -lt $myFileTime"
	if (( "$LAST_RUN" < "$myFileTime" ))
	then
		marcFileCount=$[$marcFileCount +1]
		echo "$NAME Found a fresh MARC file: '$file'. Processing: # $marcFileCount..."
		cat $file | flatskip -im -aMARC -of | $BIN_CUSTOM/nowrap.pl 2>>log.txt >$file.flat
		cat $file.flat | ./authority.pl -v"all" -o >>fix.flat 2>>log.txt
	fi
done
rm tmp.$$
# Touch the file so the next time it runs we can compare which files were added after we run now.
touch $TOUCH_FILE
echo "$NAME $marcFileCount fresh files done."
