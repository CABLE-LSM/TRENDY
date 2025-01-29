#!/usr/bin/env bash

# Gadi
# https://opus.nci.org.au/display/Help/How+to+submit+a+job
#PBS -N CABLE_merge
#PBS -P rp23
#PBS -q express
#PBS -l walltime=09:30:00
#PBS -l mem=16GB
#PBS -l ncpus=1
#PBS -l storage=gdata/rp23+scratch/rp23+gdata/hh5
#PBS -l software=netCDF:MPI:Intel:GNU:scorep
#PBS -r y
#PBS -l wd
#PBS -j oe
#PBS -S /bin/bash
#PBS -v PYTHONPATH

# This line is replaced with the appropriate target during run

source ${HOME}/TRENDY_env/bin/activate
python3 /g/data/rp23/experiments/2024-04-17_BIOS3-merge/lw5085/BIOS_through_TRENDY/merge_to_output2d.py -v -z -o /g/data/rp23/experiments/2024-04-17_BIOS3-merge/lw5085/BIOS_through_TRENDY/S0/output/bios_out_casa_1901_2022.nc /g/data/rp23/experiments/2024-04-17_BIOS3-merge/lw5085/BIOS_through_TRENDY/S0/run*/outputs/bios_out_casa_1901_2022.nc
