#!/usr/bin/env bash

#PBS -N climate_processing
#PBS -P rp23
#PBS -q normal
#PBS -l walltime=09:59:59
#PBS -l mem=8GB
#PBS -l ncpus=1
#PBS -l storage=gdata/rp23
#PBS -l software=netCDF:MPI:Intel:GNU
#PBS -r y
#PBS -l wd
#PBS -j oe
#PBS -S /bin/bash

# Script to process climate forcing data for CABLE-POP for use in TRENDY.
# Juergen Knauer, May/June 2024.

# The script downloads climate data from the Exeter server and processes them.
# The script assumes the following file structure:
#   basepath/input_orig  <- original data as downloaded from Exeter ftp server
#   basepath/input/met   <- processed files

# Note: two main differences to Peter's script (used until TRENDYv12):
#       - netcdf files are compressed rather than zipped.
#       - intermediate files (daily at 0.5deg) are not saved
# Note: aggregated variables contain a time_bnds variable that is kept for now to keep the script simpler

## TODO: revisit aggregation of fd (daymean) and consistency with other tswrf


## set up workspace
module purge
module load nco/5.0.5
module load cdo/2.0.5
module load netcdf/4.9.2

vars="dlwrf fd pre pres spfh tmax tmin tswrf ugrd vgrd"  # climate variables to process
vars="pre"
basepath="/g/data/rp23/experiments/2024-07-01_TRENDYv13"                     # absolute path where forcing files were downloaded to.
gridfile="/g/data/rp23/experiments/2024-07-01_TRENDYv13/aux/input.grid.1deg" # grid file used for TRENDY inputs (excluding everything below 60degS).
cruversion="crujra.v2.5.5d"                                                  # version name of CRUJRA product to be used
startyear=1901
endyear=2023
tsec=21600   # timestep of input in seconds (6 hourly = 21600s) 

# working directory
cd ${basepath}/input/met/
mkdir -p linked

for var in ${vars} ; do

    echo "processing variable ${var}"
    
    for ((year=${startyear};year<=${endyear};year++)) ; do
        
        echo "year ${year}"

        # pick the right file from the right folder 
        if [[ "${var}" == "fd" || "${var}" == "tswrf" ]] ; then
            basename="${var}_v13_${year}"
            filename=${basepath}/input_orig/Radiation/${basename}.nc.gz
        else 
            basename="${cruversion}.${var}.${year}.365d.noc"
            filename=${basepath}/input_orig/crujra2.5/${basename}.nc.gz
        fi
        linkname="${var}_${year}0101_${year}1231.nc"

        # copy to new folder and unzip
        cp $filename ${basename}.nc.gz
        gunzip ${basename}.nc.gz
        mv ${basename}.nc tmp.nc
        
        ## aggregate from 6-hourly to daily, change unit attribute if necessary, and aggregate to 1deg
        if [[ "${var}" == "pre" ]] ; then

            # first, calculate 6 hourly sums, then calculate daily sum of the 6-hourly sum
            cdo -O mulc,${tsec} tmp.nc tmp.sum.nc  # mm/6h
            cdo -O daysum tmp.sum.nc tmp.daytot.nc
            ncatted -O -a units,pre,m,c,"mm d-1" tmp.daytot.nc
            cdo -O -f nc4 -z zip_4 remapcon,${gridfile} tmp.daytot.nc ${basename}.daytot.1deg.nc
            ln -sfr ${basename}.daytot.1deg.nc linked/${linkname}

        elif [[ "${var}" == "tmax" ]] ; then

            # extract daily maximum
            cdo -O -m 9.96921e+36 daymax tmp.nc tmp.daymax.nc     
            cdo -O -f nc4 -z zip_4 remapcon,${gridfile} tmp.daymax.nc ${basename}.daymax.1deg.nc 
            ln -sfr ${basename}.daymax.1deg.nc linked/${linkname}
        
        elif [[ "${var}" == "tmin" ]] ; then
        
            # extract daily minimum
            cdo -O -m 9.96921e+36 daymin tmp.nc tmp.daymin.nc      
            cdo -O -f nc4 -z zip_4 remapcon,${gridfile} tmp.daymin.nc ${basename}.daymin.1deg.nc 
            ln -sfr ${basename}.daymin.1deg.nc linked/${linkname}

        else    
        
            # calculate daily mean 
            cdo -O daymean tmp.nc tmp.daymean.nc
            cdo -O -f nc4 -z zip_4 remapcon,${gridfile} tmp.daymean.nc ${basename}.daymean.1deg.nc
            ln -sfr ${basename}.daymean.1deg.nc linked/${linkname}

        fi

    done  # year loop

done  # vari#able loop

## link Ndep file
# 

## link CO2 file

# cleanup
rm tmp.nc tmp.*.nc