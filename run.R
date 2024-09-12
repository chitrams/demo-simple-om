run_HPC <- function(scenarios, experiment, om, NTASKS)
{
    file.copy(paste0(om$path, "/densities.csv"), paste0(experiment, "/"))
    file.copy(paste0(om$path, "/scenario_", om$version, ".xsd"), paste0(experiment, "/"))
  
    commands = list()
    for(scenario in scenarios)
    {
        index = scenario$index
        outputfile = paste0("txt/", scenario$index, ".txt")
        command = paste0(om$exe, " -s xml/", index, ".xml --output ", outputfile)
        full_command = paste0("export PATH=$PATH:", om$path, " && ", command)
        commands = append(commands, full_command)
    }
    writeLines(as.character(commands), paste0(experiment, "/commands.txt"))
    
    n = length(scenarios)
    
    NTASKS = min(n, NTASKS)
    
    script = readLines("job.sh")
    script = gsub(pattern = "@NTASKS@", replace = NTASKS, x = script)

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
        index = scenario$index
        
        outputfile = paste0("txt/", scenario$index, ".txt")
        command = paste0("openMalaria -s xml/", index, ".xml --output ", outputfile)
        full_command = paste0("export PATH=$PATH:", om$path, " && cd /Users/chitrams/Documents/local-workbench/simple-om/test-folder && ", command)
        system(full_command, ignore.stdout = TRUE, ignore.stderr = TRUE)
        NULL
    }
    
    stopCluster(cluster)
}