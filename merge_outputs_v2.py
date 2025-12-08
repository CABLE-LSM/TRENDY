import gc
import argparse
import xarray
import numpy

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

def build_variable(runs_var, runs_indices, grid_size):
    """Take the data from run_var and place it in output_var, using the run_indices to map
    from the vector to matrix format."""

    # Create the non-space dimension slices- these are effectively just ":" for
    # all dimensions bar space
    leading_dims = tuple([slice(None) for _ in range(runs_var[1].ndim - 1)])

    # Determine size of the array
    arr_size = tuple([runs_var[1].sizes[dim] for dim in runs_var[1].dims[:-1]])
    arr_size += grid_size
    output_var = numpy.ndarray(arr_size, dtype=runs_var[1].dtype)

    # Now for each point in the run's landmask, place the array of data in the
    # correct place
    for (run_var, run_indices) in zip(runs_var, runs_indices):
        for (pt_id, pt) in enumerate(run_indices):
            output_var[leading_dims + pt] = run_var[leading_dims + (pt_id,)]

    return output_var

def merge_outputs(experiment, nruns, file):
    """Merge the outputs from the specified stage from the given experiment
    that was run with nruns.

    The process is:
        1. Create a template for the dataset, by inspecting the dimensions on
            one of the run outputs.
        2. Write the dataset to disk as NetCDF, so that we can append the
            data variables directly on disk. If the dataset is created in
            memory then written, all the data variables are concretized at once
            overloading the RAM. This way only one data variable is concretized
            at a time.
        3. Determine which indices in the global landmask are associated with
            each run, by looking at the respective landmasks. Each run will get
            an iterable of indices, which will be associated with a given
            run output.
        4. Use the indices to place the outputs from a given run into the
            correct locations on the grid (in an xarray.DataArray).
        5. Append the DataArray to the NetCDF file on disk.
    """

    # Create the file templates
    landmask_file = lambda n: f"{experiment}/run{n}/landmask/landmask{n}.nc"
    run_output_file = lambda n: f"{experiment}/run{n}/outputs/{file}.nc"

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
    coordinate_mapping = {dim: ref_output[dim] for dim in ref_output.dims.keys()}

    # Now we can create the template dataset
    output_dataset = xarray.Dataset(
            coords=coordinate_mapping
            )

    # We have to write the dataset to disk now, and then append the variables
    # to it to stop the arrays from overloading the RAM
    output_dataset.to_netcdf(
            f"{experiment}/output/{file}.nc",
            engine='h5netcdf',
            mode='w'
            )

    # The vector outputs from each stage additionally have x and y variables
    # which we don't want to include, and latitude/longitude that we'll fill 
    # from the landmask definition. Time will also be handled in a bespoke
    # fashion
    exclude_vars = ["x", "y", "latitude", "longitude", "local_lat", "local_lon", "time"]

    # Pre-compute the active indices for all runs, using the run landmasks
    runs_indices = [0] * nruns
    for run in range(1, nruns+1):
        landmask_run = xarray.open_dataset(landmask_file(run))
        indices_as_arrs = numpy.argwhere(landmask_run["land"].to_numpy() == 1)
        runs_indices[run-1] = [tuple(index) for index in indices_as_arrs]

    # Load in each of the run outputs
    runs_outputs = [xarray.open_dataset(run_output_file(run)) for run in range(1, nruns+1)]

    # Set the encoding to be used by all variables
    var_encoding = {"zlib": True, "complevel": 4, "shuffle": True}

    # Set up the grid size
    grid_size = (ref_landmask.sizes["latitude"], ref_landmask.sizes["longitude"])

    # Now iterate through the variables, filling the array of the right size
    # with the variable data using the indices extracted prior
    for var in ref_output.data_vars:
        if var not in exclude_vars:
            runs_vars = [runs_outputs[run-1][var] for run in range(1, nruns+1)]
            var_data = build_variable(runs_vars, runs_indices, grid_size)

            # For each data variable, we want to convert the dimensions from
            # (..., ..., land) to (..., ..., latitude, longitude)
            var_dims = tuple(dim for dim in ref_output[var].dims[:-1])
            var_dims += ("latitude", "longitude")

            output_var = xarray.DataArray(
                    var_data,
                    dims = var_dims,
                    attrs = ref_output[var].attrs,
                    name=var
                    )

            output_var.encoding = var_encoding
            if numpy.issubdtype(output_var.dtype, numpy.floating):
                output_var.encoding["_FillValue"] = 1e20
            elif numpy.issubdtype(output_var.dtype, numpy.integer):
                output_var.encoding["_FillValue"] = -1
            else:
                raise ValueError("Data type of variable was not recognised")

            print(f"Finished merging variable {var} with shape {output_var.shape}")
            output_var.to_netcdf(
                    f"{experiment}/output/{file}.nc",
                    engine='h5netcdf',
                    mode='a'
                    )

if __name__ == "__main__":
    args = parse_args()

    merge_outputs(args.experiment, args.nruns, args.file)
