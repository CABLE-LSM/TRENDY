#!/usr/bin/env bash

#PBS -N LUH2_processing
#PBS -P rp23
#PBS -q normal
#PBS -l walltime=04:30:00
#PBS -l mem=64GB
#PBS -l ncpus=1
#PBS -l storage=gdata/x45+gdata/rp23
#PBS -l software=netCDF:MPI:Intel:GNU
#PBS -r y
#PBS -l wd
#PBS -j oe
#PBS -S /bin/bash

# Script to process LUH2 data for CABLE-POP for use in TRENDY.
# Juergen Knauer, May 2024. Gives identical results (+/- numerical precision) 
# compared to Peter Briggs' original scripts.

# The file assumes that LUH2 data are downloaded manually (see TRENDY protocol for location)
# there should be three files: management.nc, states.nc, and transitions.nc.
# management.nc is currently not used

## TODO:
# -check in how far wood harvest should be considered in creation of prim_only file.

## Change log:
# 20 June 24: - primaryf renamed to primary_veg. secondaryf renamed to secondary_veg.
#             - secdn_to_pastr added to stog transition.
#             - primn_to_pastr added to ptog transition.
# 29 July 24: - primf_to_secdn added to ptos transition.
#             - 6 new transitions added (all happening within CABLE-POPs 'grass' land use type):
#                ctor: crop to rangeland (representing crop abandonment).
#                qtor: pasture to rangeland (representing pasture abondonment).
#                rtoc: rangeland to crop.
#                rtoq: rangeland to pasture.
#                qtoc: pasture to crop.
#                ctoq: crop to pasture.
# 05 Aug 24:  - manually set values for missing grid cell at lon,lat 95.5, 76.5
# 07 Aug 24:  - added generation of prim_only.nc file


## set up workspace
module purge
module load nco/5.0.5
module load cdo/2.0.5
module load netcdf/4.9.2

#files="management.nc states.nc transitions.nc"
files="states.nc transitions.nc"
filepath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/input_orig/luh2"       # absolute path where unprocessed files were downloaded to.
outpath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/input/luc"              # absolute path for processed files.
gridfile="/g/data/rp23/experiments/2024-07-01_TRENDYv13/aux/input.grid.1deg"   # grid file used for TRENDY inputs (excluding everything below 60degS).

startyear=1580
endyear=2024   # note that LUH2 goes one year longer than climate data! (e.g. until 2024 for GCB2024)
#endyear=$(ncap2 -v -O -s 'print(time.size(),"%ld\n");' ${filepath}/states.nc tmptime.nc) # last year of time series = size of time dimension
missval=-9999

mkdir -p $outpath
cd $outpath

