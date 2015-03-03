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

cd $HOME

if [ $1 ]
then
	MAX_KEYS=$1
fi
echo "$NAME MAX_KEYS set to $MAX_KEYS."
echo "$NAME TODAY set to $TODAY."
if [ ! -s ./prepmarc.sh ]
then
	echo "$NAME ** script needs $HOME/premarc.sh to run!"
	exit 1
else
	./prepmarc.sh
	# prepmarc.sh knows how to process delete marc files.
	# The bi-product of that process is called: 'DEL.MRC.keys'
	if [ -s $DELETE_KEYS_FILE ]
	then
		echo "$NAME $HOME/premarc.sh has created $DELETE_KEYS_FILE, removing these authorities..."
		cat $DELETE_KEYS_FILE | remauthority -u
		echo "$NAME authorities deleted."
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
		echo "Randomizing the keys for smoother adutext loading."
		randomselection.pl -r -fauthedit.keys >tmp.$$
		if [ ! -s tmp.$$ ]
		then
			echo "$NAME ** Error: temp file of authedit.keys not made, was there a problem with randomselection.pl?"
			exit 1
		fi
		numKeys=$(cat tmp.$$ | wc -l)
		if (( $numKeys <= $MAX_KEYS ))
		then
			echo "$NAME copying authedit.keys to ${BATCH_KEY_DIR}/authedit.keys "
			# There may already be an authedit.keys file in the Batchkeys directory, if there is add to it,
			# if not one will be created.
			cat tmp.$$ >>${BATCH_KEY_DIR}/authedit.keys
		else
			echo "$NAME ** Warning: $numKeys keys found in authedit.keys but $MAX_KEYS requested."
			echo "$NAME ** Warning: split authedit.keys and copy the a section to '${BATCH_KEY_DIR}/authedit.keys'."
			exit 1
		fi
	fi
fi
echo "$NAME done."
#EOF
