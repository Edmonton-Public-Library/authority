#!/bin/bash
###########################################################################################
#
# This script prepares and loads authority files and bibliographic files from BSLW.
#
#    Copyright (C) 2019  Andrew Nisbet, Edmonton Public Library
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
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
# Instructions:
# 1) Place all downloaded zip files from BSLW into $WORK_DIR_AN 
#    (/software/EDPL/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage).
# 2) Run authbot.sh -K {MAX_KEYS} (where MAX_KEYS is an integer) which will:
#   i) Process marc files into a single normalized fixed.flat file.
#   ii) Load the fixed.flat file. 
#   iii) Move the batch keys file to the BatchKeys directory for adutext to process,
#        on the condition that the maximum number of keys are processed 
#        by authload is not exceeded.
# Example: ./authbot.sh -K 10000
#    NOTE: Chris informs me that we do not need to stop files from copying after a certain 
#          size since the number of records to process is controlled through the adutext report.
#          This functionality remains within this code. To work around it pass a param greater
#          than the maximum expected authorities.
#
# Revision:
#           2.0 - Refactoring of authbot.sh V4.3.
#
############################################################################################
WORK_DIR_AN=/software/EDPL/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage
VERSION="2.0_j"
MAX_KEYS=1000000
INSTITUTION="CNEDM"
FILE_DATE=$(date +%y%m)  # File name format: CNEDMYYMMN.zip
## CNEDM1902N.zip, CNEDM1902C.zip, and CNEDM1902U.zip
BINCUSTOM=$(getpathname bincustom)
BIN=$(getpathname bin)
WORK_DIR=$(getpathname workdir)
BATCH_KEY_DIR=$WORK_DIR/Batchkeys
NEW=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}N.zip
CHANGE=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}C.zip
UPDATE=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}U.zip
LOG=$WORK_DIR_AN/authbot.log
BACKUP=$WORK_DIR_AN/Bak
ZIP=$WORK_DIR_AN/Zip.tmp
FIX_FLAT=$WORK_DIR_AN/fix.flat
DELETE_KEYS_FILE=$WORK_DIR_AN/DEL.MRC.keys
EMAILS="andrew.nisbet@epl.ca"

TRUE=0
FALSE=1
ANNOY=$FALSE
# Test if a file is present. Exits with a message if not found.
# param:  fully qualified path to file.
require()
{
    echo -n "Testing for $1: "
    if [ -s "$1" ]; then
       echo "OK"
    else
        echo "FAIL"
        exit 1
    fi
}

# Test for all the required applications. $BIN, /bin, $BINCUSTOM, and $WORK_DIR_AN must exist and be 
# declared in $PATH
# param:  none
test_requires()
{
    require $BINCUSTOM/randomselection.pl
    require $BIN/authload
    require $BIN/marcanalyze
    require $BIN/flatskip
    require $BINCUSTOM/nowrap.pl
    require $WORK_DIR_AN/authority.pl
    require $BIN/remauthority
    require $BINCUSTOM/pipe.pl
    require $BIN/catalogload
    require $BIN/seltext
    require /bin/unzip
    require /bin/date
}

# Displays the usage for this product.
# param:  none
# return: none
usage()
{
    cat << EOFU!
 Usage: $0 -x
  Processes and load authorities and bib MARC files received from BackStage Library Works
  (BSLW). These files are typically sent as zip files named for the type of changes 
  the MRC files represent.
  
  They have to be loaded in this order CNEDM1902U.zip, CNEDM1902N.zip, and CNEDM1902C.zip
  notif:   CNEDM1602N.zip
  curcat:  CNEDM1602C.zip
  updates: CNEDM1602U.zip
  That is New, Changes, and Updates. If we load updates first changes will overwrite and we don'ta
  get the results we want. See README for more information.
  To to that we are going to rename the files so they are always picked in the right by the
  remaining process.

Flags:
  -a: Process all authority files in order. If any expected zip file is missing the
     script will halt with a message to stderr and to $LOG.
  -D: Stop at all break points. Allows the user to check results as the script progresses.
  -c: Process changes (curcat) zip file contents.
  -d {YYMM}: setting date to $OPTARG instead of the current year/month.
  -K {integer}: Throttle the number of authority keys processed per adutext run. This 
      would be used if you are reloading all your authorities. This will restrict.
  -n: Process new records (notif) from corresponding zip file.
  -u: Process updates (changes) from corresponding zip file.
  -x: Display (this) help message.
   
 Example:
    Process new (notif) file from February 2019 instead of the current month with debugging messages.
    ./authbot.sh -d1902 -Dn
    Process all authority files in the directory.
    ./authbot.sh -a
 Version: $VERSION
EOFU!
}

