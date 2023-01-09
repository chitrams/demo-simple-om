# Clear global environment
rm(list = ls())

# load local files
source("pacman.R")
source("run.R")
source("extract.R")

# Load all required packages, installing them if required
pacman::p_load(char = c("foreach", "doParallel"))

# sciCORE Slurm parameters:
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

# Scaffold xmls to use
scaffolds = list(
    "R0000GA"
)

# run scenarios, extract the data, or both
do = list(
    run = FALSE, 
    extract = TRUE
)

experiment = 'test' # name of the experiment folder

# Fixed parameters for all xmls
pop_size = 10000 # number of humans
start_year = 2000 # start of the monitoring period
end_year = 2020 # end of the monitoring period
burn_in = start_year - 30 # additional burn in time
access = 0.2029544 # 5-day probability of access to care
outdoor = 0.2
indoor = 1.0 - outdoor

# Varying parameters (combinatorial experiment)
seeds = 10
modes = c("perennial", "seasonal")
eirs = c(0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 22, 25, 30, 35, 40, 45, 50, 65, 70, 80, 90, 100, 120, 150, 200, 250, 500, 750, 1000)

# Define functional form of non-perennial seasonal setting
season_daily = 1 + sin(2 * pi * ((1 : 365) / 365))
season_month = season_daily[round(1 + seq(0, 365, length.out = 13))[-13]]
season_month = season_month / max(season_month)

# return a list of scenarios
create_scenarios <- function()
{
    index = 1
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
                    else message("Error: unknown mode ", mode)
                    
                    for(i in 1:12)
                        scenario = gsub(pattern = paste0("@seasonality", i, "@"), replace = seasonality[i], x = scenario)
                    
                    # write xml
                    writeLines(scenario, con=paste0(experiment, "/xml/", index, ".xml"))
                    
                    scenario_metadata = list(scaffoldName = scaffold, eir = eir, seed = seed, mode = mode, index = index)
                    scenarios = append(scenarios, list(scenario_metadata))
                    
                    index = index + 1
                }
            }
        }
    }
    
    return(scenarios)
}

if (do$run == TRUE)
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

if (do$extract == TRUE)
{
    message("Extracting results...")
    unlink(paste0(experiment, "/output.csv"))
    scenarios = read.csv(paste0(experiment, "/scenarios.csv"))
    df = to_df(scenarios, experiment)
    write.csv(df, paste0(experiment, "/output.csv"), row.names=FALSE)
}

message("Done")