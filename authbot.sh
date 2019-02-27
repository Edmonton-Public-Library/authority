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
# Collects all the notices required for the day and coordinates convertion to PDF.
# Instructions:
# 1) Place all you MARC files in the Authorities $HOME directory.
# 2) Run authbot.sh [MAX_KEYS] (where MAX_KEYS is an integer) which will:
#   i) Process marc files into a single normalized fixed.flat file.
#   ii) Load the fixed.flat file. 
#   iii) Move the batch keys file to the BatchKeys directory for adutext to process,
#        on the condition that the maximum number of keys are processed 
#        by authload is not exceeded.
# Example: ./authbot.sh 10000
#    NOTE: Chris informs me that we do not need to stop files from copying after a certain 
#          size since the number of records to process is controlled through the adutext report.
#          This functionality remains within this code. To work around it pass a param greater
#          than the maximum expected authorities.
#
# Revision:
#           5.0 - Fix bug that is loading Bibs as authorities. 
#           4.4 - Added date times stamps to all messages sent to stderr. 
#           4.3 - Port to Redhat which in this case means not using uuencode. 
#           4.2 - Improve record counting and reporting. 
#           4.1 - Reduce report length as requested by staff. 
#           4.0 - Proper, meaningful reporting for staff consumption. Refactored to get rid of premarc.sh and 
#                 bibmarchpoint.sh. 
#           3.3 - Much more reporting of each stage, minor changes to some file tests, fixed 
#                 bug that failed to load MARC files with lower case extensions. 
#           3.2 - Reintroduce updates as an optional process. 
#           3.1 - Return to previous zip submission loading but maintain control of load order. 
#           3.0 - Order of loading zip files matters now; added control to enforce order. 
#           2.3 - Remove convMarc and interactive mode. 
#           2.2 - Added convMarc to retain UTF-8 on load of bibs but not authorities, 
#                 because it doesn't work on authorities.
#           2.1 - Also does no-zip processing. Fixes out of date MRC files bug.
#           2.0 - Functionalized the loads so I can do multiple zip files.
#           1.3 - Added more reporting and simplified zip archive handling.
#           1.2 - Added zip file handling.
#           1.1 - Added load of bibs from BSLW.
#
############################################################################################
export HOME=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage
export WORK_DIR=`getpathname workdir`
export BIN_CUSTOM=`getpathname bincustom`
export BATCH_KEY_DIR=${WORK_DIR}/Batchkeys
export LANG=en_US.UTF-8
export SHELL=/bin/bash
export TODAY=`date +'%Y%m%d'`
export NAME="[authbot.sh]"
export ADDRESSEES="ilsadmins@epl.ca"
export EMAIL_SUBJECT="Authority load report "`date`
export REPORT=$HOME/report.txt
MAX_KEYS=1000000
DELETE_KEYS_FILE=DEL.MRC.keys
# BSLW always sends us the bibs MARC named 'BIB.MRC'
BIB_MARC_FILE=BIB.MRC
LOG=$HOME/log.txt
AUTH_LOG=authbot.log
VERSION="4.4"
# Lets go to the directory where all this is going to be done.
cd $HOME
# Make sure we remove any existing log because our reporting depends on the counts found in
# the output from the running of this script.
if [ -s $LOG ]
then
	rm $LOG
fi
if [ $1 ]
then
	MAX_KEYS=$1
fi
INIT_MSG='['$(date +"%Y-%m-%d %H:%M:%S")'] start ==='
echo $INIT_MSG > $AUTH_LOG
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME ===" >> $AUTH_LOG

# Check for dependancy ./authority.pl
if [ ! -e "$HOME/authority.pl" ]
then
	echo "** error: required file $HOME/authority.pl not found." >&2
	exit 1
fi

