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
            help="Number of pseudo-parallel runs used"
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

def merge_outputs(Experiment, NRuns, YearPeriod, File):
    """Merge the outputs from each of the pseudo-parallel runs into a single
    file."""

    # Start by generating the file path templates
    Landmask = lambda n: "{Experiment}/run{n}/landmask/landmask{n}.nc"
    Output = lambda n: "{Experiment}/run{n}/outputs/{File}_{YearPeriod}.nc"

    # Get the first landmask to use as reference for grid
    RefLandmask = xarray.open_dataset(Landmask(1))
    GlobalLongitudes = RefLandmask["longitude"]
    GlobalLatitudes = RefLandmask["latitude"]

    # Choose which variables to exclude from the output
    ExcludeVars = ["longitude", "latitude", "local_lon", "local_lat", "x", "y"]

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
        Arr = numpy.array(DimSizes, dtype=RefOutput[Var].encoding['dtype'])
        DataVarMapping[Var] = (VarDims, Arr, RefOutput[Var].attrs)
    
    # Also set up the coords argument, which has similar requirements
    # xarray doesn't allow coordinates with values, so just range the ones
    # which don't exist in CABLE
    CoordMapping = {}
    Coords = [Coord for Coord in RefOutput.dims if Coord /= "land"]
    for Coord in Coords:
        
    # Set up the Dataset to write to
    WriteDataset = xarray.Dataset(




