to_df <- function(scenarios, experiment)
{
    
    #data = foreach(scenario=iter(scenarios, by='row'), .combine=rbind) %do%
    #    {
    #        f = paste0(experiment, "/txt/", scenario$index, ".txt")
    #        if(file.exists(f) == FALSE)
    #            return(NA)
    #        d = read.csv(f, sep = "\t", header = FALSE)
    #        d['index'] = scenario$index
    #        d
    #    }
    
    n = nrow(scenarios)
    data = list()
    for (row in 1:n)
    {
        index <- scenarios[row, "index"]
        f = paste0(experiment, "/txt/", index, ".txt")
        if(file.exists(f) == FALSE)
            return(NA)
        d = fread(f, sep = "\t", header = FALSE)
        d[,'index'] = index
        data[[row]] <- d
    }
    
    data <- rbindlist(data)
    
    colnames(data) <- c('survey', 'ageGroup', 'measure', 'value', 'index')
    
    return(data)
}
