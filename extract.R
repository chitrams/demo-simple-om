to_df <- function(scenarios, experiment)
{
    data = foreach(scenario=iter(scenarios, by='row'), .combine=rbind) %do%
        {
            f = paste0(experiment, "/txt/", scenario$index, ".txt")
            if(file.exists(f) == FALSE)
                return(NA)
            d = read.csv(f, sep = "\t", header = FALSE)
            d['index'] = scenario$index
            d
        }
    colnames(data) <- c('survey', 'ageGroup', 'measure', 'value', 'index')
    return(data)
}
