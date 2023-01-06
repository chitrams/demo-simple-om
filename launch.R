# Clear global environment
rm(list = ls())

# Tidy up
if (interactive()) clc()  # Clear console
if (interactive()) clf()  # Close figures

# Set working directory to sourced file
setwd("/scicore/home/scicore/cavelan/git/r-workflow")

# Load all required packages, installing them if required
pacman::p_load(char = c("foreach", "doParallel"))

# load local files
source("pacman.R")
source("run.R")
source("extract.R")

# if using the sciCORE cluster:
sciCORE = list(
    use = TRUE,
    account = "penny",
    jobName = "OpenMalaria"
)

# OpenMalaria
om = list(
    version = 44,
    path = "/home/acavelan/git/om-dev/fitting/om/openMalaria-44.0"
)
if (sciCORE$use == TRUE) om$path = "/scicore/home/chitnis/GROUP/openMalaria-44.0/"

# Scaffold xml to use
scaffolds = list(
    "R0000GA"
)

# run scenarios, extract the data, or both
do_run = FALSE
do_extract = TRUE

# name of the experiment folder
experiment = 'test'

# Fixed
pop_size = 10000
burn_in_years = 30
access = 0.2029544 # 5-day probability
start_year = 2000
end_year = 2020
outdoor_biting = 0.2

# Variable
seeds = 10
modes = c("perennial", "seasonal")
eirs = c(0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 22, 25, 30, 35, 40, 45, 50, 65, 70, 80, 90, 100, 120, 150, 200, 250, 500, 750, 1000)

# Test (12 scenarios with 2000 popsize); uncomment to overwrite other settings and do a quick test
#pop_size = 2000
#eirs = c(2, 10, 20, 40, 60, 80, 100, 200)
#modes = c("perennial", "seasonal")
#seeds = 3

# Computed
burn_in = start_year - burn_in_years
outdoor = outdoor_biting
indoor = 1.0 - outdoor

# Define functional form of non-perennial, seasonal setting
season_daily = 1 + sin(2 * pi * ((1 : 365) / 365))
season_month = season_daily[round(1 + seq(0, 365, length.out = 13))[-13]]
season_month = season_month / max(season_month)

# return a list of scenarios
create_scenarios <- function()
{
    count = 1
    scenarios = list()
    for(scaffold in scaffolds)
    {
        xml = readLines(paste0("scaffolds/", scaffold, ".xml"))
        xml = gsub(pattern = "@version@", replace = om$version, x = xml)
        xml = gsub(pattern = "@pop_size@", replace = pop_size, x = xml)
        xml = gsub(pattern = "@burn_in@", replace = burn_in, x = xml)
        xml = gsub(pattern = "@access@", replace = access, x = xml)
        xml = gsub(pattern = "@start_year@", replace = start_year, x = xml)
        xml = gsub(pattern = "@end_year@", replace = end_year, x = xml)
        xml = gsub(pattern = "@indoor@", replace = indoor, x = xml)
        xml = gsub(pattern = "@outdoor@", replace = outdoor, x = xml)
        
        for(eir in eirs)
        {
            for(seed in 1:seeds)
            {
                for(mode in modes)
                {
                    scenario = xml
                    scenario = gsub(pattern = "@seed@", replace = seed, x = scenario)
                    scenario = gsub(pattern = "@eir@", replace = eir, x = scenario)
                    
                    if(mode == "seasonal") seasonality = season_month
                    else if(mode == "perennial") seasonality = replicate(12, 1)
                    else print("unknown mode:", mode)
                    
                    for(i in 1:12)
                    {
                        pattern = paste0("@seasonality", i, "@")
                        scenario = gsub(pattern = pattern, replace = seasonality[i], x = scenario)
                    }
                    
                    writeLines(scenario, con=paste0(experiment, "/xml/", count, ".xml"))
                    
                    scenario_metadata = list(scaffoldName = scaffold, eir = eir, seed = seed, mode = mode, count = count)
                    scenarios = append(scenarios, list(scenario_metadata))
                    
                    count = count + 1
                }
            }
        }
    }
    
    return(scenarios)
}

if (do_run == TRUE)
{
    message("Cleaning Tree...")
    unlink(experiment, recursive=TRUE)
    dir.create(experiment)
    dir.create(paste0(experiment, "/xml"))
    dir.create(paste0(experiment, "/txt"))
    dir.create(paste0(experiment, "/fig"))
    
    message("Creating scenarios...")
    scenarios = create_scenarios()
    
    message("Running scenarios...")
    run_scenarios(scenarios, experiment, om, sciCORE)
    write.csv(do.call(rbind, scenarios), paste0(experiment, "/scenarios.csv"), row.names=FALSE)
}

if (do_extract == TRUE)
{
    message("Extracting results...")
    unlink(paste0(experiment, "/output.csv"))
    scenarios = read.csv(paste0(experiment, "/scenarios.csv"))
    df = to_df(scenarios, experiment)
    write.csv(df, paste0(experiment, "/output.csv"), row.names=FALSE)
}

message("Done")