# Function to manage each the bib load, delete and adds and changes to authorities.
function do_update 
{
	# First part: update your bibs. This is done because BSLW adds RDA tags 
	# into the bibs for us as part of their contract requirements.
	echo "==> testing for $BIB_MARC_FILE"
	if [ -s $BIB_MARC_FILE ]
	then
		# And we concatenate to ensure we don't blow away any pre-existing adutext.keys file.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> checking bib match points on $BIB_MARC_FILE ..."
		cat $BIB_MARC_FILE | flatskip -im -a'MARC' -of | $BIN_CUSTOM/nowrap.pl > $BIB_MARC_FILE.flat
		# Get all the matchpoint TCNs for comparison with our catalog.
		grep "^\.035\.   |a(Sirsi)" $BIB_MARC_FILE.flat | $BIN_CUSTOM/pipe.pl -W'\s+' -oc2 -dc2 > $BIB_MARC_FILE.CatalogTag035s.lst
		# next we get the number of these found in our catalog BOTH visible and shadowed, and report.
		cat $BIB_MARC_FILE.CatalogTag035s.lst | seltext -lBOTH -oA  2>$BIB_MARC_FILE.analyse
		# Make a record of the file name and tags found in the on-going log file.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $BIB_MARC_FILE" >>$LOG
		cat $BIB_MARC_FILE | marcanalyze >>$LOG 2>$BIB_MARC_FILE.err
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ====== 035 matchpoint report =====" >>$LOG
		cat $BIB_MARC_FILE.analyse >>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME finished checking match point report." >>$AUTH_LOG
		echo "==> done."
		# -im (default) MARC records will be read from standard input.
		# -a (required) specifies the format of the record.
		# -b is followed by one option to indicate how bib records will be matched; 'f'(default) matches on the flexible key.
		# -h is followed by one option to indicate how holdings will be determined; 'n' no holdings processing; no copy is created.
		# -m indicates catalog creation/update/review mode; 'u' update if matched, never create.
		# -f is followed by a list of options specifying how to use the flexible key; 'S' use the Sirsi number (035).
		# -e specifies the filename for saving MARC records with errors.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> running catalogload..." >&2
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME running catalogload." >>$AUTH_LOG
		cat $BIB_MARC_FILE | catalogload -im -a'MARC' -bf -hn -mu -fS -e'BIB.MRC.err' > BIB.MRC.catkeys.lst 2>>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> done." >&2
		# Move the error report from authload into the log for the final error report.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] === Contents of BIB.MRC.err: " >>$LOG
		cat BIB.MRC.err >>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] === End contents of BIB.MRC.err: " >>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME done catalogload." >>$AUTH_LOG
		# Now copy all the affected catalog keys to ${workdir}/Batchkeys/adutext.keys in lieu of touchkeys on each.
		# Adutext will throttle the load based on values specified in the report as outlined below.
		# "In order to process a large amount of catalog keys, this file can be created 
		# which will be partially processed with each adutext run.  The first 
		# ${threshold} lines will be set to be picked up by adutext, then removed 
		# from the file.  Eventually the file will be empty and removed.
		# batchckeyfile=${workdir}/Batchkeys/adutext.keys
		# threshold=20000"
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> managing cat keys from BIB.MRC.catkeys.lst ..." >&2
		if [ -s BIB.MRC.catkeys.lst ]
		then
			# And we concatenate to ensure we don't blow away any pre-existing adutext.keys file.
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME appending keys to ${BATCH_KEY_DIR}/adutext.keys" >>$AUTH_LOG
			cat BIB.MRC.catkeys.lst >>${BATCH_KEY_DIR}/adutext.keys
			# Since we don't want the same key to be processed multiple times because this function 
			# can be run  multiple times for two bib.MRC files; one for changes from LC and one for changes
			# that resulted from submissions from us, we will sort and uniq the keys now.
			if [ -e ${BATCH_KEY_DIR}/adutext.keys ]
			then
				cat ${BATCH_KEY_DIR}/adutext.keys | sort -rn | uniq > temp_sort_keys.$$
				if [ -s temp_sort_keys.$$ ]
				then
					if cp temp_sort_keys.$$ ${BATCH_KEY_DIR}/adutext.keys
					echo "["$(date +"%Y-%m-%d %H:%M:%S")"] Unique bib keys: " >> $REPORT
					cat temp_sort_keys.$$ | pipe.pl -tc0 -cc0 2>> $REPORT
					then
						rm temp_sort_keys.$$
					fi
				fi
			fi
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> done." >&2
		else
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME ** Warning: BIB.MRC.catkeys.lst failed to copy to '${BATCH_KEY_DIR}/adutext.keys' because it was empty."
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME ** Warning: BIB.MRC.catkeys.lst failed to copy to '${BATCH_KEY_DIR}/adutext.keys' because it was empty." >>$AUTH_LOG
		fi
		# next make sure premarc.sh doesn't process this puppy because that will add time to processing.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> moving the $BIB_MARC_FILE $BIB_MARC_FILE.done" >&2
		mv $BIB_MARC_FILE $BIB_MARC_FILE.done
	fi

	# Pre-process all the other MARC files.
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> processing authority MRC files..." >&2
	marcFileCount=0
	declare -a marcFiles=(`ls *.MRC`)
	# ...clean out the fix.flat file, it's a temp file any way.
	if [ -s fix.flat ]; then
		rm fix.flat
	fi
	## now loop through the above array
	for file in "${marcFiles[@]}"
	do
		marcFileCount=$[$marcFileCount +1]
		# Do a MRC analyse and report.
		# Make a record of the file name and tags found in the on-going log file.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME checking $file analyse." >>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME checking $file analyse." >>$AUTH_LOG
		cat $file | marcanalyze >>$LOG 2>>$AUTH_LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME finished checking $file analyse." >>$AUTH_LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME Found MARC file: '$file'. Processing: # $marcFileCount starting flatskip..." >>$AUTH_LOG
		cat $file | flatskip -im -aMARC -of 2>>$AUTH_LOG | $BIN_CUSTOM/nowrap.pl 2>>$AUTH_LOG >$file.flat
		marc_records=`egrep DOCUMENT $file.flat | wc -l`
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $file contains $marc_records " >>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME done flatskip." >>$AUTH_LOG
		if [ $file = 'DEL.MRC' ]
		then
			# Of which there is 1 in every shipment, but only found in the *N.zip file.
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME processing deleted authoriites..." >>$AUTH_LOG
			# Save the report results for catalogers.
			cat $file.flat | $HOME/authority.pl -d > $DELETE_KEYS_FILE 2>>$LOG
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME done." >>$AUTH_LOG
		else
			# Which you don't get with *C.zip
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME processing authoriites..." >>$AUTH_LOG
			# Save the report results for catalogers.
			cat $file.flat | $HOME/authority.pl -v"all" -o >>fix.flat 2>>$LOG
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME done." >>$AUTH_LOG
		fi
		mv $file $file.done
	done
	# process delete marc files.
	echo "==> done."
	# The bi-product of that process is called: 'DEL.MRC.keys'
	if [ -e $DELETE_KEYS_FILE ]
	then
		if [ -s $DELETE_KEYS_FILE ]
		then
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  created $DELETE_KEYS_FILE, removing these authorities..."
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME created $DELETE_KEYS_FILE, removing these authorities..." >>$AUTH_LOG
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME created $DELETE_KEYS_FILE, removing these authorities..." >>$LOG
			cat $DELETE_KEYS_FILE | remauthority -u 2>>$LOG
		fi
		# There is a list of authority keys to remove but it's empty, get rid of it so we don't do this again if re-run.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  authorities deleted." >&2
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME authorities deleted." >>$AUTH_LOG
		rm $DELETE_KEYS_FILE
	fi

	# We should now have a fix.flat file here from the process block before this.
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  testing for fix.flat..."
	if [ -s fix.flat ]
	then
		# Authload doesn't do any touchkeys so we have to put all of the effected keys into 
		# the ${WORK_DIR}/Batchkeys/authedit.keys file for adutext to find and process over the nights to come.
		# *** Warning ***
		# The next line doesn't include convMarc because experiments show that convMarc does not work with authorities.
		# To load the authorities while preserving diacritics, use MarcEdit to convert to marc-8, compile to mrc, and load
		# directly with the following line.
		# *** Warning ***
		# -fc: use 001 as match, -mb: update if possible, otherwise create, -q: set authorized date.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  starting authload 'cat fix.flat | authload -fc -mb -q"$TODAY" -efix.flat.err'" >&2
		cat fix.flat | authload -fc -mb -q"$TODAY" -e"fix.flat.err" > authedit.keys 2>>$LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  done." >&2
		# Move the error report from authload into the log for the final error report.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] === Contents of fix.flat.err: " >> $LOG
		cat fix.flat.err >> $LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] === End of contents of fix.flat.err: " >> $LOG
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  testing and managing authedit.keys..." >&2
		if [ -s authedit.keys ]
		then
			# We have found that if you randomize your keys you can distribute SUBJ changes over a number of nights
			# you can improve your adutext run times by spreading them over a couple of nights rather than doing them
			# all at once.
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME Randomizing the keys for smoother adutext loading." >&2
			randomselection.pl -r -fauthedit.keys >tmp.$$
			if [ ! -s tmp.$$ ]
			then
				echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME ** Error: temp file of authedit.keys not made, was there a problem with randomselection.pl?" >>$AUTH_LOG
				exit 1
			fi
			numKeys=$(cat tmp.$$ | wc -l)
			if (( $numKeys <= $MAX_KEYS ))
			then
				echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME copying authedit.keys to ${BATCH_KEY_DIR}/authedit.keys " >>$AUTH_LOG
				# There may already be an authedit.keys file in the Batchkeys directory, if there is add to it,
				# if not one will be created.
				if cat tmp.$$ >>${BATCH_KEY_DIR}/authedit.keys
				then
					rm tmp.$$
				fi
			else
				echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME ** Warning: $numKeys keys found in authedit.keys but $MAX_KEYS requested." >>$AUTH_LOG
				echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME ** Warning: split authedit.keys and copy the a section to '${BATCH_KEY_DIR}/authedit.keys'." >>$AUTH_LOG
				exit 1
			fi
		else
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  ** no authedit.keys file found." >&2
		fi
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==> done." >&2
	fi
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] ==>  returning to caller of do_update()." >&2
	return;
} # End of do do_update()