# Asks if user would like to do what the message says.
# param:  message string.
# return: 0 if the answer was yes and 1 otherwise.
confirm()
{
	if [ -z "$1" ]; then
		echo `date +"%Y-%m-%d %H:%M:%S"`" ** error, confirm_yes requires a message." >>$LOG
		echo "** error, confirm_yes requires a message." >&2
		exit $FALSE
	fi
	local message="$1"
	echo `date +"%Y-%m-%d %H:%M:%S"`" $message? y/[n]: " >>$LOG
	echo "$message? y/[n]: " >&2
	read answer
	case "$answer" in
		[yY])
			echo `date +"%Y-%m-%d %H:%M:%S"`" yes selected." >>$LOG
			echo "yes selected." >&2
			echo $TRUE
			;;
		*)
			echo `date +"%Y-%m-%d %H:%M:%S"`" no selected." >>$LOG
			echo "no selected." >&2
			echo $FALSE
			;;
	esac
}

# Logs messages to STDERR and $LOG file.
# param:  Log file name. The file is expected to be a fully qualified path or the output
#         will be directed to a file in the directory the script's running directory.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local log_file=$1
    local message="$2"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$time $message" >>$log_file
    echo "$time $message" >&2
    if [ $ANNOY == $TRUE ] && [ $(confirm "BREAK POINT: $3 Continue ") == "$FALSE" ]; then
        echo " exiting early."
        exit 1
    fi
}

