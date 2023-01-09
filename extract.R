to_df <- function(scenarios, experiment)
{
    data = foreach(scenario=iter(scenarios, by='row'), .combine=rbind) %do%
        {
            d = read.csv(paste0(experiment, "/txt/", scenario$id, ".txt"), sep = "\t", header = FALSE)
            d['id'] = scenario$id
            d
        }
    colnames(data) <- c('survey', 'ageGroup', 'measure', 'value', 'id')
    return(data)
}