# This file is all the authority keys and IDs on our system output in pipe-delimited 
# output format. It is created by authority.pl. This file is a conveinence because it
# takes quite a few minutes to output all the keys, this will save time, on the other
# hand if you have an old file it may produce misleading results. It is always safe to 
# remove this file, authority.pl will create another if it doesn't find one.
# Do we need to clean up from previous runs?
if [ -e AllAuthKeysAndIDs.lst ]
then
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME removing AllAuthKeysAndIDs.lst from last time" >> $AUTH_LOG
	rm AllAuthKeysAndIDs.lst
fi
# If this hasn't been run since last month, or last zip file, we want to ensure that the old work is removed.
# This file is generated as a bi-product of the authload process and is handy to determine what 
# records were affected.
if [ -e authedit.keys ]
then
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME removing authedit.keys from last time" >> $AUTH_LOG
	rm authedit.keys
fi
# Get rid of the previous flat files too.
# Tools like flatskip convert MARC into flat for loading by authload. Authority.pl also
# creates a fixed flat file that contains all the 001 match points normalized to upper case
# No spaces.
if ls *.flat >/dev/null
then
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME removing *.flat  files from last time" >> $AUTH_LOG
	rm *.flat
fi
# Initialize the logs for this run.
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME MAX_KEYS set to $MAX_KEYS." >>$AUTH_LOG
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME TODAY set to $TODAY." >>$AUTH_LOG
# BSLW has switched things up a bit. Now they send mods too so order of loading matters.
# The files are called  CNEDM1602U.zip, CNEDM1602N.zip, and CNEDM1602C.zip
# They have to be loaded in this order
# notif:   CNEDM1602N.zip
# curcat:  CNEDM1602C.zip
# updates: CNEDM1602U.zip
# That is New, Changes, and Updates. If we load updates first changes will overwrite and we don'ta
# get the results we want. See README for more information.
# To to that we are going to rename the files so they are always picked in the right by the remaining process.
new_zip=`ls *N.zip`
change_zip=`ls *C.zip`
update_zip=`ls *U.zip`
if [ -f "$new_zip" ]
then
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] renaming $new_zip to A.zip." >>$AUTH_LOG
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] found $new_zip." >>$LOG
	mv $new_zip A.zip
