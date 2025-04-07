import argparse
import numpy
import xarray

def _parse_args():
    """Read the command line arguments."""

    parser = argparse.ArgumentParser(
            prog="merge_outputs",
            description="Merge the outputs distributed across pseudo-" +\
                    "parallel runs into a single output files."
            )

    parser.add_argument(
            "-e",
            "--experiment",
            help="Experiment name"
            )

    parser.add_argument(
            "-n",
            "--nruns",
            help="Number of pseudo-parallel runs used",
            type=int
            )

    parser.add_argument(
            "-t",
            "--time",
            help="Years used to merge"
            )

    parser.add_argument(
            "-f",
            "--file",
            help="Which file to merge"
            )

    return parser.parse_args()

def insert_data(GlobalDataset, RunOutput, RunMask):
    """Take the output from RunOutput and place it into the relevant global
    indices as defined by the mask."""

    print(f"Trying to open {RunOutput} and {RunMask}")
    RunOutput = xarray.open_dataset(
            RunOutput,
            chunks=None,
            cache=True
            )
    RunMask = xarray.open_dataset(RunMask)

    # Quick check to make sure the data is valid
    assert RunOutput["time"].size == GlobalDataset["time"].size,\
            "Something went wrong- time dimensions are different between " +\
            "run output and global output."

    # Set up the actual mask as an array
    Mask = ~numpy.isnan(RunMask["land"].data)
    # Extract the indices belonging to this run
    RunInds = [Ind for Ind, Val in numpy.ndenumerate(Mask) if Val]

    # Fill in the variables
    for Var in RunOutput.data_vars:
        if Var not in ["latitude", "longitude"]:
            # Set the non-space dimensions to global slices
            LeadingDims = tuple((slice(None)
                        for _ in range(len(RunOutput[Var].dims)-1)))
            for (N, Ind) in enumerate(RunInds):
                GlobalDataset[Var][LeadingDims + Ind] = \
                         RunOutput[Var][LeadingDims + (N,)]

def merge_outputs(Experiment, NRuns, YearPeriod, File):
    """Merge the outputs from each of the pseudo-parallel runs into a single
    file."""

    # Start by generating the file path templates
    Landmask = lambda n: f"{Experiment}/run{n}/landmask/landmask{n}.nc"
    Output = lambda n: f"{Experiment}/run{n}/outputs/{File}_{YearPeriod}.nc"

    # Get the first landmask to use as reference for grid
    RefLandmask = xarray.open_dataset(Landmask(1))
    GlobalLongitudes = RefLandmask["longitude"]
    GlobalLatitudes = RefLandmask["latitude"]

    # Choose which variables to exclude from the output
    ExcludeVars = ["x", "y", "latitude", "longitude"]

    # Get the first output file to use as a reference to the variables
    RefOutput = xarray.open_dataset(Output(1))

    # We want to create a data structure to use as the data_vars argument for a
    # new xarray Dataset. This requires a dictionary of:
    # VarName : ((DimNames), array-like, attrs)
    DataVarMapping = {}
    DataVars = [Var for Var in RefOutput.data_vars if Var not in ExcludeVars]
    for Var in DataVars:
        # On the reference output, the spatial dimension is "land", so we want
        # all dimensions except the last
        VarDims = RefOutput[Var].dims[:-1] + ("y", "x")
        DimSizes = tuple([RefOutput[Dim].size for Dim in VarDims])
        Arr = numpy.ndarray(DimSizes, dtype=RefOutput[Var].encoding['dtype'])
        DataVarMapping[Var] = (VarDims, Arr, RefOutput[Var].attrs)
    
    # Also set up the coords argument, which has similar requirements
    # Exclude land, since it's only for the vector form
    CoordMapping = {}
    Coords = {Coord: RefOutput[Coord]
              for Coord in RefOutput.dims if Coord != "land"}
        
    # Set up the Dataset to write to
    WriteDataset = xarray.Dataset(
            data_vars=DataVarMapping,
            coords=CoordMapping
            )

    # Now retrieve and fill the data
    for Run in range(1, NRuns+1):
        insert_data(WriteDataset, Output(Run), Landmask(Run))

    WriteDataset.to_netcdf(f"{File}_{YearPeriod}.nc")

if __name__ == "__main__":
    args = _parse_args()

    merge_outputs(args.experiment, args.nruns, args.time, args.file)
