# function to generate the news graph of any model and any quarter
gen_news_graphs <- function(output_dfm, target_variable, target_period, dates_list, df_list) { # df_list = list of dataframes with lagged dates
  for (j in 2:length(df_list)) {
    old_data <- df_list[[j-1]]
    new_data <- df_list[[j]]
    # add rows for news if missing
    add.months <- function(date,n) seq(date, by = paste (n, "months"), length = 2)[2]
    addt_months <- max(round(as.numeric(difftime(target_period, max(new_data$date), units="days"))/(365.25/12)), 0)
    for (i in 1:addt_months) {
      old_data[nrow(old_data)+1,"date"] <- add.months(old_data[nrow(old_data)+1-1,"date"], 1)
      new_data[nrow(new_data)+1,"date"] <- add.months(new_data[nrow(new_data)+1-1,"date"], 1)
    }
    
    has_news <- tryCatch({
      news <- gen_news(old_data, new_data, output_dfm, target_variable, target_period)
      TRUE 
    }, error=function(e){FALSE})
    
    # plotting
    forecast <- news$y_new
    date <- dates_list[j]
    # only updating data if there's news
    if (has_news) {
      revisions <- news$impact_revisions  
      impact <- news$news_table$Impact
    } else {
      revisions <- 0.0
      impact <- rep(NA, length(news$news_table$Impact))
    }
    row_names <- row.names(news$news_table)
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
  
  p <- ggplot() + 
    geom_bar(data=filter(plot_df, series != "forecast"), aes(x=date_forecast, y=value, fill=series), stat="identity") +
    geom_line(data=filter(plot_df, series == "forecast"), aes(x=date_forecast, y=value, color=series)) +
    scale_color_manual(values="black") +
    labs(y = "%", x="Date forecast made", color="", fill="Variable contribution") +
    ggtitle(paste0(target_variable, ", ", target_period, " forecast evolution"))
  
  return (list(p=p, plot_df=plot_df))
}

# lag a data according to publication lag, DEPRECATED not necessary anymore
lag_data <- function(data, catalog, lag_date) {
  lag_series <- function(data, col_name, which_date, catalog) {
    if (grepl("dep_cap", col_name)) {
      n_lag <- 1 
    } else{
      n_lag <- catalog %>% 
        filter(code == col_name) %>% 
        select(publication_lag) %>% slice(1:1) %>% pull
    }
    last_row <- which(data$date == which_date) - n_lag
    series <- data[,col_name]
    series[last_row:nrow(data)] <- NA
    return (series)
  }
  
  for (col in colnames(data)[2:ncol(data)]) {
    data[,col] <- lag_series(data, col, lag_date, catalog)
  }
  data <- data %>% 
    filter(date <= lag_date)
  return (data)
}

# update the plot data for the unctad nowcast web app
update_nowcast_web_data <- function(unctad_nowcast_web_directory, latest_database, output_directory, news_directory) {
  files <- list.files(news_directory)
  for (filename in files) {
    if (!exists("final_data")) {
      final_data <- read_csv(paste0(news_directory, filename), col_types=cols())
    } else {
      tmp <- read_csv(paste0(news_directory, filename), col_types=cols())
      final_data <- final_data %>% 
        rbind(tmp)
    }
  }
  
  # writing to bokeh app
  write_csv(final_data, paste0(unctad_nowcast_web_directory, "nowcasts/data/data.csv"))
  
  # moving the latest database, adding full # of rows if necessary
  add.months <- function(date,n) seq(date, by = paste (n, "months"), length = 2)[2]
  db <- read_csv(paste0(output_directory, latest_database, "_database_tf.csv"))
  while (max(db$date) < target_period) {
    db[nrow(db)+1, "date"] <- add.months(max(db$date), 1)
  }
  write_csv(db, paste0(unctad_nowcast_web_directory, "nowcasts/data/actuals.csv"))
}