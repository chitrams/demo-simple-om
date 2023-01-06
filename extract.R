to_df <- function(scenarios, experiment)
{
    data = foreach(scenario=iter(scenarios, by='row'), .combine=rbind) %do%
        {
            d = read.csv(paste0(experiment, "/txt/", scenario$count, ".txt"), sep = "\t", header = FALSE)
            d['count'] = scenario$count
            d
        }
    colnames(data) <- c('survey', 'ageGroup', 'measure', 'value', 'count')
    return(data)
}
