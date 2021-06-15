library(tidyverse)
library(nowcastDFM)
Sys.setlocale(category = "LC_NUMERIC", locale = "en_US.UTF-8")

source("src/helper.r")
source("src/gen_plots.r")

# directory locations
if (Sys.info()[["sysname"]] == "Darwin") {
  output_directory <- "/Users/danhopp/dhopp1/UNCTAD/nowcast_data_update/output/" # location of the database files from nowcast_data_update
  helper_directory <- "/Users/danhopp/dhopp1/UNCTAD/nowcast_data_update/helper/" # location of helper files, like catalog.csv, from nowcast_data_update
  unctad_nowcast_web_directory <- "/Users/danhopp/dhopp1/UNCTAD/unctad-nowcast-web/" # location of bokeh application for unctad nowcast web app, comment out this line if unsure
} else {
  output_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/output/" # location of the database files from nowcast_data_update
  helper_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/helper/" # location of helper files, like catalog.csv, from nowcast_data_update
  unctad_nowcast_web_directory <- "/home/danhopp/dhopp1/UNCTAD/unctad-nowcast-web/" # location of bokeh application for unctad nowcast web app, comment out this line if unsure
}
catalog <- read_csv(paste0(helper_directory, "catalog.csv"))

# parameter, which quarter to nowcast
target_periods <- c("2020-06-01")
while (as.numeric(difftime(
  as.character(seq(as.Date(max(target_periods)), by = paste (3, "months"), length = 2)[2]), # only continue if the addition is less than 93 days away
  Sys.Date(), units="days")) <= 93) {
  target_periods <- c(
    target_periods, 
    as.character(seq(as.Date(max(target_periods)), by = paste (3, "months"), length = 2)[2])
  )
}

for (target_period in target_periods) {
  target_period <- as.Date(target_period)
  # generating new plots and forecasts
  database_dates <- get_databases(output_directory)$database_dates
  latest_database <- get_databases(output_directory)$latest_database
  data <- read_csv(paste0(output_directory, latest_database, "_database_tf.csv")) %>% data.frame
  
  for (target_variable in c("x_world", "x_servs_world", "x_vol_world2")) {
    reestimate <- list.files(paste0("estimated_models/", target_variable, "/")) %>% # last estimated model
      sort %>% 
      .[length(.)] %>% 
      paste0("estimated_models/", target_variable, "/", .)
    save_directory <- "output/"
    limited_db_dates <- database_dates %>% 
      .[as.numeric(difftime(target_period, ., units="days")) <= 93] %>%  # only starting 93 days before the target period
      .[as.numeric(difftime(., target_period, units="days")) <= 93] # ending 93 days after the target period
    gen_plots(limited_db_dates, latest_database, target_variable, target_period, reestimate, save_directory) 
  }
  
  # updating data file of unctad nowcast website
  if (exists("unctad_nowcast_web_directory")) {
    update_nowcast_web_data(unctad_nowcast_web_directory, latest_database, target_period, output_directory)
  } 
}

cat("\033[0;32mNowcasts successfully updated\033[0m\n")
