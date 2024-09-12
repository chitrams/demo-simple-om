run_scicore <- function(scenarios, experiment, om, sciCORE)
{
    commands = list()
    for(scenario in scenarios)
    {
        index = scenario$index
        outputfile = paste0("txt/", scenario$index, ".txt")
        command = paste0("openMalaria -s xml/", index, ".xml --output ", outputfile)
        full_command = paste0("export PATH=$PATH:", om$path, " && ", command)
        commands = append(commands, full_command)
    }
    writeLines(as.character(commands), paste0(experiment, "/commands.txt"))
    
    n = length(scenarios)
    
    scriptTemplate = readLines("job.sh")
    
    maxJobs = 50000
    start <- 1
    end <- 1
    while (end < n) {
        start <- end
        end <- min(start+maxJobs, n)

        script = scriptTemplate
        script = gsub(pattern = "@START@", replace = start, x = script)
        script = gsub(pattern = "@END@", replace = end, x = script)
        script = gsub(pattern = "@account@", replace = sciCORE$account, x = script)
        script = gsub(pattern = "@jobname@", replace = sciCORE$jobName, x = script)
        writeLines(script, con=paste0(experiment, "/start_array_job_", start, "_", end, ".sh"))
        
        message("Launching array job from ", start, " to ", end)
        system(paste0("cd ", experiment, " && sbatch --wait start_array_job_", start, "_", end, ".sh"))
    }
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
        index = scenario$index
        
        outputfile = paste0("txt/", scenario$index, ".txt")
        command = paste0("openMalaria -s xml/", index, ".xml --output ", outputfile)
        full_command = paste0("export PATH=$PATH:", om$path, " && cd ", experiment, " && ", command)
        system(full_command, ignore.stdout = TRUE, ignore.stderr = TRUE)
        NULL
    }
    
    stopCluster(cluster)
}

run_scenarios <- function(scenarios, experiment, om, sciCORE)
{
    file.copy(paste0(om$path, "../test/densities.csv"), paste0(experiment, "/"))
    file.copy(paste0(om$path, "../schema/scenario_", om$version, ".xsd"), paste0(experiment, "/"))
    
    if(sciCORE$use == TRUE) run_scicore(scenarios, experiment, om, sciCORE)
    else run_local(scenarios, experiment, om)
}