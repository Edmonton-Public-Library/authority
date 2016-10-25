####################################################
# Makefile for project authority 
# Created: Mon Dec 22 10:07:38 MST 2014
#
#<one line to give the program's name and a brief idea of what it does.>
#    Copyright (C) 2015  Andrew Nisbet
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
# Written by Andrew Nisbet at Edmonton Public Library
# Rev: 
#      0.1 - Change copyright date. 
#      0.0 - Dev. 
####################################################
# Change comment below for appropriate server.
PRODUCTION_SERVER=eplapp.library.ualberta.ca
TEST_SERVER=edpl-t.library.ualberta.ca
USER=sirsi
REMOTE=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesFromBackStage/
REMOTE_CREATE=/s/sirsi/Unicorn/EPLwork/cronjobscripts/Authorities/FilesForBackStage/
LOCAL=~/projects/authority/
APP=authority.pl
AUTH_BOT=authbot.sh
AUTH_CREATE=PrepareAndTransferBIBsAndAuthsToBackstage.pl
ARGS=-x
.PHONY: compile test production all

compile:
	perl -c ${APP}
	perl -c ${AUTH_CREATE}

test: ${LOCAL}${AUTH_BOT} ${LOCAL}${APP} compile
	scp ${LOCAL}${AUTH_BOT} ${USER}@${TEST_SERVER}:${REMOTE}
	scp ${LOCAL}${APP} ${USER}@${TEST_SERVER}:${REMOTE}
	scp ${LOCAL}${AUTH_CREATE} ${USER}@${TEST_SERVER}:${REMOTE_CREATE}

production: ${LOCAL}${AUTH_BOT} ${LOCAL}${APP} compile 
	scp ${LOCAL}${AUTH_BOT} ${USER}@${PRODUCTION_SERVER}:${REMOTE}
	scp ${LOCAL}${APP} ${USER}@${PRODUCTION_SERVER}:${REMOTE}
	scp ${LOCAL}${AUTH_CREATE} ${USER}@${PRODUCTION_SERVER}:${REMOTE_CREATE}

all: compile test production