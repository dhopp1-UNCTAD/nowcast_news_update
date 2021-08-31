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
gen_plots <- function (database_dates, latest_database, target_variable, target_period, training_date, save_directory) {
  weekly_start <- as.Date("2020-08-07") # when weekly data started being gathered
  vars <- catalog[catalog[,paste0(target_variable, "_block_1")] > 0,] %>% select(code, !!paste0(target_variable, "_block_1")) %>% arrange(!!sym(paste0(target_variable, "_block_1"))) %>% select(code) %>% pull
  
  # check if model already estimated
  model_path <- paste0("estimated_models/", target_variable, "/", training_date, ".rds")
  if (file.exists(model_path)) {
    output_dfm <- readRDS(model_path)
  } else { # estimate it if not
    model_data <- read_csv(paste0(output_directory, training_date, "_database_tf.csv")) %>% data.frame
    model_data <- model_data[,c("date", vars)]
    p <- catalog %>% select(!!paste0(target_variable, "_p")) %>% slice(1) %>% pull
    blocks <- data.frame(x=rep(1, ncol(model_data)-1))
    
    # if there's an error in estimating the DFM, take the last working model
    tryCatch({
      output_dfm <- dfm(model_data, blocks, p, max_iter=1500)  
    }, error = function(e) {
      output_dfm <<- readRDS(paste0("estimated_models/", target_variable, "/", max(list.files(paste0("estimated_models/", target_variable)))))  
    }, silent=TRUE)
    saveRDS(output_dfm, model_path)
  }
  
  # creating list of dataframe data
  df_list <- list()
  for (db_date in database_dates) {
    db_date <- as.Date(db_date, origin="1970-01-01")
    df_list[[length(df_list)+1]] <- read_csv(paste0(output_directory, as.character(db_date), "_database_tf.csv"), col_types=cols()) %>% data.frame %>% select(c("date", vars))
  } 
  
  rm("final_df") # has to be removed because created in the gen_news_graph function
  result <- gen_news_graphs(output_dfm, target_variable, target_period, database_dates, df_list)
  plot_df <- result$plot_df
  plot_df <- plot_df %>% 
    mutate(target = target_variable, target_period = target_period)
  write_csv(plot_df, paste0(save_directory, target_variable, "_", target_period, ".csv"))  
}