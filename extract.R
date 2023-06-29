to_df <- function(scenarios, experiment)
{
    infoCount = 0
    maxInfoCount = 100
    n = nrow(scenarios)
    data = list()

    for (row in 1:n)
    {
        index <- scenarios[row, "index"]
        f = paste0(experiment, "/txt/", index, ".txt")
        if(file.exists(f) == FALSE) {
            if(infoCount < maxInfoCount) {
                message("Warning: File ", f, " is missing")
                if(infoCount == maxInfoCount-1) {
                    message("Further missing files will not be shown")
                }
            }
            infoCount <- infoCount + 1
        }
        else {
            d = fread(f, sep = "\t", header = FALSE)
            d[,'index'] = index
            data[[row]] <- d
        }
    }
    
    data <- rbindlist(data)
    
    if(infoCount > 0) {
        message("Warning: ", infoCount, "/", n, " files are missing")
    }
    
    if (nrow(data) == 0) {
        message("Error: Dataframe is empty because no outputs were found")
        message("       Check the log files and make sure OpenMalaria is able to run")
    }
    else {
        colnames(data) <- c('survey', 'ageGroup', 'measure', 'value', 'index')
    }
    
    return(data)
}
