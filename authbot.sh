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
MAX_KEYS=600000

cd $HOME
if [ ! -s prepmarc.sh ]
then
	echo "$NAME ** script needs $HOME/premarc.sh to run!"
	exit 1
else
	prepmarc.sh
fi
if [ $1 ]
then
	MAX_KEYS=$1
fi
echo "$NAME MAX_KEYS set to $MAX_KEYS."
echo "$NAME TODAY set to $TODAY."
# We should now have a fix.flat file here.
if [ ! -s fix.flat ]
then
	echo "$NAME Nothing to do. Looks like $HOME/premarc.sh didn't produce any output."
	exit 0
else
	# Authload doesn't do any touchkeys, it is designed to take a file of cat keys 
	# the length of which, controls the number of authority records that will be
	# processed by adutext. The current opinion amongst experts is to limit the
	# number to 100,000. After that adutext is liable to run into the HUP.
	cat fix.flat | authload -fc -mb -q"$TODAY" -e"fix.flat.err" > authedit.keys
	if [ -s authedit.keys ]
	then
		# cat authedit.keys | sort -r | uniq > tmp.$$
		echo "Randomizing the keys for smoother adutext loading."
		randomselection.pl -r -fauthedit.keys >tmp.$$
		cp tmp.$$ authedit.keys
		numKeys=$(cat authedit.keys | wc -l)
		if (( $numKeys <= $MAX_KEYS ))
		then
			echo "$NAME copying authedit.keys to ${BATCH_KEY_DIR}/authedit.keys "
			cp authedit.keys ${BATCH_KEY_DIR}/authedit.keys
		else
			echo "$NAME ** Warning: $numKeys keys found in authedit.keys but $MAX_KEYS requested."
			echo "$NAME ** Warning: split authedit.keys and copy the a section to '${BATCH_KEY_DIR}/authedit.keys'."
			exit 1
		fi
	else
		echo "$NAME ** Warning: authedit.keys not created or empty, nothing to do."
		exit 0
	fi
fi
echo "$NAME successful."
#EOF
