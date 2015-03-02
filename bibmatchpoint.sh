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
#
############################################################################################
export HOME=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage
export LANG=en_US.UTF-8
export SHELL=/bin/bash

if [ $# -eq 1 ]; then
	if [ ! -s $1 ]; then
		echo "*error: the requested MARC file '$1' is empty."
		echo "usage: $0 <foo.mrc>"
		exit 1
	fi
else
	echo "*error: the name of the bib MARC file required."
	echo "usage: $0 <foo.mrc>"
	exit 1
fi


cat $1 | flatskip -im -a'MARC' -of | nowrap.pl > $1.flat
grep "^\.035\.   |a(Sirsi)" $1.flat | cut -d')' -f2 | sed -e 's/^[ \t]*//' | sort | uniq -u > $1.CatalogTag035s.lst
cat $1.CatalogTag035s.lst | seltext -lBOTH 2>/dev/null | sort | uniq -u > $1.CatalogKeys.lst
lookup_in_catalog=`cat $1.CatalogKeys.lst | wc -l`
cat $1 | marcanalyze >/dev/null 2>$1.err
cat $1.err | egrep -e '<marc> \$\(1402\)' | awk '{print $1}' >$1.tmp
analyse=`cat $1.tmp`
echo -e "  found: $lookup_in_catalog \ndelivered: $analyse"
rm $1.tmp $1.err
