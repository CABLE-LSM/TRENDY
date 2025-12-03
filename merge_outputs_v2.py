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

def build_variable(output_var, runs_var, runs_indices):
    """Take the data from run_var and place it in output_var, using the run_indices to map
    from the vector to matrix format."""

    # Create the non-space dimension slices
    leading_dims = tuple([slice(None) for _ in range(output_var.ndim - 2)])

    print(f"Shape: {output_var.shape}")
    for (run_var, run_indices) in zip(runs_var, runs_indices):
        # Convert the set of indices to a single indexer over all dimensions
        # lat_inds, lon_inds = zip(*run_indices)
        #indexing_array_grid = (leading_dims + (lat_inds, lon_inds))
        #output_var[indexing_array_grid] = run_var.to_numpy()
        for (pt_id, pt) in enumerate(run_indices):
            output_var[leading_dims + pt] = run_var[leading_dims + (pt_id,)]

def insert_data(output_dataset, run_output_file, landmask_file):
    """Take the data from run_output and insert it into output_dataset using the mask
    defined by the given landmask."""

    # Load in the run specific files
    run_output = xarray.open_dataset(run_output_file)
    landmask = xarray.open_dataset(landmask_file)

    # Get the point locations from the landmask. These will always represent the last
    # 2 dimensions of the array.
    point_locations = [tuple(point) for point in numpy.argwhere(landmask["land"].to_numpy() == 1)]

    # Now iterate through the variables we want to output- again, need to exclude some
    # variables
    exclude_vars = ["local_lat", "local_lon", "latitude", "longitude"]
    for var in output_dataset.data_vars:
        if var not in exclude_vars:
            # We need to create the slice for the non-space dimensions. This is effectively
            # a tuple of (:, :, ...) of length equal to the non-space dimensions of the
            # variable. This is then added to the points extracted from the mask to create
            # an indexer of (:, :, ..., lat, lon) for each point in the mask.
            leading_dims = tuple([slice(None) for _ in range(len(run_output[var].dims) - 1)])
            print(f"leading_dims: {leading_dims}")
            for pt_id, point in enumerate(point_locations):
                print(f"Run index: {leading_dims + (pt_id,)}, output index: {leading_dims + point}")
                output_dataset[var][leading_dims + point] = \
                        run_output[var][leading_dims + (pt_id,)]

def code_from_variable(dataset, var):
    """Create a code describing how to build the numpy array for a given variable."""

    var_dims = "_".join(dataset[var].dims)
    var_dtype = str(dataset[var].encoding["dtype"])

    return "_".join([var_dims, var_dtype])

def merge_outputs(experiment, nruns, file):
    """Merge the outputs from the specified stage from the given experiment
    that was run with nruns."""

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

    # The vector outputs from each stage additionally have x and y variables which
    # we don't want to include, and latitude/longitude that we'll fill from the
    # landmask definition. Time will also be handled in a bespoke fashion
    exclude_vars = ["x", "y", "latitude", "longitude", "local_lat", "local_lon", "time"]

    # We can't preassign arrays for all of the variables, since this blows the RAM of a
    # hugemem node. Instead, assign a single array for each possible shape, and fill it
    # with the relevant data. We then pass the correctly sized array to the merging
    # function, to be filled and then assigned to the relevant variable.
    var_arrays = {}
    for var in ref_output.data_vars:
        if var not in exclude_vars:
            # Drop the "land" dimension, which is the last dimension, and add ("y", "x")
            var_dims = ref_output[var].dims
            var_dtype = ref_output[var].encoding["dtype"]

            if (var_dims, var_dtype) not in var_arrays.keys():
                print(f"Creating a new array for {(var_dims, var_dtype)}")
                arr_size = tuple([ref_output.sizes[dim] for dim in var_dims])
                
                # Drop the land dimension, and add the x, y
                arr_size = arr_size[:-1] + (ref_landmask.sizes["latitude"], ref_landmask.sizes["longitude"])
                arr = numpy.ma.masked_all(arr_size, dtype=numpy.dtype(var_dtype))
                var_arrays[(var_dims, var_dtype)] = arr

    """
    # Create the dictionary of NetCDF variables
    data_var_mapping = {}
    for var in ref_output.data_vars:
        if var not in exclude_vars:
            dim_sizes = tuple([ref_output[dim].size for dim in var_dims])

            # Create the new array to store the data, using the reference data type
            data_arr = numpy.ma.masked_all(dim_sizes, dtype=ref_output[var].encoding['dtype'])

            # Now we can create the required tuple used to build NetCDF variables with xarray
            data_var_mapping[var] = (var_dims, data_arr, ref_output[var].attrs)s
    """
    # Now we can create the dataset, and begin filling it
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

    # Now iterate through the variables, filling the array of the right size with the variable
    # data using the indices extracted prior
    for var in ref_output.data_vars:
        if var not in exclude_vars:
            runs_vars = [runs_outputs[run-1][var] for run in range(1, nruns+1)]
            var_dims = ref_output[var].dims
            var_dtype = ref_output[var].encoding["dtype"]
            build_variable(
                    var_arrays[(var_dims, var_dtype)],
                    runs_vars,
                    runs_indices
                    )
            print(f"Applied dimensions: {(var_dims[:-1] + ('latitude', 'longitude'))}")
            output_var = xarray.DataArray(
                    var_arrays[(var_dims, var_dtype)],
                    dims = var_dims[:-1] + ("latitude", "longitude"),
                    attrs = ref_output[var].attrs,
                    name=var
                    )

            ds = xarray.open_dataset(f"{experiment}/output/{file}.nc")
            print(f"Dataset dimensions: {ds.dims}")
            ds.close()

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

    # Fill in the data from each of the runs
    # for run in range(1, nruns+1):
        # insert_data(output_dataset, run_output_file(run), landmask_file(run))
        # gc.collect()

if __name__ == "__main__":
    args = parse_args()

    merge_outputs(args.experiment, args.nruns, args.file)
