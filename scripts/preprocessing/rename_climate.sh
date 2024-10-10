

vars="dlwrf fd pre pres spfh tmax tmin tswrf ugrd vgrd"  # climate variables to process
basepath="/g/data/rp23/experiments/2024-07-01_TRENDYv13/"                     # absolute path where forcing files were downloaded to.
cruversion="crujra.v2.4.5d"
startyear=1901
endyear=2022

# working directory
cd ${basepath}/input/v12/met
mkdir -p linked

for var in ${vars} ; do

    echo "processing variable ${var}"
    
    for ((year=${startyear};year<=${endyear};year++)) ; do
        
        echo "year ${year}"

        # pick the right file from the right folder 
        if [[ "${var}" == "fd" || "${var}" == "tswrf" ]] ; then
            basename="${var}_v12_${year}"
            outname="${var}_v12_${year}0101_${year}1231"
        else 
            basename="${cruversion}.${var}.${year}.365d.noc"
            outname="${cruversion}.${var}.${year}0101_${year}1231.365d.noc"
        fi

        linkname="${var}_${year}0101_${year}1231.nc"
        ## rename
        if [[ "${var}" == "pre" ]] ; then

            ln -sfr ${outname}.daytot.1deg.nc linked/${linkname}
            #mv ${basename}.daytot.1deg.nc ${outname}.daytot.1deg.nc

        elif [[ "${var}" == "tmax" ]] ; then

            ln -sfr ${outname}.daymax.1deg.nc linked/${linkname}
            #mv ${basename}.daymax.1deg.nc ${outname}.daymax.1deg.nc
        
        elif [[ "${var}" == "tmin" ]] ; then

            ln -sfr ${outname}.daymin.1deg.nc linked/${linkname}
            #mv ${basename}.daymin.1deg.nc ${outname}.daymin.1deg.nc 

        else    
        
            ln -sfr ${outname}.daymean.1deg.nc linked/${linkname}
            #mv ${basename}.daymean.1deg.nc ${outname}.daymean.1deg.nc 

        fi

    done  # year loop

done  # variable loop
