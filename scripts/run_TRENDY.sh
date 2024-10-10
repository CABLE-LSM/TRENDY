#!/usr/bin/env bash

# This script starts multiple sessions of the CABLE run script, each time using different land masks and output folders
# Before running this script, the following needs to be checked in the CABLE run script:
# PBS settings, Run sequence, CABLE settings 

# Script requires the following files
# landmask_script --> creates landmasks
#
# run_script      --> runs CABLE instances
#     - requires run_cable-pop_lib.sh
# merge_script    --> merges CABLE outputs to latlon grid
#     - requires merge_to_output2d.py 
# cleanup script  --> cleans up folder structure

#-------------------------------------------------------
# Modules
#-------------------------------------------------------
module purge
module load R/4.2.2
module load python3/3.10.4
module load proj/6.2.1
module load gdal/3.0.2
module load geos/3.8.0
module load intel-compiler/2021.8.0
export R_LIBS=/g/data/x45/R/libs
export PYTHONPATH=/g/data/x45/python3.10.4/lib/python3.10/site-packages


#-------------------------------------------------------
# Settings
#-------------------------------------------------------
experiment="S0"
experiment_name="${experiment}"
run_model=1       # run the model or just do other steps (e.g. merging)?
merge_results=1   # after runs are finished, merge results into one folder and backup 
                  # restart, logs, landmasks etc. (1) or keep folder structure as it is (0).
                  # The latter is useful if runs are to be resumed from restart files. 
#mergesteps="zero_biomass spinup_nutrient_limited_1 spinup_nutrient_limited_2 1700_1900 1901_2023"   # sub-steps to be merged
mergesteps="1700_1900 1901_2023"

### Spatial subruns ###
create_landmasks=1               # create new landmask files (1) or use existing ones (0)?
nruns=100                         # number of runs in parallel
extent="global"                  # "global" or "lon_min,lon_max,lat_min,lat_max"
#extent="-2.0,25.0,35.0,60.0"     # Europe
#extent="-102.6,-96.4,37.4,39.6"       # USA
climate_restart="cru_climate_rst"       # name of climate restart file (without file extension)
keep_dump=1                             # keep dump files (1) or discard (0)? They are always kept for LUC runs


### Directories and files###
# Output directory
outpath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/${experiment_name}"
# Code directory
cablecode="/home/599/jk8585/CABLE_code/CABLE-POP_TRENDY"
# Run directory
rundir="/home/599/jk8585/CABLE_run/TRENDY_v13"
# Scripts
landmask_script="${rundir}/scripts/split_landmask.R"
run_script="${rundir}/scripts/run_cable.sh"
merge_script="${rundir}/scripts/merge_outputs.sh"
cleanup_script="${rundir}/scripts/cleanup.sh"
# Cable executable
exe="${cablecode}/bin/cable"

# Append the location of the cablepop python module to the PYTHONPATH
export PYTHONPATH=${cablecode}/scripts:${PYTHONPATH}
# CABLE-AUX directory (uses offline/gridinfo_CSIRO_1x1.nc and offline/modis_phenology_csiro.txt)
aux="/g/data/rp23/experiments/2024-07-01_TRENDYv13/aux"
# Global Meteorology
#GlobalMetPath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/input/v12/met"
GlobalMetPath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/input/met"
# Global LUC
#GlobalTransitionFilePath="/g/data/x45/LUH2/GCB_2023/1deg/EXTRACT"
#GlobalTransitionFilePath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/input/v12/luc/processed"
GlobalTransitionFilePath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/input/luc"
# Global Surface file 
SurfaceFile="${aux}/gridinfo_CSIRO_1x1.nc"   
# Global Land Mask
GlobalLandMaskFile="${aux}/landmasks/glob_ipsl_1x1.nc"
# vegetation parameters
filename_veg="${rundir}/params/def_veg_params.txt"
# soil parameters
filename_soil="${rundir}/params/def_soil_params.txt"
# casa-cnp parameters
casafile_cnpbiome="${rundir}/params/pftlookup.csv"

## ---------------------------- End Settings ---------------------------------- ## 
# OS and Workload manager
ised="sed --in-place=.old"  # Linux: "sed --in-place=.old" ; macOS/Unix: "sed -i .old"
pqsub="qsub"  # PBS: "qsub" ; Slurm: "sbatch --parsable"
# PBS: qsub -W "depend=afterok:id1:id2"
# Slurm: sbatch --dependency=afterok:id1:id2
function dqsub()
{
    # PBS
    echo "qsub -W \"depend=afterok${1}\""
    # # Slurm
    # echo "sbatch --parsable --dependency=afterok${1}"
}
ntag="PBS -N "  # PBS: "PBS -N " ; Slurm: "SBATCH --job-name="

# -----------------------------------------------------------------------
# 1) Create landmasks (created in folders ${outpath}/runX/landmask)
# -----------------------------------------------------------------------
if [[ ${create_landmasks} -eq 1 ]] ; then
    echo "Create landmasks"
    ${landmask_script} ${GlobalLandMaskFile} ${nruns} ${outpath} ${extent}
    echo "Finished creating landmasks"
fi