else
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] **error Failed to find new authorities. Should be named '$new_zip'. Load order of files from BSLW is important. exiting." >>$AUTH_LOG
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == **error Failed to find new authorities. Should be named '$new_zip'. Load order of files from BSLW is important. exiting."
	exit 1
fi
# Now the changes
if [ -f "$change_zip" ]
then
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] renaming $change_zip to B.zip." >>$AUTH_LOG
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] found $change_zip." >>$LOG
	mv $change_zip B.zip
else
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] **error Failed to find change authorities. Should be named '$change_zip'. Load order of files from BSLW is important. exiting." >>$AUTH_LOG
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == **error Failed to find change authorities. Should be named '$change_zip'. Load order of files from BSLW is important. exiting."
	exit 1
fi
if [ -f "$update_zip" ]
then
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] renaming $update_zip to C.zip." >>$AUTH_LOG
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] found $update_zip." >>$LOG
	mv $update_zip C.zip
else
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] No update zip file found, moving right along." >>$AUTH_LOG
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == No update zip file found, moving right along.." >&2
fi

# Here we will look for any zip file and unpack it.
if ls *.zip >/dev/null
then
	declare -a zipFiles=(`ls *.zip`)
	for zip_file in "${zipFiles[@]}"
	do
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == processing $zip_file." >&2
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == testing if any *.MRC files." >&2
		if ls *.MRC
		then
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == yes, removing." >&2
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME removing any MRC files from last time" >> $AUTH_LOG
			rm *.MRC
		else
			echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == no." >&2
		fi
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == Unzipping $zip_file ..." >&2
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME Unzipping $zip_file" >>$AUTH_LOG
		# Clean (rm) zip file so we don't do this over and over.
		unzip $zip_file *.MRC >>$LOG
		## It is also possible they have packaged MRC files as 'mrc' files.
		if unzip $zip_file *.mrc >>$LOG 
		then
			# Rename the files so they will run with a standard extension of .MRC
			for marc_file in *.mrc
			do
				mv "$marc_file" "${marc_file%.mrc}.MRC"
			done
		fi
		# Call the function that will do all the processing Bibs and authorities.
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == calling update()" >&2
		do_update 
		echo "["$(date +"%Y-%m-%d %H:%M:%S")"] == returned from update()" >&2
	done
