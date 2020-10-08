library(tidyverse)
library(nowcastDFM)

source("src/helper.r")
source("src/gen_plots.r")

# directory locations
output_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/output/" # location of the database files from nowcast_data_update
helper_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/helper/" # location of helper files, like catalog.csv, from nowcast_data_update
unctad_nowcast_web_directory <- "/home/danhopp/dhopp1/UNCTAD/unctad-nowcast-web/" # location of bokeh application for unctad nowcast web app, comment out this line if unsure
catalog <- read_csv(paste0(helper_directory, "catalog.csv"))

# parameter, which quarter to nowcast
target_period <- as.Date("2020-09-01")

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
  gen_plots(database_dates, latest_database, target_variable, target_period, reestimate, save_directory) 
}

# updating data file of unctad nowcast website
if (exists("unctad_nowcast_web_directory")) {
  update_nowcast_web_data(unctad_nowcast_web_directory, latest_database, target_period)
}

cat("\033[0;32mNowcasts successfully updated\033[0m\n")