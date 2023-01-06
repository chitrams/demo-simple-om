run_scicore <- function(scenarios, experiment, om, sciCORE)
{
    commands = list()
    for(scenario in scenarios)
    {
        count = scenario$count
        outputfile = paste0("txt/", scenario$count, ".txt")
        command = paste0("openMalaria -s xml/", count, ".xml --output ", outputfile)
        full_command = paste0("export PATH=$PATH:", om$path, " && ", command)
        commands = append(commands, full_command)
    }
    writeLines(as.character(commands), paste0(experiment, "/commands.txt"))
    
    n = length(scenarios)
    
    script = readLines("job.sh")
    script = gsub(pattern = "@N@", replace = n, x = script)
    script = gsub(pattern = "@account@", replace = sciCORE$account, x = script)
    script = gsub(pattern = "@jobname@", replace = sciCORE$jobName, x = script)
    
    writeLines(script, con=paste0(experiment, "/start_array_job.sh"))
    
    system(paste0("cd ", experiment, " && sbatch --wait start_array_job.sh"))
}

run_local <- function(scenarios, experiment, om)
{
    n = length(scenarios)
    
    n_cores = detectCores() - 1
    registerDoParallel(n_cores)
    cluster = makeCluster(n_cores, type="FORK")  
    registerDoParallel(cluster)  
    
    foreach(i=1:n, .combine = 'c') %dopar% {
        scenario = scenarios[[i]]
        count = scenario$count
        
        outputfile = paste0("txt/", scenario$count, ".txt")
        command = paste0("openMalaria -s xml/", count, ".xml --output ", outputfile)
        full_command = paste0("export PATH=$PATH:", om$path, " && cd ", experiment, " && ", command)
        system(full_command, ignore.stdout = TRUE, ignore.stderr = TRUE)
        NULL
    }
    
    stopCluster(cluster)
}

run_scenarios <- function(scenarios, experiment, om, sciCORE)
{
    file.copy(paste0(om$path, "/densities.csv"), paste0(experiment, "/"))
    file.copy(paste0(om$path, "/scenario_", om$version, ".xsd"), paste0(experiment, "/"))
    
    if(sciCORE$use == TRUE) run_scicore(scenarios, experiment, om, sciCORE)
    else run_local(scenarios, experiment, om)
}