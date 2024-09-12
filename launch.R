# Clear global environment
rm(list = ls())

# load local files
source("pacman.R")
source("run.R")
source("extract.R")

# Load all required packages, installing them if required
pacman::p_load(char = c("foreach", "doParallel", "dplyr", "data.table"))

# sciCORE Slurm parameters:
sciCORE = list(
    use = TRUE,
    account = "penny",
    jobName = "OpenMalaria"
)

# OpenMalaria
om = list(
    version = 45,
    path = "/scicore/home/penny/GROUP/OpenMalaria/OM_schema45/"
)

# Scaffold xmls to use
scaffolds = list(
    "R0000GA"
)

# run scenarios, extract the data, or both
do = list(
    run = TRUE, 
    extract = TRUE,
    example = TRUE
)

experiment = 'test' # name of the experiment folder

# Fixed parameters for all xmls
pop_size = 1000 # number of humans
start_year = 2010 # start of the monitoring period
end_year = 2020 # end of the monitoring period
burn_in = start_year - 10 # additional burn in time
access = 0.2029544 # 5-day probability of access to care
outdoor = 0.2
indoor = 1.0 - outdoor

# Varying parameters (combinatorial experiment)
seeds = 5
modes = c("perennial", "seasonal")
eirs = c(5, 10, 15, 20, 40, 60, 80, 100, 150, 200)

# For a quick test
# pop_size = 2000
# seeds = 3
# modes = c("perennial")
# eirs = c(5, 20, 50, 100, 200)

# Define functional form of non-perennial seasonal setting
season_daily = 1 + sin(2 * pi * ((1 : 365) / 365))
season_month = season_daily[round(1 + seq(0, 365, length.out = 13))[-13]]
season_month = season_month / max(season_month)

# Return a list of scenarios
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
                    
                    # add the scenario to the list, only the 'index' field is mandatory, see example at the end
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
    dir.create(paste0(experiment, "/log"))
    
    message("Creating scenarios...")
    scenarios = create_scenarios()
    fwrite(rbindlist(scenarios), paste0(experiment, "/scenarios.csv"))
    
    message("Running scenarios...")
    # run_scenarios(scenarios, experiment, om, sciCORE)
    run_local(scenarios, experiment, om)
}

if (do$extract == TRUE)
{
    message("Extracting results...")
    unlink(paste0(experiment, "/output.csv"))
    scenarios = fread(paste0(experiment, "/scenarios.csv"))
    
    start.time <- Sys.time()
    df = to_df(scenarios, experiment)
    end.time <- Sys.time()
    time.taken <- end.time - start.time
    message("Extract time: ", time.taken)
    
    if(nrow(df) == 0) {
        message("Error: extraction failed, output dataframe is empty")
        message("       output.csv not saved")
    }
    else {
        start.time <- Sys.time()
        fwrite(df, paste0(experiment, "/output.csv"))
        end.time <- Sys.time()
        time.taken <- end.time - start.time
        message("Write time: ", time.taken)
    }
}

if (do$example == TRUE)
{
    scenarios = fread(paste0(experiment, "/scenarios.csv"))
    d = fread(paste0(experiment, "/output.csv"))
    
    # remove NA values
    d = d[complete.cases(d), ]
    
    # remove first survey
    d = d[!d$survey == 1,]
    
    # sum up surveys
    d = d %>% 
        group_by(index, measure, ageGroup) %>% 
        summarise(value = sum(value), .groups = 'drop')
    
    # adjust nHosts for age_group 0-1
    d[d$ageGroup == 1 & d$measure == 0, ]['value'] = d[d$ageGroup == 1 & d$measure == 0, ]['value'] * 0.5
    
    # merge with the scenarios to have more metadata
    d = merge(d, scenarios, by = 'index')
    
    # summarised scenario_1
    scenario_1 = d[d$index == 1, ]
}

