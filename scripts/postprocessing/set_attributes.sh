#!/bin/bash

#PBS -N TRENDY_postprocessing
#PBS -P rp23
#PBS -q normal
#PBS -l walltime=18:00:00
#PBS -l mem=64GB
#PBS -l ncpus=1
#PBS -l storage=gdata/rp23+gdata/x45+gdata/xp65+gdata/ct11
#PBS -l software=netCDF:MPI:Intel:GNU
#PBS -r y
#PBS -l wd
#PBS -j oe
#PBS -S /bin/bash

# Skript to delete and set global attributes for TRENDY netcdf output files
# Note that this is a temporary script. Its functionality needs to be 
# integrated into the 'postprocess_TRENDY.sh' script in the future!


### Modules
module load nco/5.0.5


### ------------------------------------------------------------------------------------------------
### Settings 
### ------------------------------------------------------------------------------------------------
simdir="/g/data/rp23/experiments/2024-07-01_TRENDYv13"   # Location of TRENDY outputs (main folder)

exp="S0"  # experiment to postprocess

vars="nbp nbppft mrro mrso evapotrans cVeg cSoil gpp ra rh lai tas pr rsds evapotranspft transpft evapo albedopft snow_depthpft shflxpft rnpft cLitter cVegpft cSoilpft soilr rhpft laipft landCoverFrac oceanCoverFrac cLeaf cWood cRoot cCwd tsl msl evspsblveg evspsblsoi tskinpft mslpft theightpft"  # Part 2
#vars="fVegLitter fLeafLitter fWoodLitter fRootLitter fVegSoil fNdep fBNF fNup fNnetmin nSoil nOrgSoil nInorgSoil fNloss nVeg nLeaf nWood nRoot nLitter cSoilpools fAllocLeaf fAllocWood fAllocRoot" # Part 3
#vars="cProduct fLuc"  # S3 only


## global attributes
creation_date=$(date)
source_code="https://github.com/CABLE-LSM/CABLE/tree/CABLE-POP_TRENDY"
commit="e190b23"
institution="CSIRO Environment; Western Sydney University"
contact="Juergen Knauer (J.Knauer@westernsydney.edu.au); Ian Harman (ian.harman@csiro.au)"



### ----------------------------------------------------------------------------------------------
### Start Script
### ----------------------------------------------------------------------------------------------

## switch to output folder
cd ${simdir}/upload/${exp}

for var in ${vars} ; do
	
	outfile="CABLE-POP_${exp}_${var}.nc"

	## first delete all added global attributes
	ncatted -O -a source_code,global,d,,   ${outfile}
	ncatted -O -a institution,global,d,,   ${outfile}
	ncatted -O -a contact,global,d,,       ${outfile}
	ncatted -O -a commit,global,d,,        ${outfile}
	ncatted -O -a creation_date,global,d,, ${outfile}
	ncatted -O -a Production,global,d,,    ${outfile}
		

	## add attributes in the right order
	ncatted -O -a creation_date,global,c,c,"${creation_date}" ${outfile}
	ncatted -O -a source_code,global,c,c,"${source_code}" ${outfile}
	ncatted -O -a commit,global,c,c,"${commit}" ${outfile}
    ncatted -O -a institution,global,c,c,"${institution}" ${outfile}
    ncatted -O -a contact,global,c,c,"${contact}" ${outfile}

	## compress file --> test: does compression level stay the same?
	#cdo -z zip_${compression} copy tmp.nc ${outfile}

	## give permissions
	chmod 775 ${outfile}

	# delete history
	ncatted -h -a history,global,d,c, ${outfile}
	#ncatted -h -a history_of_appended_files,global,d,c, ${outfile}

done