# The files will be extracted to a temp directory, the names of the MARC
# files are normalized, then copied out of that directory and placed in 
# the working directory.
get_MRC_files()
{
    # extract all the MRC and mrc files to a temp folder under this directory.
    local zip_file=$1
    # First get rid of any existing .MRC or .mrc files.
    if rm *.MRC 2>/dev/null; then
        logit $LOG "removed pre-existing *.MRC files from $WORK_DIR_AN."
    fi
    if [ ! -d "$BACKUP" ]; then
        logit $LOG "creating backup directory $BACKUP."
        mkdir $BACKUP
    fi
    if [ ! -d "$ZIP" ]; then
        logit $LOG "creating backup directory $ZIP."
        mkdir $ZIP
    fi
    if [ ! -s "$zip_file" ]; then 
        logit $LOG "**error: requested zip file $zip_file doesn't exist or is empty."
        exit 1
    fi
    cp $zip_file $ZIP
    cd $ZIP 
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
    cd ..
    mv $ZIP/*.MRC .
    # Now move the file to the backup directory
    mv $zip_file $BACKUP/
    # Clean up the temp zip directory it may have tons of reports or other files.
    rm -rf $ZIP
}

# Processes the bibs file. 
# param:  none
process_bibs()
{
    for BIB_MARC_FILE in $(ls BIB.* 2>/dev/null); do
        # And we concatenate to ensure we don't blow away any pre-existing adutext.keys file.
		logit $LOG " ==> checking bib match points on $BIB_MARC_FILE ..."
		cat $BIB_MARC_FILE | flatskip -im -a'MARC' -of | nowrap.pl > $BIB_MARC_FILE.flat
		# Get all the matchpoint TCNs for comparison with our catalog.
		egrep -e "^\.035\.   |a(Sirsi)" $BIB_MARC_FILE.flat | pipe.pl -W'\s+' -oc2 -dc2 > $BIB_MARC_FILE.CatalogTag035s.lst
		# next we get the number of these found in our catalog BOTH visible and shadowed, and report.
		cat $BIB_MARC_FILE.CatalogTag035s.lst | seltext -lBOTH -oA  2>$BIB_MARC_FILE.analyse
		# Make a record of the file name and tags found in the on-going log file.
		logit $LOG " $BIB_MARC_FILE"
		cat $BIB_MARC_FILE | marcanalyze >>$LOG 2>$BIB_MARC_FILE.err
		logit $LOG " ====== 035 matchpoint report ====="
		cat $BIB_MARC_FILE.analyse >>$LOG
		logit $LOG "  finished checking match point report."
		echo "==> done."
		# -im (default) MARC records will be read from standard input.
		# -a (required) specifies the format of the record.
		# -b is followed by one option to indicate how bib records will be matched; 'f'(default) matches on the flexible key.
		# -h is followed by one option to indicate how holdings will be determined; 'n' no holdings processing; no copy is created.
		# -m indicates catalog creation/update/review mode; 'u' update if matched, never create.
		# -f is followed by a list of options specifying how to use the flexible key; 'S' use the Sirsi number (035).
		# -e specifies the filename for saving MARC records with errors.
		logit $LOG " ==> running catalogload..."
		logit $LOG "  running catalogload."
		cat $BIB_MARC_FILE | catalogload -im -a'MARC' -bf -hn -mu -fS -e'BIB.MRC.err' > BIB.MRC.catkeys.lst 2>>$LOG
		logit $LOG " ==> done."
		# Move the error report from authload into the log for the final error report.
		logit $LOG " === Contents of BIB.MRC.err: " 
		cat BIB.MRC.err >>$LOG
		logit $LOG " === End contents of BIB.MRC.err: " 
		logit $LOG "  done catalogload." 
		# Now copy all the affected catalog keys to ${workdir}/Batchkeys/adutext.keys in lieu of touchkeys on each.
		# Adutext will throttle the load based on values specified in the report as outlined below.
		# "In order to process a large amount of catalog keys, this file can be created 
		# which will be partially processed with each adutext run.  The first 
		# ${threshold} lines will be set to be picked up by adutext, then removed 
		# from the file.  Eventually the file will be empty and removed.
		# batchckeyfile=${workdir}/Batchkeys/adutext.keys
		# threshold=20000"
		logit $LOG " ==> managing cat keys from BIB.MRC.catkeys.lst ..."
		if [ -s BIB.MRC.catkeys.lst ]
		then
			# And we concatenate to ensure we don't blow away any pre-existing adutext.keys file.
			logit $LOG "  appending keys to ${BATCH_KEY_DIR}/adutext.keys"
			cat BIB.MRC.catkeys.lst >>$BATCH_KEY_DIR/adutext.keys
			# Since we don't want the same key to be processed multiple times because this function 
			# can be run  multiple times for two bib.MRC files; one for changes from LC and one for changes
			# that resulted from submissions from us, we will sort and uniq the keys now.
			if [ -e "$BATCH_KEY_DIR/adutext.keys" ]
			then
				cat $BATCH_KEY_DIR/adutext.keys | sort -rn | uniq > temp_sort_keys.$$
				if [ -s temp_sort_keys.$$ ]
				then
					if cp temp_sort_keys.$$ $BATCH_KEY_DIR/adutext.keys
					logit $LOG " Unique bib keys: " 
					cat temp_sort_keys.$$ | pipe.pl -tc0 -cc0 2>> $LOG
					then
						rm temp_sort_keys.$$
					fi
				fi
			fi
			logit $LOG " ==> done."
		else
			logit $LOG "  ** Warning: BIB.MRC.catkeys.lst failed to copy to '${BATCH_KEY_DIR}/adutext.keys' because it was empty."
			logit $LOG "  ** Warning: BIB.MRC.catkeys.lst failed to copy to '${BATCH_KEY_DIR}/adutext.keys' because it was empty."
		fi
		# next make sure premarc.sh doesn't process this puppy because that will add time to processing.
		logit $LOG " ==> moving the $BIB_MARC_FILE $BIB_MARC_FILE.done"
        # Stop the authority process from accidentally loading this as if it were a authority file.
		mv $BIB_MARC_FILE $BIB_MARC_FILE.done
    done
}

# Processes the special DEL.MRC file keys produced when process_zipped ran.
# param:  name of the file of deleted authority keys.
process_deletes()
{
    local delete_keys_file="$1"
    # The bi-product of that process is called: 'DEL.MRC.keys'
    if [ -s "$delete_keys_file" ]; then
        logit $LOG " created $delete_keys_file, removing these authorities..."
        cat $delete_keys_file | remauthority -u 2>>$LOG
        logit $LOG "==>  authorities deleted."
        # There is a list of authority keys to remove but it's empty, get rid of it so we don't do this again if re-run.
        rm $delete_keys_file
    else
        logit $LOG "**error call to delete authorities but the athority file '$delete_keys_file' is not found or empty."
    fi
}

#
# param:  
process_authorities()
{
    # ...clean out the $FIX_FLAT file, it's a temp file any way.
    if [ -s "$FIX_FLAT" ]; then
        rm $FIX_FLAT
    fi
    for file in $(ls *.MRC); do
        # Pre-process all the other MARC files.
        logit $LOG "==> processing authority MRC files..."
        # Do a MRC analyse and report.
        # Make a record of the file name and tags found in the on-going log file.
        logit $LOG " checking $file analyse."
        cat $file | marcanalyze >>$LOG
        logit $LOG " finished checking $file analyse."
        cat $file | flatskip -im -aMARC -of | nowrap.pl >$file.flat
        marc_records=$(egrep DOCUMENT $file.flat | wc -l)
        logit $LOG "$file contains $marc_records"
        logit $LOG " finished flatskip."
        if [ $file = 'DEL.MRC' ]; then
            # Of which there is 1 in every shipment, but only found in the *N.zip file.
            logit $LOG " processing deleted authorities..."
            # Save the report results for catalogers.
            cat $file.flat | $WORK_DIR_AN/authority.pl -d > $DELETE_KEYS_FILE 2>>$LOG
            logit $LOG " done."
        else
            # Which you don't get with *C.zip
            logit $LOG " processing authorities..." 
            # Save the report results for catalogers.
            cat $file.flat | $WORK_DIR_AN/authority.pl -v"all" -o >>$FIX_FLAT 2>>$LOG
            logit $LOG " done." 
        fi
        # Clean up the source MRC so we don't reprocess it.
        mv $file $file.done
    done
    logit $LOG "==> done."
}

# Processes authorities, but before we can do that we have to normalize them since Symphony
# at the time of writing, only saved authority keys in upper case, regardless of how they arrive
# from the vendor. This makes matching impossible without normalization.
# param:  Name of the file of normalized authority IDs, ($FIX_FLAT).
process_normalized_authorities()
{
    local fix_flat=$1
    local today=$(transdate -d-0)
    # We should now have a $fix_flat file here from the process block before this.
    logit $LOG "==>  testing for $fix_flat..."
    # Authload doesn't do any touchkeys so we have to put all of the effected keys into 
    # the ${WORK_DIR}/Batchkeys/authedit.keys file for adutext to find and process over the nights to come.
    # *** Warning ***
    # The next line doesn't include convMarc because experiments show that convMarc does not work with authorities.
    # To load the authorities while preserving diacritics, use MarcEdit to convert to marc-8, compile to mrc, and load
    # directly with the following line.
    # *** Warning ***
    # -fc: use 001 as match, -mb: update if possible, otherwise create, -q: set authorized date.
    local API="authload -fc -mb -q$today"
    logit $LOG " ==>  starting authload::'cat $fix_flat | $API'"
    cat $fix_flat | $API > authedit.keys 2>>$LOG
    logit $LOG " ==>  done."
    logit $LOG "==>  testing and managing authedit.keys..."
    if [ -s authedit.keys ]
    then
        # We have found that if you randomize your keys you can distribute SUBJ changes over a number of nights
        # you can improve your adutext run times by spreading them over a couple of nights rather than doing them
        # all at once.
        logit $LOG " Randomizing the keys for smoother adutext loading."
        randomselection.pl -r -fauthedit.keys >tmp.$$
        if [ ! -s tmp.$$ ]
        then
            logit $LOG "** Error: temp file of authedit.keys not made, was there a problem with randomselection.pl?"
            exit 1
        fi
        numKeys=$(cat tmp.$$ | wc -l)
        if (( $numKeys <= $MAX_KEYS )); then
            logit $LOG "  copying authedit.keys to ${BATCH_KEY_DIR}/authedit.keys "
            # There may already be an authedit.keys file in the Batchkeys directory, if there is add to it,
            # if not one will be created.
            if cat tmp.$$ >>${BATCH_KEY_DIR}/authedit.keys; then
                rm tmp.$$
            fi
        else
            logit $LOG "** Warning: $numKeys keys found in authedit.keys but $MAX_KEYS requested."
            logit $LOG "** Warning: split authedit.keys and copy the a section to '${BATCH_KEY_DIR}/authedit.keys'."
            exit 1
        fi
    else
        logit $LOG "==>  ** no authedit.keys file found."
    fi
}

# Processes all the authority files within a given zip file.
# param:  Zip file to process, should be the fully qualified path.
process_zipped()
{
    local zip_file=$1
    # extract all the MRC and mrc files to this directory.
    get_MRC_files $zip_file
    # process each of the MRC files.
    # If there is a BIB file in this zip do it now, but nothing will be done if there aren't
    # any. The function has to run though because if there is a BIB file, this func will process it
    # and rename it, so it doesn't get accidentally loaded as an authority.
    process_bibs
    # Now do any authority files.
    process_authorities 
    # One of the authority files will eventually be a DEL.MRC file so we will do the deletes now.
    # This file is generated by process_authorities() and removed during process_deletes().
    if [ -s "$DELETE_KEYS_FILE" ]; then
        process_deletes $DELETE_KEYS_FILE
    else
        logit $LOG "$zip_file didn't contain any deleted authority MRC files."
    fi
    # Process the fixed (normalized authority IDs)
    login $LOG "==>  testing for normalized authotity keys to match for loading and updating."
    if [ -s "$FIX_FLAT" ]; then
        process_normalized_authorities $FIX_FLAT
    else
        logit $LOG "*warning, no authorities files found in $zip_file."
    fi
    logit $LOG " == done."
}

################################# Run section #################################
cd $WORK_DIR_AN
if [ -s "$LOG" ]; then
    ANSWER=$(confirm "remove existing log file ")
    if [ "$ANSWER" == "$TRUE" ]; then
        rm "$LOG"
    else
        logit $LOG "====== New authbot log session ======"
    fi
fi
while getopts ":acd:DK:nux" opt; do
  case $opt in
    a)  logit $LOG "-a processing all authority files in order."
        test_requires
        # Order is important so do the following:
        process_zipped $NEW
        process_zipped $CHANGE
        process_zipped $UPDATE
        ;;
    D)  logit $LOG "-D triggered to stop at all processing break points for debugging."
        ANNOY=$TRUE
        ;;
    c)  logit $LOG "-c processing changes (curcat) $CHANGE."
        ANSWER=$(confirm "*warning: If there is a $NEW load it first. Continue")
        if [ "$ANSWER" == "$FALSE" ]; then
            logit $LOG "Aborting at user's request."
            exit 1
        fi 
        test_requires
        process_zipped $CHANGE
        ;;
	d)  logit $LOG " -d looking for ${INSTITUTION}$OPTARG*.zip files instead of the current year/month."
        FILE_DATE=$OPTARG
        NEW=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}N.zip
        CHANGE=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}C.zip
        UPDATE=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}U.zip
        ;;
	K)  logit $LOG " -K throttling adutext to $OPTARG keys."
        MAX_KEYS=$OPTARG
        ;;
    n)  logit $LOG "-n processing new records (notif) $NEW."
        test_requires
        process_zipped $NEW
        ;;
    u)  logit $LOG "-u processing updates (changes) $CHANGE."
        ANSWER=$(confirm "*warning: If there is a $NEW, or $CHANGE load them first. Continue")
        if [ "$ANSWER" == "$FALSE" ]; then
            logit $LOG "Aborting at user's request."
            exit 1
        fi
        # In case the user has selected -d.
        NEW=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}N.zip
        CHANGE=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}C.zip
        UPDATE=$WORK_DIR_AN/${INSTITUTION}${FILE_DATE}U.zip
        test_requires
        process_zipped $UPDATE
        ;;
	x)	usage
		;;
    *)	echo "**error invalid option specified '$opt'" >&2
		;;
  esac
done
exit $TRUE
# EOF 


