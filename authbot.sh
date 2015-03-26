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
#   i) Run $HOME/premarc.sh to process marc files into a single normalized fixed.flat file.
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
#           2.0 - Functionalized the loads so I can do multiple zip files.
#           1.3 - Added more reporting and simplified zip archive handling.
#           1.2 - Added zip file handling.
#           1.1 - Added load of bibs from BSLW.
#
############################################################################################
export HOME=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage
export WORK_DIR=`getpathname workdir`
export BATCH_KEY_DIR=${WORK_DIR}/Batchkeys
export LANG=en_US.UTF-8
export SHELL=/bin/bash
export TODAY=`date +'%Y%m%d'`
export NAME="[authbot.sh]"
MAX_KEYS=1000000
DELETE_KEYS_FILE=DEL.MRC.keys
# BSLW always sends us the bibs MARC named 'BIB.MRC'
BIB_MARC_FILE=BIB.MRC

# Function to manage each the bib load, delete and adds and changes to authorities.
do_update ()
{
	# First part: update your bibs. This is done because BSLW adds RDA tags 
	# into the bibs for us as part of their contract requirements.
	if [ -s $BIB_MARC_FILE ]
	then
		# Do some reporting on the file we got.
		if [ -s bibmatchpoint.sh ]
		then
			# And we concatenate to ensure we don't blow away any pre-existing adutext.keys file.
			bibmatchpoint.sh $BIB_MARC_FILE 2>&1 >>authbot.log
			echo "$NAME finished running bibmatchpoint.sh." >>authbot.log
		else
			echo "$NAME ** Warning: bibmatchpoint.sh not present in this directory." >>authbot.log
		fi
		# -im (default) MARC records will be read from standard input.
		# -a (required) specifies the format of the record.
		# -b is followed by one option to indicate how bib records will be matched; 'f'(default) matches on the flexible key.
		# -h is followed by one option to indicate how holdings will be determined; 'n' no holdings processing; no copy is created.
		# -m indicates catalog creation/update/review mode; 'u' update if matched, never create.
		# -f is followed by a list of options specifying how to use the flexible key; 'S' use the Sirsi number (035).
		# -e specifies the filename for saving MARC records with errors.
		echo "$NAME running catalogload." >>authbot.log
		cat $BIB_MARC_FILE | catalogload -im -a'MARC' -bf -hn -mu -fS -e'BIB.MRC.err' > BIB.MRC.catkeys.lst
		echo "$NAME done catalogload." >>authbot.log
		# Now copy all the affected catalog keys to ${workdir}/Batchkeys/adutext.keys in lieu of touchkeys on each.
		# Adutext will throttle the load based on values specified in the report as outlined below.
		# "In order to process a large amount of catalog keys, this file can be created 
		# which will be partially processed with each adutext run.  The first 
		# ${threshold} lines will be set to be picked up by adutext, then removed 
		# from the file.  Eventually the file will be empty and removed.
		# batchckeyfile=${workdir}/Batchkeys/adutext.keys
		# threshold=20000"
		if [ -s BIB.MRC.catkeys.lst ]
		then
			# And we concatenate to ensure we don't blow away any pre-existing adutext.keys file.
			echo "$NAME appending keys to ${BATCH_KEY_DIR}/adutext.keys" >>authbot.log
			cat BIB.MRC.catkeys.lst >>${BATCH_KEY_DIR}/adutext.keys
		else
			echo "$NAME ** Warning: BIB.MRC.catkeys.lst failed to copy to '${BATCH_KEY_DIR}/adutext.keys' because it was empty." >>authbot.log
		fi
		# next make sure premarc.sh doesn't process this puppy because that will add time to processing.
		rm $BIB_MARC_FILE
	fi

	# Pre-process all the other MARC files.
	if [ ! -s ./prepmarc.sh ]
	then
		echo "$NAME ** script needs $HOME/premarc.sh to run!" >>authbot.log
		exit 1
	else
		echo "$NAME running prepmarc.sh" >>authbot.log
		./prepmarc.sh
		# prepmarc.sh knows how to process delete marc files.
		# The bi-product of that process is called: 'DEL.MRC.keys'
		if [ -s $DELETE_KEYS_FILE ]
		then
			echo "$NAME $HOME/premarc.sh has created $DELETE_KEYS_FILE, removing these authorities..." >>authbot.log
			cat $DELETE_KEYS_FILE | remauthority -u
			echo "$NAME authorities deleted." >>authbot.log
			# Now remove the file so we don't do this again if re-run.
			rm $DELETE_KEYS_FILE
		fi
	fi

	# We should now have a fix.flat file here.
	if [ -s fix.flat ]
	then
		# Authload doesn't do any touchkeys so we have to put all of the effected keys into 
		# the ${WORK_DIR}/Batchkeys/authedit.keys file for adutext to find and process over the nights to come.
		cat fix.flat | authload -fc -mb -q"$TODAY" -e"fix.flat.err" > authedit.keys
		if [ -s authedit.keys ]
		then
			# We have found that if you randomize your keys you can distribute SUBJ changes over a number of nights
			# you can improve your adutext run times by spreading them over a couple of nights rather than doing them
			# all at once.
			echo "$NAME Randomizing the keys for smoother adutext loading."
			randomselection.pl -r -fauthedit.keys >tmp.$$
			if [ ! -s tmp.$$ ]
			then
				echo "$NAME ** Error: temp file of authedit.keys not made, was there a problem with randomselection.pl?" >>authbot.log
				exit 1
			fi
			numKeys=$(cat tmp.$$ | wc -l)
			if (( $numKeys <= $MAX_KEYS ))
			then
				echo "$NAME copying authedit.keys to ${BATCH_KEY_DIR}/authedit.keys " >>authbot.log
				# There may already be an authedit.keys file in the Batchkeys directory, if there is add to it,
				# if not one will be created.
				if cat tmp.$$ >>${BATCH_KEY_DIR}/authedit.keys
				then
					rm tmp.$$
				fi
			else
				echo "$NAME ** Warning: $numKeys keys found in authedit.keys but $MAX_KEYS requested." >>authbot.log
				echo "$NAME ** Warning: split authedit.keys and copy the a section to '${BATCH_KEY_DIR}/authedit.keys'." >>authbot.log
				exit 1
			fi
		fi
	fi
} # End of do do_update()

