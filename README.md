# A simple(r) demo R workflow to run OpenMalaria


This is a demo workflow to run OpenMalaria from within RStudio. The
purpose of this repo is to be instructional so someone new to
OpenMalaria can run a relatively simple workflow within RStudio, but not
as simple as the wiki-provided:

``` bash
./OpenMalaria --scenario example_scenario.xml --output output.txt
```

In other words, we are running several scenarios with some combination
of parameters instead of only putting in the one scenario into
OpenMalaria.

This README will walk you through:

- Creating an SSH tunnel to set up an RStudio container on Pawsey
- Running the workflow on the RStudio container

## Set up RStudio

Open the file
[`start_rstudio.sh`](https://github.com/chitrams/demo-simple-om/blob/main/start_rstudio.sh).
This script will create an SSH tunnel to Setonix on your 8787 port.

What you need to change in this script is the USERNAME on line 4.

Then run:

``` bash
# Change the file permission so you can execute the script:
chmod +x start_rstudio.sh

# After the file permission has been changed, run:
./start_rstudio.sh
```

You only need to run `chmod +x start_rstudio.sh` once. Every other time
you want to start RStudio on Pawsey you can simply execute it by using
the command `./start_rstudio.sh` in your terminal.

## Run the workflow

When you open launch.R, what you need to change are in the first 33
lines. I will walk you through them one by one.

### Parameters to change

``` r
# OpenMalaria
om = list(
    version = 47,
    path = "/software/projects/pawsey1104/GROUP/OpenMalaria_47",
    exe = "/software/projects/pawsey1104/GROUP/OpenMalaria_47/openmalaria_47.0.sif"
)
```

This bit of code specifies the path to the OpenMalaria support files and
the executable. The support files that must be accessible to run
OpenMalaria are `densities.csv` and `scenario_47.xsd` in the instance of
version 47. The executable in this instance is a Singularity Image File
that Aurélien has built, `openmalaria_47.0.sif`.

For any version changes, we will be updating the executables in that
`GROUP` folder.

``` r
# run scenarios, extract the data, or both
do = list(
    run = TRUE, 
    extract = TRUE,
    example = FALSE
)
```

Here is where it gets a bit gnarly. When you first run the scenarios,
you want to set `run = TRUE` and everything else to `FALSE`. This is
because we can’t yet access Slurm from within RStudio. I will walk you
through the run vs extract steps in the next sub-section. Before I get
to that, there is one more parameter you need to change:

``` r
experiment = 'local-09-19' # name of the experiment folder
```

This is the name of your folder. Change it to whatever you wish. I’ve
set mine to the name `local-09-19`.

### Running the workflow on an HPC

To run the scenarios, set the parameters in launch.R to the following:

``` r
# run scenarios, extract the data, or both
do = list(
    run = TRUE, 
    extract = FALSE,
    example = FALSE
)
```

Then click on the ‘Source’ button to execute the script. It will come up
with an error; this is expected! What you do now is open to a separate
terminal window and do the following:

``` bash
# Log on to setonix
ssh chitrams@setonix.pawsey.org.au

# Navigate to the folder where the outputs are saved
cd experiment-folder

# Change file permissions so you can execute the script
chmod +x start_array_job.sh

# Execute the script
sbatch start_array_job.sh
```

OpenMalaria will then run on your XML files and save all the output in
the `txt/` folder.

Now go back to your RStudio IDE and change the parameters in launch.R to
the following:

``` r
# run scenarios, extract the data, or both
do = list(
    run = FALSE, 
    extract = TRUE,
    example = FALSE
)
```

Now click on the ‘Source’ button again to execute the script. You should
now have `output.csv` and `scenarios.csv` files in your output folder.
Well done!

### Option to run the workflow locally

To run the workflow locally, go to the last part of the
`if (do$run == TRUE) { ... }` part of the script. In the last section:

``` r
message("Running scenarios...")
    run_HPC(scenarios, experiment, om, NTASKS)
    # run_local(scenarios, experiment, om)
```

If you’d like to run the workflow locally, uncomment the
`run_local()`line and comment out the `run_HPC()` line.

## Requirements

- I run MacOS 14.5.