else # No zip files but could be MRCs here dropped by admin.
	do_update
fi
# Move everything back so we can rerun if needed, and reduce confusion.
mv A.zip $new_zip
mv B.zip $change_zip
mv C.zip $update_zip
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] Total authorities processed: " >> $REPORT
# Pipe's summation command (-a) outputs to STDERR.
# cat authbot.log | pipe.pl -W'\s+' -g'c1:marcin' -oc0 -ac0 2>> $REPORT
cat $LOG | egrep "Record type" | egrep Authority | pipe.pl -W'Count:' -ac1 -oc1 >/dev/null 2>> $REPORT
# ==       sum
# c1:    5443
echo "" >> $REPORT
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] Total bib records processed: " >> $REPORT
# Find the total bibs loaded. We don't want the actual outputs, just the sum:.
cat $LOG | egrep "Record type" | egrep Bibliographic | pipe.pl -W'Count:' -ac1 -oc1 >/dev/null 2>> $REPORT
# ==       sum
# c1:    3562
echo "" >> $REPORT
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] The following bib(s) produced errors: " >> $REPORT
cat $LOG | pipe.pl -g'c0:\.035\.\s+' -m'c1:_#'  -oc1 -dc1 >> $REPORT
echo "Authorities loaded on "`hostname`" on "`date`". Please find load report attached." | mailx -s"$EMAIL_SUBJECT" -a $REPORT "$ADDRESSEES"
echo "["$(date +"%Y-%m-%d %H:%M:%S")"] $NAME end ===." >>$AUTH_LOG
#EOF
