suppressPackageStartupMessages({
  library(tidyverse)
  library(nowcastDFM)
})
options(warn=-1)

# options
output_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/output/" # location of the database files from nowcast_data_update
helper_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/helper/" # location of helper files, like catalog.csv, from nowcast_data_update
estimated_models_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_news_update/estimated_models/"
reestimate_model <- FALSE
newest_database <- NA # which date database to run as latest data, e.g. "2020-08-06". Leave NA to calculate automatically.
second_newest_database <- NA # e.g. "2020-08-05"
which_model <- NA # which already estimated model to run, e.g. "2020-08-06". Leave NA to run latest one.
target_variable <- "x_world" # 3 options: x_world for global trade value, x_vol_world2 for global trade volume, x_servs_world for global trade in services
target_period <- NA # as.Date("2020-06-01") which date to be forecast for the news. Leave NA to run for current quarter.


# reading data
get_file_dates <- function (path) {
  tmp <- list.files(path) %>% 
    sapply(function(x) substr(x, 1, 10)) %>% 
    as.Date %>% 
    unique %>% 
    .[!is.na(.)] %>% 
    sort
  return (tmp)
}

gen_data <- function(catalog, target_variable, data) {
  catalog_info <- catalog %>% 
    .[.[,target_variable] == 1,]
  vars <- catalog_info$code
  blocks <- catalog_info %>% 
    select(starts_with(paste0(target_variable, "_block"))) %>% data.frame
  data <- data[,c("date", vars)] %>% data.frame
  return (list(data=data, blocks=blocks))
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


# reading / estimating model
if (reestimate_model) {
  info <- gen_data(catalog, target_variable, newest_data)
  data <- info$data
  blocks <- info$blocks
  output_dfm <- dfm(data, blocks, p=1, max_iter=1500, threshold=1e-5)
  saveRDS(output_dfm, paste0(estimated_models_directory, newest_database, "_", target_variable, "_output_dfm.rds"))
} else {
  available_dfms <- get_file_dates(estimated_models_directory)
  if (is.na(which_model)) {
    which_model <- available_dfms[length(available_dfms)]  
  }
  output_dfm <- readRDS(paste0(estimated_models_directory, which_model, "_", target_variable, "_output_dfm.rds"))
}


# generating news
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

news <- gen_news(old_data, new_data, output_dfm, target_variable, target_period)
