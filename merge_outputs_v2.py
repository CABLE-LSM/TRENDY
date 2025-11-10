def parse_args():
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
            "-f",
            "--file",
            help="Which file to merge"
            )

    return parser.parse_args()

def insert_data(output_dataset, run_output, landmask):
    """Take the data from run_output and insert it into output_dataset using the mask
    defined by the given landmask."""

    # Get the point locations from the landmask. These will always represent the last
    # 2 dimensions of the array.
    point_locations = [tuple(point) for point in numpy.argwhere(landmask["land"])]

    # Now iterate through the variables we want to output- again, need to exclude some
    # variables
    exclude_vars = ["local_lat", "local_lon", "latitude", "longitude"]
    for var in output_dataset.data_vars:
        if var not in exclude_vars:
            # We need to create the slice for the non-space dimensions. This is effectively
            # a tuple of (:, :, ...) of length equal to the non-space dimensions of the
            # variable. This is then added to the points extracted from the mask to create
            # an indexer of (:, :, ..., lat, lon) for each point in the mask.
            leading_dims = tuple(slice(None) for _ in range(run_output[var].dims[:-1]))
            for pt_id, point in enumerate(point_locations):
                output_dataset[var][leading_dims + point] = \
                        run_output_var[leading_dims + (pt_id,)]

def merge_outputs(experiment, nruns, file):
    """Merge the outputs from the specified stage from the given experiment
    that was run with nruns."""

    # Create the file templates
    landmask_file = lambda n: f"{Experiment}/run{n}/landmask/landmask{n}.nc"
    run_output_file = lambda n: f"{Experiment}/run{n}/outputs/{file}.nc"

    # Get the first landmask to use as reference for grid
    ref_landmask = xarray.open_dataset(landmask_file(1))
    global_longitudes = ref_landmask["longitude"]
    global_latitudes = ref_landmask["latitude"]

    # Create the new dataset that will be filled with the respective runs
    # For that, we'll need to open a reference output to get the list of variables
    ref_output = xarray.open_dataset(run_output_file(1))

    # Set up the coordinates dimensions and variables. Note this isn't the full set of
    # dimensions, just the ones that are assigned coordinates in standard CABLE output.
    # The remaining dimensions without coordinates (patch, soil, rad, pools) will be
    # created automatically during creation of the variables
    coordinate_mapping = {
            "x"     : ref_landmask["longitude"],
            "y"     : ref_landmask["latitude"],
            "time"  : ref_output["time"],
            }

    # The vector outputs from each stage additionally have x and y variables which
    # we don't want to include, and latitude/longitude that we'll fill from the
    # landmask definition. Time will also be handled in a bespoke fashion
    exclude_vars = ["x", "y", "latitude", "longitude", "local_lat", "local_lon", "time"]

    # Create the dictionary of NetCDF variables
    data_var_mapping = {}
    for var in ref_output.data_vars:
        if var not in exclude_vars:
            # Drop the "land" dimension, which is the last dimension, and add ("y", "x")
            var_dims = ref_output[var].dims[:-1] + ("y", "x")
            dim_sizes = tuple([ref_output[dim].size for dim in var_dims])

            # Create the new array to store the data, using the reference data type
            data_arr = numpy.ndarray(dim_sizes, dtype=ref_output[var].encoding['dtype'])

            # Now we can create the required tuple used to build NetCDF variables with xarray
            data_var_mapping[var] = (var_dims, data_arr, ref_output[var].attrs)

    # Now we can create the dataset, and begin filling it
    output_dataset = xarray.Dataset(
            data_vars=data_var_mapping,
            coords=coordinate_mapping
            )

    # Fill in the data from each of the runs
    for run in range(1, nruns+1):
        insert_data(output_dataset, run_output_file(run), landmask_file(run))

    # Write to disk
    output_dataset.to_netcdf(f"{experiment}/output/{stage}.nc")

if __name__ == "__main__":
    args = parse_args()

    merge_outputs(args.experiment, args.nruns, args.file)