# -----------------------------------------------------------------------
# 2) Run CABLE
# -----------------------------------------------------------------------
RUN_IDS=
if [[ ${run_model} -eq 1 ]] ; then
    echo "Submit model runs"
    # 2.1) Write general settings into run script
    ${ised} -e "s|^#${ntag}.*|#${ntag}${experiment_name}|" ${run_script}
    ${ised} -e "s|^experiment=.*|experiment='${experiment}'|" ${run_script}
    ${ised} -e "s|^experiment_name=.*|experiment_name='${experiment_name}'|" ${run_script}
    ${ised} -e "s|^cablecode=.*|cablecode='${cablecode}'|" ${run_script}
    ${ised} -e "s|^rundir=.*|rundir='${rundir}'|" ${run_script}
    ${ised} -e "s|^exe=.*|exe='${exe}'|" ${run_script}
    ${ised} -e "s|^aux=.*|aux='${aux}'|" ${run_script}
    ${ised} -e "s|^MetPath=.*|MetPath='${GlobalMetPath}'|" ${run_script}
    ${ised} -e "s|^TransitionFilePath=.*|TransitionFilePath='${GlobalTransitionFilePath}'|" ${run_script}
    ${ised} -e "s|^SurfaceFile=.*|SurfaceFile='${SurfaceFile}'|" ${run_script}
    ${ised} -e "s|^filename_veg=.*|filename_veg='${filename_veg}'|" ${run_script}
    ${ised} -e "s|^filename_soil=.*|filename_soil='${filename_soil}'|" ${run_script}
    ${ised} -e "s|^casafile_cnpbiome=.*|casafile_cnpbiome='${casafile_cnpbiome}'|" ${run_script}
    ${ised} -e "s|^ised=.*|ised='${ised}'|" ${run_script}

    # 2.2) Loop over landmasks and start runs
    for ((irun=1; irun<=${nruns}; irun++)) ; do
        #irun=1
        runpath="${outpath}/run${irun}"
        ${ised} -e "s|^runpath=.*|runpath='${runpath}'|" ${run_script}
        ${ised} -e "s|^LandMaskFile=.*|LandMaskFile='${runpath}/landmask/landmask${irun}.nc'|" ${run_script}
        RUN_IDS="${RUN_IDS}:$(${pqsub} ${run_script})"
    done

    if [[ -f ${run_script}.old ]] ; then rm ${run_script}.old ; fi

    echo "Submitted model jobs ${RUN_IDS}"
fi

# -----------------------------------------------------------------------
# 3) Merge outputs (only if all previous runs were OK)
# -----------------------------------------------------------------------
if [[ ${merge_results} -eq 1 ]] ; then
    echo "Submit merge jobs"
    ftypes="cable casa LUC"
    outfinal="${outpath}/output"
    if [[ -d ${outfinal} ]] ; then
        rm -r ${outfinal}
    fi
    mkdir -p ${outfinal}

    for mergestep in ${mergesteps} ; do
        for ftype in ${ftypes} ; do
            if [[ ("${ftype}" != "LUC") || ("${experiment}" == "S3" && ("${mergestep}" == "1700_1900" || "${mergestep}" == "1901_"* )) ]] ; then
                ${ised} -e "s|^#${ntag}.*|#${ntag}${experiment_name}_merge|" ${merge_script}
                ${ised} -e "s|^python3.*|python3 ${rundir}/scripts/aux/merge_to_output2d.py -v -z -o ${outfinal}/cru_out_${ftype}_${mergestep}.nc ${outpath}/run*/outputs/cru_out_${ftype}_${mergestep}.nc|" ${merge_script}
                if [[ ${run_model} -eq 1 ]] ; then
                    #MERGE_IDS="${MERGE_IDS}:$($(dqsub ${RUN_IDS}) ${merge_script})"
                    MERGE_IDS="${MERGE_IDS}:$(qsub -W "depend=afterok${RUN_IDS}" $merge_script)"
                else
                    #MERGE_IDS="${MERGE_IDS}:$(${pqsub} ${merge_script})"
                    MERGE_IDS="${MERGE_IDS}:$(qsub $merge_script)"
                fi
            fi
        done
    done

    if [[ -f ${merge_script}.old ]] ; then rm ${merge_script}.old ; fi

    echo "Submitted merge jobs ${MERGE_IDS}"

    # -----------------------------------------------------
    # 4) Backup and cleanup
    # -----------------------------------------------------

    echo "Submit cleaning job"
    ${ised} -e "s|^exp_name=.*|exp_name='${experiment_name}'|" ${cleanup_script}
    ${ised} -e "s|^outpath=.*|outpath='${outpath}'|" ${cleanup_script}
    ${ised} -e "s|^nruns=.*|nruns=${nruns}|" ${cleanup_script}
    ${ised} -e "s|^climate_restart=.*|climate_restart='${climate_restart}'|" ${cleanup_script}
    ${ised} -e "s|^keep_dump=.*|keep_dump=${keep_dump}|" ${cleanup_script}
    ${ised} -e "s|^mergesteps=.*|mergesteps='${mergesteps}'|" ${cleanup_script}

    CLEAN_ID=$(eval $(dqsub ${MERGE_IDS}) ${cleanup_script})

    if [[ -f ${cleanup_script}.old ]] ; then rm ${cleanup_script}.old ; fi

    echo "Submitted clean job ${CLEAN_ID}"
fi

exit