cd $HOME

if [ $1 ]
then
	MAX_KEYS=$1
fi
INIT_MSG=`date`' start ==='
echo $INIT_MSG > authbot.log
echo "$NAME ===" >> authbot.log
# Do we need to clean up from previous runs?
if [ -e AllAuthKeysAndIDs.lst ]
then
	echo "$NAME removing AllAuthKeysAndIDs.lst from last time" >> authbot.log
	rm AllAuthKeysAndIDs.lst
fi
if ls *.MRC >/dev/null
then
	echo "$NAME removing MRC files from last time" >> authbot.log
	rm *.MRC
fi
if ls BIB.MRC.*
then
	echo "$NAME removing BIB.MRC.* report files from last time" >> authbot.log
	rm BIB.MRC.*
fi

echo "$NAME MAX_KEYS set to $MAX_KEYS." >>authbot.log
echo "$NAME TODAY set to $TODAY." >>authbot.log
# Here we will look for any zip file and unpack it. Don't worry if you don't find it,
# the admin may have placed the required files in the directory manually.
if ls *.zip >/dev/null
then
	declare -a zipFiles=(`ls *.zip`)
	for file in "${zipFiles[@]}"
	do
		echo "$NAME Unzipping $file" >>authbot.log
		if unzip $file *.MRC >>authbot.log
		then
			echo "$NAME removing $file" >>authbot.log
			rm $file
		fi
		# Call the function that will do all the processing on DEL.MRC Bibs and authorities.
		do_update 
	done
fi

echo "$NAME end ===." >>authbot.log
#EOF
