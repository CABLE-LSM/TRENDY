#!/usr/bin/env bash

# Make links in format var_startdate_enddate.nc
# to the CRUJRA met files of TRENDY
#
# CO2 and nitrogen deposition are linked by hand (hard-coded below).
#
# Similar to Python script of Lachlan Whyborn
#    https://gist.github.com/Whyborn/97c57babc7a531e0605c9d44802a7ce1
#
# Written, Matthias Cuntz, July 2024
# Modified, adapted to Trendy v13 (2024), Sep 2024, Matthias Cuntz

set -e

# input/output directories
# Gadi - v12
# idir="/g/data/rp23/data/no_provenance/met_forcing/crujra_1x1_1d/v2.4/"
# odir="/g/data/rp23/experiments/2024-03-12_CABLE4-dev/lw5085/data_links/"
# biocomp - v12: if run in met directory daily_1deg
# idir=${PWD}
# odir=../daily_1deg_met
# biocomp - v13: downloaded from gadi:/g/data/rp23/experiments/2024-07-01_TRENDYv13
idir="/home/mcuntz/data/trendy_v13/input"
odir="/home/mcuntz/data/met_forcing/CRUJRA2024"

# final year
# # v12
# fyear=2022
# v13
fyear=2023


# make absolute from relative directories
cd ${idir}
idir=${PWD}
cd -

mkdir -p ${odir}
cd ${odir}
odir=${PWD}

# directories with meteo files (without co2 and ndep directories)
cd ${idir}
# # v12
# dirs=$(find . -maxdepth 1 -type d | sed -e 's|./||' -e 's|^[.]||' -e 's|co2||' -e 's|ndep||')
# v13
dirs=$(find . -maxdepth 1 -type d | sed -e 's|./||' -e 's|^[.]||' -e 's|co2||' -e 's|ndep||' -e 's|luc||')

for d in ${dirs} ; do
    mkdir -p ${odir}/${d}
    echo "Link files from ${idir}/${d} into ${odir}/${d}"
    # v12: for i in ${idir}/${d}/*${d}* ; do
    for i in ${idir}/${d}/*.nc ; do
	# v12
	# # filenames are like:
	# #    pres/crujra.v2.4.5d.pres.2022.365d.noc.daymean.1deg.nc
	# # or like
	# #    fd/fd_v12_2022.daymean.1deg.nc
        # yr=${i##*${d}}
        # if [[ ${i} == *crujra* ]] ; then
        #     yr=${yr:1:4}
        # else
        #     yr=${yr:5:4}
        # fi
	# echo ln ${i} ${odir}/${d}/${d}_${yr}0101_${yr}1231.nc
        # ln -sf ${i} ${odir}/${d}/${d}_${yr}0101_${yr}1231.nc

	# v13
	# filenames are like:
	#    /home/mcuntz/data/trendy_v13/input/met/crujra.v2.5.5d.pres.2022.365d.noc.daymean.1deg.nc
	# or like
	#    /home/mcuntz/data/trendy_v13/input/met/fd_v13_2022.daymean.1deg.nc
	ifile=$(basename ${i})
        if [[ ${i} == *crujra* ]] ; then
	    met=$(echo ${ifile} | cut -d '.' -f 5)
	    yr=$(echo ${ifile} | cut -d '.' -f 6)
        else
	    met=$(echo ${ifile} | cut -d '_' -f 1)
	    yr=$(echo ${ifile} | cut -d '_' -f 3)
            yr=${yr:0:4}
        fi
	echo ln ${i} ${odir}/${d}/${met}_${yr}0101_${yr}1231.nc
        ln -sf ${i} ${odir}/${d}/${met}_${yr}0101_${yr}1231.nc
    done
done

# Link co2 and nitrogen forcing by hand
mkdir -p ${odir}/co2
echo ln ${idir}/co2/global_co2_ann_1700_${fyear}.txt ${odir}/co2/co2_17000101_${fyear}1231.txt
ln -sf ${idir}/co2/global_co2_ann_1700_${fyear}.txt ${odir}/co2/co2_17000101_${fyear}1231.txt

mkdir -p ${odir}/ndep
echo ln ${idir}/ndep/NOy_plus_NHx_dry_plus_wet_deposition_1850_2099_annual.1deg.nc ${odir}/ndep/NDep_18500101_20991231.nc
ln -s ${idir}/ndep/NOy_plus_NHx_dry_plus_wet_deposition_1850_2099_annual.1deg.nc ${odir}/ndep/NDep_18500101_20991231.nc

exit
