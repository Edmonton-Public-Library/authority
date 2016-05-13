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
# Processes all the Authority MARC files in the directory into flat files for testing and loading.
# *************************** WARNING *********************************
# PLEASE ENSURE ALL AUTHORITY MARC FILES ARE CONVERTED FROM UTF-8 TO MARC-8 BEFORE RUNNING.
# == Processing instructions until we move to native UTF-8 ==
# Export the mrc files from the zip archive. Since both archives contain TITLE.NEW.MRC etc, it behoves you to extract into separate folders.
# Open the authority files (basically all files '''except BIB.MRC''') in MarcEdit by double-click on MRC file.
# For each file in-turn, 
## Select execute to convert the MRC into MRK plain text.
## Select edit records.
## In the MarcEdit editor select File>Compile File into MARC, selecting save as MARC-8 MARC File (*.mrc) as the Save as type.
# You can confirm that the file has been processed correctly if you double-click the MARC-8 version of a file and search for accented characters. You should not see {ecute} or similar annotations.
# '''Note''': these instructions are not required for BIB.MRC because convMarc will convert bib marc files.
# *************************** WARNING *********************************
# Version:
# 1.7 - Remove code that processes new files only. Parent script authbot.sh manages files.
# 1.6 - Remove interactive mode because we only handle Unicode, we aren't worried about loading Unicode over ANSEL.
# 1.5 - Important change to NOT use convMarc because it doesn't work on authority MARC files.
#       Added prompt for each file to ensure user accepts responsibility for having authorities in correct format.
# 1.4 - Added convMarc to retain UTF-8 on dump from flatskip.
# 1.3 - Removed log removal and added more output to log.
# 1.2 - Added pipe from flatskip to Bincustom/nowrap.pl.
# 1.1 - Added code append to a single fix.flat file, and remove before the process starts.
#       Fixed comments. Added code to remove old fix.flat if there are more than on new
#       MARC files.
# 1.0 - initial release.
#
############################################################################################
export HOME=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage
export LANG=en_US.UTF-8
export SHELL=/bin/bash
export NAME="[prepmarc.sh]"
export BIN_CUSTOM=`getpathname bincustom`
# TOUCH_FILE=./._marc_.txt
# LAST_RUN=0
# LAST_RUN_DATE=""

# Test for the customer directory and cd there.
if [ -e $HOME ]
then
	cd $HOME
else
	echo "$NAME **error: invalid configuration. '$HOME' doesn't exist." >>log.txt
	exit 1
fi

# If we have run before we left a touch file here. The last modified 
# time stamp is used to determine when we last ran, so we can look for
# newer files.
# if [ -e $TOUCH_FILE ]
# then
	## LAST_RUN=`stat -c %Y $TOUCH_FILE`
	# perl -e 'print ((stat("._marc_.txt"))[9]);' > tmp.$$
	# LAST_RUN=`cat tmp.$$`
	## LAST_RUN_DATE=`stat -c %y $TOUCH_FILE`
# else
	# echo "$NAME no $TOUCH_FILE found, will process all MARC files in directory." >>log.txt
# fi

# Here we will get a list of all the new MARC files and process them.
# If you want to re-process any MARC file like foo.MRC, just type the following:
# touch foo.MRC
# ./prepmarc.sh
marcFileCount=0

declare -a marcFiles=(`ls *.MRC`)

echo "$NAME cleaning out old 'fix.flat' files"
# ...clean out the fix.flat file, it's a temp file any way.
if [ -s fix.flat ]; then
	rm fix.flat
fi

## now loop through the above array
for file in "${marcFiles[@]}"
do
	# perl -e 'print ((stat("'$file'"))[9]);' > tmp.$$
	# myFileTime=`cat tmp.$$`
	# echo "comparing $LAST_RUN -lt $myFileTime"
	# if (( "$LAST_RUN" < "$myFileTime" ))
	# then
		marcFileCount=$[$marcFileCount +1]
		# Let's just make sure the person running this has read the warning above.
		# echo -n "*** WARNING: Are you sure $file is MARC-8 so we don't break our diacritics? y[n]: "
		# read imsure
		# if [ "$imsure" != "y" ]
		# then
			# echo "... it's ok to be cautious, exiting."
			# exit 1
		# fi
		echo "$NAME Found a fresh MARC file: '$file'. Processing: # $marcFileCount..."
		# The next process should remain as is because convMarc doesn't handle authority marc files.
		# == Processing instructions until we move to native UTF-8 ==
		# Export the mrc files from the zip archive. Since both archives contain TITLE.NEW.MRC etc, it behoves you to extract into separate folders.
		# Open the authority files (basically all files '''except BIB.MRC''') in MarcEdit by double-click on MRC file.
		# For each file in-turn, 
		## Select execute to convert the MRC into MRK plain text.
		## Select edit records.
		## In the MarcEdit editor select File>Compile File into MARC, selecting save as MARC-8 MARC File (*.mrc) as the Save as type.
		# You can confirm that the file has been processed correctly if you double-click the MARC-8 version of a file and search for accented characters. You should not see {ecute} or similar annotations.
		# '''Note''': these instructions are not required for BIB.MRC because convMarc will convert bib marc files.
		cat $file | flatskip -im -aMARC -of | $BIN_CUSTOM/nowrap.pl 2>>log.txt >$file.flat
		if [ $file = 'DEL.MRC' ]
		then
			# Of which there is 1 in every shipment, but only found in the *N.zip file.
			cat $file.flat | ./authority.pl -d > $file.keys 2>>log.txt
		else
			# Which you don't get with *C.zip
			cat $file.flat | ./authority.pl -v"all" -o >>fix.flat 2>>log.txt
		fi
	# fi
done
# rm tmp.$$
## Touch the file so the next time it runs we can compare which files were added after we run now.
# touch $TOUCH_FILE
# echo "$NAME $marcFileCount fresh files done." >>log.txt
echo "$NAME $marcFileCount files done." >>log.txt
