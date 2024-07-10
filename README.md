[//]: # (Author: Lachlan Whyborn, Matthias Cuntz)
[//]: # (Date Modified: 2024-07-08)

# TRENDY v12 Experiment Configuration

This repository contains the auxiliary scripts required to run the TRENDY configuration on the RP23 NCI project on Gadi and on the biocomp cluster with files in /home/mcuntz.

## Usage

Copy these scripts to do the desired run directory. On Gadi, access to the HH5 project is also required to run the python landmask script. On biocomp, a valid anaconda environment with the name pystd is assumed. The changes needed to be made by the user are in the ```run_TRENDY.sh``` script and are:

* Specify the location of the ```cable``` repository, by setting the ```cablecode``` variable on line 46.
* Set the experiment to run by setting the ```experiment``` variable on line 26. The experiment names correspond to a set of internal configuration options.

The changes in this branch as compared to the trunk reflect a series of changes to the Met input routines which are currently contained in CABLE PR [290](https://github.com/CABLE-LSM/CABLE/pull/290). The changes are a first pass at making the input routines generalised. The namelist options ```Run``` and ```MetVersion``` that set a series of options inside the code have been removed, and replaced with options in ```cru.nml``` which permit the same behaviour.

The Met files are required to be named with a certain format, that contains the start and end date of the data in the given file in YYYYMMDD format. The start and end dates are represented by <startdate> and <enddate> in the namelist option. Taking an example from the most recent TRENDY version, the file ```crujra.v2.4.5d.pre.1901.365d.noc.daytot.1deg.nc``` can be symlinked to ```precip-19010101-19011231.nc```, and the ```rainFile``` namelist option set to ```precip-<startdate>-<enddate>.nc``` to allow it to be read by the new routines. This also handles files which span multiple years (but for now, only files which contain full years). This should allow easier substituting in and out of different Met forcing datasets.

The possible internal names for each Met variable are handled by pre-preparing a set of possible Met names stored in ```namelists/met_names.nml```, which contains the possible NetCDF variable names to check for.

A summary of the new namelist options in the ```cru.nml``` are:
* <variable>File: ```CHARACTER(256)```, template matching the set of files for a given met variable. Includes ```NDep```. Defaults to ```"None"```.
* CO2File: ```CHARACTER(256)```, location of the CO2 file. Given that the CO2 values are currently stored in a columnated text file, it does not yet require the templated format. Defaults to ```"None"```.
* LandmaskFile: ```CHARACTER(256)```, location of the landmask file. Defaults to ```"None"```.
* <variable>Recycle: ```LOGICAL```, whether the given variable is recycled. Defaults to ```.FALSE.```.
* CO2Method: ```CHARACTER(16)```, method for choosing the CO2 values. Either "Yearly" to read the current run year, or the desired year as a string. Defaults to ```"Yearly"```.
* NDepMethod: ```CHARACTER(16)```, method for choosing the NDep values. Either "Yearly" to read the current run year, or the desired year as a string. Defaults to ```"Yearly"```.
* LeapYears: ```LOGICAL```, whether the Met dataset contains leap years. Defaults to ```.FALSE.```
* DtHrs: ```REAL```, time step in hours. Defaults to ```3.0```.
* MetRecyc: ```INTEGER```, period for the met recycling. Defaults to ```20```.
* ReadDiffFrac: ```LOGICAL```, whether to read the diffusive fraction from file or allow CABLE to calculate it. Defaults to ```.TRUE.```.
* Directread: ```LOGICAL```, whether to read the Met data directly from NetCDF files into vectors, or read into an array then into vectors. Defaults to ```.FALSE.```.

The ```run_cable.sh``` script has been modified to appropriately change the ```cru.nml``` namelist options for the different scenarios 0 through 3.

## Resources

The default job configuration, with 100 parallel runs, takes ~8 hours, 450GB of memory and ~12000 files, so ensure that the file system you are running on has the required resources.
