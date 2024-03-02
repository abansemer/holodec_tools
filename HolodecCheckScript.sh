#!/bin/bash

DiskNumber="05"
FlightID="RF02"

###################### Don't Modify below here ######################
Drive1="/Volumes/Holodec"$DiskNumber"A/CAESER/"$FlightID"/"
Drive2="/Volumes/Holodec"$DiskNumber"B/CAESER/"$FlightID"/"

# Checking if the files are the same on both drives
echo "================ Checking Contents of Drive 1 ================" 
rsync -av --dry-run --ignore-existing $Drive2 $Drive1
echo "================ Checking Contents of Drive 2 ================" 
#rsync -av --dry-run --ignore-existing $Drive1 $Drive2

# Checking the number of files 
echo "===================Checking Number of Files===================" 
Files1=$(find $Drive1 -type f | wc -l)
Files2=$(find $Drive2 -type f | wc -l)
echo "Drive 1 has:" $Files1 "files"
echo "Drive 2 has:" $Files2 "files"
#####################################################################

