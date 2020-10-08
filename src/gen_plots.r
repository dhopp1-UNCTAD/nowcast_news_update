# info on databases
get_databases <- function (output_directory) {
  files <- list.files(output_directory)
  database_dates <- files %>% 
    grepl("_tf", .) %>% 
    files[.] %>% 
    sort %>% 
    substr(1, 10) %>% 
    as.Date
  latest_database <- database_dates[length(database_dates)]
  return (list(database_dates=database_dates, latest_database=latest_database))  
}

# generating the plots
gen_plots <- function (database_dates, latest_database, target_variable, target_period, reestimate, save_directory) {
  weekly_start <- as.Date("2020-08-07") # when weekly data started being gathered
  
  if (reestimate==TRUE) {
    p <- catalog %>% select(!!paste0(target_variable, "_p")) %>% slice(1) %>% pull
    vars <- catalog[catalog[,paste0(target_variable, "_block_1")] > 0,] %>% select(code, !!paste0(target_variable, "_block_1")) %>% arrange(!!sym(paste0(target_variable, "_block_1"))) %>% select(code) %>% pull
    model_data <- data[,c("date", vars)] # maybe need to only go up to 2019 for model estimation
    blocks <- data.frame(x=rep(1, ncol(model_data)-1))
    output_dfm <- dfm(model_data, blocks, p, max_iter=1500)
  } else {
    vars <- catalog[catalog[,paste0(target_variable, "_block_1")] > 0,] %>% select(code, !!paste0(target_variable, "_block_1")) %>% arrange(!!sym(paste0(target_variable, "_block_1"))) %>% select(code) %>% pull
    output_dfm <- readRDS(reestimate)
  }
  
  # add artificial lag months
  which_months <- c((seq(target_period, length=4, by="-1 months") %>% sort), (seq(target_period, length=5, by="1 months") %>% sort)) %>% unique
  which_months <- which_months[which_months < weekly_start] # only do artificial lags for when before started getting data weekly
  which_months <- which_months[which_months < Sys.Date()]
  which_months <- which_months[!(which_months %in% as.Date(database_dates[database_dates >= weekly_start]))] # don't add dates already in the manual database dates
  df_list <- list()
  for (month in which_months) {
    df_list[[length(df_list)+1]] <- lag_data(data, catalog, month) %>% select(c("date", vars))
  }
  # add manual databases
  if (T) {
    for (db_date in database_dates[database_dates >= weekly_start]) {
      db_date <- as.Date(db_date, origin="1970-01-01")
      df_list[[length(df_list)+1]] <- read_csv(paste0(output_directory, as.character(db_date), "_database_tf.csv")) %>% data.frame %>% select(c("date", vars))
      which_months[length(which_months) + 1] <- as.Date(db_date)
    } 
  }
  
  rm("final_df")
  result <- gen_news_graphs(output_dfm, target_variable, target_period, which_months, df_list)
  ggsave(paste0(save_directory, latest_database, "_", target_variable, "_plot.png"), height=10, width=10)
  plot_df <- result$plot_df
  write_csv(plot_df, paste0(save_directory, latest_database, "_", target_variable, "_plot_df.csv"))  
}