for file in ${files} ; do
    
    ## 1) select time period of interest, set time axis to years since 1580 and set calendar.
    # latitude and longitude dimensions are renamed to lat and lon (the variables latitude(lat) and longitude(lon) remain). 

    # The transitions file always has one less data record than the others.
    if [[ "${file}" == "transitions.nc" ]] ; then
        endyear_file=$(echo "${endyear} - 1" | bc)
    else 
        endyear_file=${endyear}
    fi

    cp ${filepath}/${file} ${outpath}/${file}
    #ncks -O -d time,${startyear},${endyear_file} ${file} tmp.nc
    cdo -O -f nc4 selyear,${startyear}/${endyear_file} ${file} tmp.nc
    cdo -O -f nc4 setmissval,${missval} tmp.nc tmp1.nc  # adjusts variable attributes as well
    cdo -O -f nc4 -settaxis,${startyear}-01-01,00:00:00,1year tmp1.nc tmp2.nc

    ## 2) Aggregate from 0.25 to 1 degree using conservative remapping
    cdo -O -z zip_4 remapcon,${gridfile} tmp2.nc tmp3.nc
    #ncrename -d latitude,lat -d longitude,lon tmp2.nc

    ## 3) create prim_only file
    # The prim_only file identifies grid cells that are primary vegetation
    # throughout the entire simulation period. Those grid cells are ignored
    # in the LUC calculations of the model. 
    # A grid cell qualifies as 'prim_only' if it does not have transitions
    # from primary_veg to a different land use type since 850. We do not 
    # check primary_veg itself anymore because grid cells can have primary_veg < 1
    # if land fraction < 1.
    if [[ "${file}" == "transitions.nc" ]] ; then
        cdo -O -s remapcon,${gridfile} ${file} tmp_prim1.nc
        cdo -O -f nc4 setmissval,${missval} tmp_prim1.nc tmp_prim2.nc 
        
        # Important: make sure transitions below correspond to ptos and ptog conversions later!!
        ncap2 -O -s from_prim="primf_harv+primn_to_secdf+primn_harv+primf_to_secdn+
                            primf_to_c3ann+primf_to_c4ann+primf_to_c3per+primf_to_c4per+primf_to_c3nfx+primf_to_pastr+
                            primf_to_range+primn_to_c3ann+primn_to_c4ann+primn_to_c3per+primn_to_c4per+primn_to_c3nfx+
                            primn_to_pastr" -v --cnk_map rd1 tmp_prim2.nc tmp_prim3.nc
        cdo -O -s timsum tmp_prim3.nc tmp_prim4.nc
        cdo -O -s ltc,0.001 tmp_prim4.nc tmp_prim5.nc
        cdo -O -s chname,from_prim,prim_only tmp_prim5.nc tmp_prim6.nc  # change variable name
        ncwa -O -a time tmp_prim6.nc prim_only.nc                       # delete time dimension
        ncap2 -O -s "prim_only(13,275)=1" prim_only.nc prim_only.nc     # set one missing grid cell

        ncatted -O -a standard_name,prim_only,o,c,"prim_only" prim_only.nc
        ncatted -O -a long_name,prim_only,o,c,"prim_only" prim_only.nc
    fi

    # set optimal netcdf chunking
    # Note: This is now done as part of the ncap2 command below. Chunking can likely be improved!
    #nccopy -d0 -c longitude/64,latitude/64,time/1 tmp2.nc tmp3.nc

    ## 4) Aggregate land use classes into broader categories
    tmpfile="tmp3.nc"

    if [[ "${file}" == "management.nc" ]] ; then

        echo 'no variables extracted from management.nc!'

    elif [[ "${file}" == "states.nc" ]] ; then

        ## Note that primn and secdn are mixtures of grassy and woody vegetation, thus aren't attributed 
        ## to neither grass nor wood in preprocessing. Within CABLE-POP, vegetation is split into 
        ## woody and non-woody (grass) components according to biome information (BIOME-1 model from Prentice et al. 1992).
        ncap2 -O -s "grass=c3ann+c4ann+c3per+c4per+c3nfx+pastr+range" -v --cnk_map rd1 $tmpfile ${outpath}/grass.nc
        ncap2 -O -s "primary_veg=primf+primn"                         -v --cnk_map rd1 $tmpfile ${outpath}/primary_veg.nc
        ncap2 -O -s "secondary_veg=secdf+secdn"                       -v --cnk_map rd1 $tmpfile ${outpath}/secondary_veg.nc

        ncap2 -O -s "crop=c3ann+c4ann+c3per+c4per+c3nfx" -v --cnk_map rd1 $tmpfile ${outpath}/crop.nc
        ncap2 -O -s "past=pastr"                         -v --cnk_map rd1 $tmpfile ${outpath}/past.nc
        ncap2 -O -s "rang=range"                         -v --cnk_map rd1 $tmpfile ${outpath}/rang.nc

        # NOTE: this step might be specific for TRENDYv13 (2024) and not needed for other versions!!
        # Go through all the files again just to set the value for that missing grid cell...
        # All transitions and states set to 0 except for primary_veg.
        ncap2 -O -s "grass(:,13,275)=0.0" ${outpath}/grass.nc ${outpath}/grass.nc
        ncap2 -O -s "primary_veg(:,13,275)=1.0" ${outpath}/primary_veg.nc ${outpath}/primary_veg.nc
        ncap2 -O -s "secondary_veg(:,13,275)=0.0" ${outpath}/secondary_veg.nc ${outpath}/secondary_veg.nc
        ncap2 -O -s "crop(:,13,275)=0.0" ${outpath}/crop.nc ${outpath}/crop.nc
        ncap2 -O -s "past(:,13,275)=0.0" ${outpath}/past.nc ${outpath}/past.nc
        ncap2 -O -s "rang(:,13,275)=0.0" ${outpath}/rang.nc ${outpath}/rang.nc

    elif [[ "${file}" == "transitions.nc" ]] ; then
        
        ncap2 -O -s "pharv=primf_harv+primn_harv"  -v --cnk_map rd1 $tmpfile ${outpath}/pharv.nc
        ncap2 -O -s "smharv=secmf_harv+secnf_harv" -v --cnk_map rd1 $tmpfile ${outpath}/smharv.nc
        ncap2 -O -s "syharv=secyf_harv"            -v --cnk_map rd1 $tmpfile ${outpath}/syharv.nc

        # primf_harv is counted as a transition. That's because primary forest is assumed to transition into 
        # a secondary forest as soon as harvest takes place.
        ncap2 -O -s "ptos=primf_harv+primn_to_secdf+primn_harv+primf_to_secdn" -v --cnk_map rd1 $tmpfile ${outpath}/ptos.nc
        ncap2 -O -s "ptog=primf_to_c3ann+primf_to_c4ann+primf_to_c3per+primf_to_c4per+primf_to_c3nfx+primf_to_pastr+
                          primf_to_range+primn_to_c3ann+primn_to_c4ann+primn_to_c3per+primn_to_c4per+primn_to_c3nfx+
                          primn_to_pastr" -v --cnk_map rd1 $tmpfile ${outpath}/ptog.nc
        ncap2 -O -s "stog=secdf_to_c3ann+secdf_to_c4ann+secdf_to_c3per+secdf_to_c4per+secdf_to_c3nfx+secdf_to_pastr+
                          secdf_to_range+secdn_to_c3ann+secdn_to_c4ann+secdn_to_c3per+secdn_to_c4per+secdn_to_c3nfx+
                          secdn_to_pastr" -v --cnk_map rd1 $tmpfile ${outpath}/stog.nc
        ncap2 -O -s "gtos=c3ann_to_secdf+c4ann_to_secdf+c3per_to_secdf+c4per_to_secdf+c3nfx_to_secdf+pastr_to_secdf+
                          range_to_secdf+c3ann_to_secdn+c4ann_to_secdn+c3per_to_secdn+c4per_to_secdn+c3nfx_to_secdn+
                          pastr_to_secdn+range_to_secdn" -v --cnk_map rd1 $tmpfile ${outpath}/gtos.nc
        ncap2 -O -s "ptoc=primf_to_c3ann+primf_to_c4ann+primf_to_c3per+primf_to_c4per+primf_to_c3nfx+primn_to_c3ann+
                          primn_to_c4ann+primn_to_c3per+primn_to_c4per+primn_to_c3nfx" -v --cnk_map rd1 $tmpfile  ${outpath}/ptoc.nc
        ncap2 -O -s "ptoq=primf_to_pastr+primn_to_pastr" -v --cnk_map rd1 $tmpfile  ${outpath}/ptoq.nc
        ncap2 -O -s "stoc=secdf_to_c3ann+secdf_to_c4ann+secdf_to_c3per+secdf_to_c4per+secdf_to_c3nfx+secdn_to_c3ann+
                          secdn_to_c4ann+secdn_to_c3per+secdn_to_c4per+secdn_to_c3nfx" -v $tmpfile --cnk_map rd1 ${outpath}/stoc.nc
        ncap2 -O -s "stoq=secdf_to_pastr+secdn_to_pastr" -v --cnk_map rd1 $tmpfile ${outpath}/stoq.nc
        ncap2 -O -s "ctos=c3ann_to_secdf+c4ann_to_secdf+c3per_to_secdf+c4per_to_secdf+c3nfx_to_secdf+c3ann_to_secdn+
                          c4ann_to_secdn+c3per_to_secdn+c4per_to_secdn+c3nfx_to_secdn" -v --cnk_map rd1 $tmpfile ${outpath}/ctos.nc
        ncap2 -O -s "qtos=pastr_to_secdf+pastr_to_secdn" -v --cnk_map rd1 $tmpfile ${outpath}/qtos.nc
        # new transitions added July 2024:
        # Note that these transitions only account for changes WITHIN the 'grass' land use type in CABLE-POP
        ncap2 -O -s "ctor=c3ann_to_range+c3nfx_to_range+c3per_to_range+c4ann_to_range+c4per_to_range" -v --cnk_map rd1 $tmpfile ${outpath}/ctor.nc
        ncap2 -O -s "rtoc=range_to_c3ann+range_to_c3nfx+range_to_c3per+range_to_c4ann+range_to_c4per" -v --cnk_map rd1 $tmpfile ${outpath}/rtoc.nc
        ncap2 -O -s "qtor=pastr_to_range" -v --cnk_map rd1 $tmpfile ${outpath}/qtor.nc
        ncap2 -O -s "rtoq=range_to_pastr" -v --cnk_map rd1 $tmpfile ${outpath}/rtoq.nc
        ncap2 -O -s "qtoc=pastr_to_c4per+pastr_to_c4ann+pastr_to_c3per+pastr_to_c3nfx+pastr_to_c3ann" -v --cnk_map rd1 $tmpfile ${outpath}/qtoc.nc
        ncap2 -O -s "ctoq=c4per_to_pastr+c4ann_to_pastr+c3per_to_pastr+c3nfx_to_pastr+c3ann_to_pastr" -v --cnk_map rd1 $tmpfile ${outpath}/ctoq.nc

        # see under 'states' what is happening here... 
        ncap2 -O -s "pharv(:,13,275)=0.0"  ${outpath}/pharv.nc ${outpath}/pharv.nc
        ncap2 -O -s "smharv(:,13,275)=0.0" ${outpath}/smharv.nc ${outpath}/smharv.nc
        ncap2 -O -s "syharv(:,13,275)=0.0" ${outpath}/syharv.nc ${outpath}/syharv.nc
        ncap2 -O -s "ptos(:,13,275)=0.0" ${outpath}/ptos.nc ${outpath}/ptos.nc
        ncap2 -O -s "ptog(:,13,275)=0.0" ${outpath}/ptog.nc ${outpath}/ptog.nc
        ncap2 -O -s "stog(:,13,275)=0.0" ${outpath}/stog.nc ${outpath}/stog.nc
        ncap2 -O -s "gtos(:,13,275)=0.0" ${outpath}/gtos.nc ${outpath}/gtos.nc
        ncap2 -O -s "ptoc(:,13,275)=0.0" ${outpath}/ptoc.nc ${outpath}/ptoc.nc
        ncap2 -O -s "ptoq(:,13,275)=0.0" ${outpath}/ptoq.nc ${outpath}/ptoq.nc
        ncap2 -O -s "stoc(:,13,275)=0.0" ${outpath}/stoc.nc ${outpath}/stoc.nc
        ncap2 -O -s "stoq(:,13,275)=0.0" ${outpath}/stoq.nc ${outpath}/stoq.nc
        ncap2 -O -s "ctos(:,13,275)=0.0" ${outpath}/ctos.nc ${outpath}/ctos.nc
        ncap2 -O -s "qtos(:,13,275)=0.0" ${outpath}/qtos.nc ${outpath}/qtos.nc
        ncap2 -O -s "ctor(:,13,275)=0.0" ${outpath}/ctor.nc ${outpath}/ctor.nc
        ncap2 -O -s "rtoc(:,13,275)=0.0" ${outpath}/rtoc.nc ${outpath}/rtoc.nc
        ncap2 -O -s "qtor(:,13,275)=0.0" ${outpath}/qtor.nc ${outpath}/qtor.nc
        ncap2 -O -s "rtoq(:,13,275)=0.0" ${outpath}/rtoq.nc ${outpath}/rtoq.nc
        ncap2 -O -s "qtoc(:,13,275)=0.0" ${outpath}/qtoc.nc ${outpath}/qtoc.nc
        ncap2 -O -s "ctoq(:,13,275)=0.0" ${outpath}/ctoq.nc ${outpath}/ctoq.nc
    fi

    # Notes:
    # - nothing can be converted back to its primary state (hence no *top exists)
    # - from the LUH2 guidelines: "all natural vegetation should be cleared for managed pasture, 
    #   and only cleared for rangeland if it is forested”.
    #   --> primn_to_range and secdn_to_range are not considered. I tried accounting for those 
    #       transitions but it would make the LU distribution worse (e.g. N Australia would be treeless)
    # - grass includes rangeland (rang), pasture (q), and crops (c). Therefore 'g' has to encompass c and q.
    #   --> qtos and ctos need to be a subset of gtos
    #   --> stoc and stoq need to be a subset of stog
    #   --> ptoq and ptoc need to be a subset of ptog
    # - in previous version, agricultural abandonment was not included if it was not converted to forest.
    #   Therefore, the following transitions were added:
    #   --> ctor: transition from cropland to rangeland (unmanaged grass)
    #   --> qtor: transition from pasture to rangeland (unmanaged grass)
    #   --> rtoc: transition from rangeland to cropland
    #   --> rtoq: transition from rangeland to pasture
    #   Note that these transitions only happen within the 'grass' land use type in CABLE-POP.
    # - the following transitions are ignored:
    #   --> all to and from urban
    #   --> secdn_to_secdf and secdf_to_secdn (because it would interfere with the woodfrac logic within CABLE-POP).
    #   --> primn_to_range and secdn_to_range (see above)

done

# Give permissions and remove intermediate files.
chmod 775 *.nc
rm tmp.nc tmp*.nc 
rm states.nc transitions.nc