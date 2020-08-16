suppressPackageStartupMessages({
  library(tidyverse)
  library(nowcastDFM)
})
options(warn=-1)
Sys.setlocale(category = "LC_NUMERIC", locale = "en_US.UTF-8")
options(scipen=500)

### options
reestimate_model <- FALSE
newest_database <- NA # which date database to run as latest data, e.g. "2020-08-06". Leave NA to calculate automatically.
second_newest_database <- NA # e.g. "2020-08-05". Leave NA to calculate automatically.
which_model <- NA # which already estimated model to run, e.g. "2020-08-06". Leave NA to run latest one.
target_period <- as.Date("2020-06-01") # as.Date("2020-06-01") which date to be forecast for the news. Leave NA to run for current quarter.

output_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/output/" # location of the database files from nowcast_data_update
helper_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/helper/" # location of helper files, like catalog.csv, from nowcast_data_update
historical_news_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_news_update/historical_news/" # where news of prior months, to generate visualizations, comes from
estimated_models_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_news_update/estimated_models/"


for (target_variable in c("x_world", "x_vol_world2", "x_servs_world")) { # 3 options: x_world for global trade value, x_vol_world2 for global trade volume, x_servs_world for global trade in services
  ### reading data
  get_file_dates <- function (path) {
    tmp <- list.files(path) %>% 
      sapply(function(x) substr(x, 1, 10)) %>% 
      as.Date %>% 
      unique %>% 
      .[!is.na(.)] %>% 
      sort
    return (tmp)
  }
  
  # restrict values to between
  
  gen_data <- function(catalog, target_variable, data) {
    catalog_info <- catalog %>% 
      .[.[,target_variable] != 0,] %>% 
      select(-url, -download_group) %>% # mar_cn is not distinct because getting data is split into two groups 
      distinct()
    vars <- catalog_info[order(catalog_info[,target_variable] %>% pull),]$code # order is important for the blocks
    blocks <- catalog_info %>% 
      select(starts_with(paste0(target_variable, "_block"))) %>% 
      data.frame
    blocks <- blocks[order(blocks[,1]),] %>% data.frame
    for (col in colnames(blocks)) {
      for (row in 1:nrow(blocks)) {
        if (blocks[row, col] > 0) {
          blocks[row, col] <- 1 
        } else {
          blocks[row, col] <- 0
        }
      }
    }
    data <- data[,c("date", vars)] %>% data.frame
    p <- catalog[1,paste0(target_variable, "_p")] %>% pull
    return (list(data=data, blocks=blocks, p=p))
  }
  
  catalog <- read_csv(paste0(helper_directory, "catalog.csv"))
  available_databases <- get_file_dates(output_directory)
  
  if (is.na(newest_database)) {
    newest_database <- available_databases[length(available_databases)]  
  }
  if (is.na(second_newest_database)) {
    second_newest_database <- available_databases[length(available_databases)-1]
  } 
  
  newest_data <- read_csv(paste0(output_directory, newest_database, "_database_tf.csv"))
  second_newest_data <- read_csv(paste0(output_directory, second_newest_database, "_database_tf.csv"))
  
  
  ### reading / estimating model
  if (reestimate_model) {
    info <- gen_data(catalog, target_variable, newest_data)
    data <- info$data
    blocks <- info$blocks
    p <- info$p
    output_dfm <- dfm(data, blocks, p=p, max_iter=1500, threshold=1e-5)
    saveRDS(output_dfm, paste0(estimated_models_directory, target_variable, "/", newest_database, "_", target_variable, "_output_dfm.rds"))
  } else {
    available_dfms <- get_file_dates(paste0(estimated_models_directory, target_variable))
    if (is.na(which_model)) {
      which_model <- available_dfms[length(available_dfms)]  
    }
    output_dfm <- readRDS(paste0(estimated_models_directory, target_variable, "/", which_model, "_", target_variable, "_output_dfm.rds"))
  }
  
  
  ### generating news
  old_data <- gen_data(catalog, target_variable, second_newest_data)$data
  new_data <- gen_data(catalog, target_variable, newest_data)$data
  if (is.na(target_period)) {
    months <- 1:12
    quarters <- c(3,3,3,6,6,6,9,9,9,12,12,12)
    target_period <- as.Date(paste0(substr(Sys.Date(), 1, 4), "-", quarters[which(as.numeric(substr(Sys.Date(), 6, 7)) == months)], "-01"))
  }
  # add extra rows if missing for target period
  add.months <- function(date,n) seq(date, by = paste (n, "months"), length = 2)[2]
  addt_months <- round(as.numeric(difftime(target_period, max(new_data$date), units="days"))/(365.25/12))
  for (i in 1:addt_months) {
    old_data[nrow(old_data)+1,"date"] <- add.months(old_data[nrow(old_data)+1-1,"date"], 1)
    new_data[nrow(new_data)+1,"date"] <- add.months(new_data[nrow(new_data)+1-1,"date"], 1)
  }
  
  # enforce just one new data point per series, because the news_dfm function can't properly handle it when more than one new datapoint is published. The additional data will show up in the next week's news.
  output_newest <- read_csv(paste0(output_directory, newest_database, "_database_tf.csv"))
  for (col in colnames(new_data)[2:length(colnames(new_data))]) {
    last_data_point_old <- 0
    for (i in seq(length(new_data[,col]), 1, by=-1)) {
      if (!is.na(old_data[i,col]) & last_data_point_old == 0) {
        last_data_point_old <- i
        break
      }
    }
    new_data[(last_data_point_old+2):nrow(new_data), col] <- NA
    # persist it in /output/ folder
    to_append <- data.frame(date=new_data[,"date"], x=new_data[,col])
    colnames(to_append) <- c("date", col)
    output_newest <- output_newest %>% select(-!!col) %>% 
      left_join(to_append, by="date")
  }
  write_csv(output_newest, paste0(output_directory, newest_database, "_database_tf.csv"))
  
  
  # break if no new data releases
  status <- tryCatch({
    news <- gen_news(old_data, new_data, output_dfm, target_variable, target_period)
    
    # saving news directory
    news_directory <- paste0(historical_news_directory, target_variable, "/", target_period, "/")
    if (!dir.exists(news_directory)) { dir.create(news_directory, recursive=TRUE) }
    
    saveRDS(news, paste0(news_directory, second_newest_database, "_to_", newest_database, "_news.rds"))
    TRUE },
    error = function(e) {
      FALSE })
  
  if (status) {
    ### generating visualizations
    files <- list.files(news_directory) %>% 
      .[sapply(., function(x) grepl("news", x))]
    all_news <- list()
    # reading in historical news
    for (file in files) {
      all_news[[file]] <-readRDS(paste0(news_directory, file))
    }
    
    # creating plotting df
    rm(final_df)
    for (file in files) {
      forecast <- all_news[[file]]$y_new
      date <- as.Date(str_replace(str_split(file, "_to_")[[1]][2], "_news.rds", ""))
      revisions <- all_news[[file]]$impact_revisions
      row_names <- row.names(all_news[[file]]$news_table)
      impact <- all_news[[file]]$news_table$Impact
      df <- data.frame(
        date_forecast = date,
        forecast = forecast,
        impact_revisions = revisions
      )
      df[,row_names] <- impact
      if(exists("final_df")) {
        final_df <- rbind(final_df, df)
      } else {
        final_df <- df
      }
    }
    
    plot_df <- final_df %>% 
      gather(series, value, -date_forecast) %>% 
      mutate(series = factor(series, levels=(colnames(final_df[,2:ncol(final_df)]) %>% sort())), value=value * 100)
    
    ggplot() + 
      geom_bar(data=filter(plot_df, series != "forecast"), aes(x=date_forecast, y=value, fill=series), stat="identity") +
      geom_line(data=filter(plot_df, series == "forecast"), aes(x=date_forecast, y=value, color=series)) +
      scale_color_manual(values="black") +
      labs(y = "%", x="Date forecast made", color="", fill="Variable contribution") +
      ggtitle(paste0(target_variable, ", ", target_period, " forecast evolution"))
    
    # save plot and final_df
    # prevent scientific notation in csv
    for (i in 1:ncol(final_df)) {
      final_df[,i] <- as.character(final_df[,i]) %>% sapply(., function(x) str_replace(x, ",", "."))
    }
    write_csv(final_df, paste0(news_directory, newest_database, "_plot_data.csv"))
    ggsave(paste0(news_directory, newest_database, "_plot_data.png"), height=10, width=20)
  }
}