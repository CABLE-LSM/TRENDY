#!/usr/bin/env bash

#PBS -N download_files
#PBS -P rp23
#PBS -q copyq
#PBS -l walltime=00:15:00
#PBS -l mem=32GB
#PBS -l ncpus=1
#PBS -l storage=gdata/x45+gdata/rp23
#PBS -r y
#PBS -l wd
#PBS -j oe
#PBS -S /bin/bash

# Script to download TRENDY forcing data.
# Written by Peter Campbell 6/7/2021
# He says: It will download the files into a CRUJRA2021 sub-directory of the directory you submit the job from.
# The mirror -c option tells it to continue the download from where it stopped in case you need to restart it.  
# The -P 3 option tells it to download 3 files in parallel.
# I created ~/.netrc with the username and password so you don't need to put the password into the script.

# Configuration
#username="user-20"
#hostname="trendydl.exeter.ac.uk"
extdir=trendy-gcb2024/input/   # external directory on Exeter server
outdir=/g/data/rp23/experiments/2024-07-01_TRENDYv13/input_orig/  ## target directory where files are downloaded to


###################################################
## Option A: Download everything in input folder ##
###################################################
lftp -c "open sftp://user-20@trendydl.exeter.ac.uk; mirror -c -P 3 \"$extdir\" \"$outdir\""

###############################################
## Option B: Download individual sub-folders ##
###############################################

## 1) meteorological forcing
#lftp -c "open sftp://user-20@trendydl.exeter.ac.uk; mirror -c -P 3 \"$extdir\"/crujra2.5 \"$outdir\""

## compress netcdf files here and convert to netcdf4!!

## 2) CO2 data
#lftp -c "open sftp://user-20@trendydl.exeter.ac.uk; mirror -c -P 3 \"$extdir\"/CO2field \"$outdir\""

## 3) N deposition
#lftp -c "open sftp://user-20@trendydl.exeter.ac.uk; mirror -c -P 3 \"$extdir\"/ndep \"$outdir\""



