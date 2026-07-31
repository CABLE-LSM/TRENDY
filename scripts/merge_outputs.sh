#!/usr/bin/env bash

# Gadi
# https://opus.nci.org.au/display/Help/How+to+submit+a+job
#PBS -N S0_merge
#PBS -P rp23
#PBS -q normal
#PBS -l walltime=06:30:00
#PBS -l mem=16GB
#PBS -l ncpus=1
#PBS -l storage=gdata/rp23+gdata/x45
#PBS -l software=netCDF:MPI:Intel:GNU:scorep
#PBS -r y
#PBS -l wd
#PBS -j oe
#PBS -S /bin/bash
#PBS -v PYTHONPATH

# This line is replaced with the appropriate target during run
python3 /home/599/jk8585/CABLE_run/TRENDY_v13/scripts/aux/merge_to_output2d.py -v -z -o /g/data/rp23/experiments/2024-07-01_TRENDYv13/S0/output/cru_out_casa_1901_2023.nc /g/data/rp23/experiments/2024-07-01_TRENDYv13/S0/run*/outputs/cru_out_casa_1901_2023.nc
