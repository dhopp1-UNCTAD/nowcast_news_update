library(tidyverse)
library(nowcastDFM)

output_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/output/" # location of the database files from nowcast_data_update
helper_directory <- "/home/danhopp/dhopp1/UNCTAD/nowcast_data_update/helper/" # location of helper files, like catalog.csv, from nowcast_data_update
catalog <- read_csv(paste0(helper_directory, "catalog.csv"))

### helper functions
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
  
  actual <- data[data$date == target_period, target_variable] * 100
  p <- ggplot() + 
    geom_bar(data=filter(plot_df, series != "forecast"), aes(x=date_forecast, y=value, fill=series), stat="identity") +
    geom_line(data=filter(plot_df, series == "forecast"), aes(x=date_forecast, y=value, color=series)) +
    scale_color_manual(values="black") +
    labs(y = "%", x="Date forecast made", color="", fill="Variable contribution") +
    ggtitle(paste0(target_variable, ", ", target_period, " forecast evolution"))
  if (length(actual) > 0) {
    p <- p + geom_hline(aes(yintercept=actual), linetype="dashed", color="#444444") +# plotting actual as a dotted line
      annotate("text", dates_list[1], actual, vjust = 1, label = paste0("Actual")) 
  }
  
  return (list(p=p, plot_df=plot_df))
}

# lag a data according to publication lag
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
### helper functions

### generating plot for a time period and target
latest_database <- as.Date("2020-09-15")
target_variable <- "x_vol_world2" # x_world, x_servs_world, x_vol_world2
data <- read_csv(paste0(output_directory, latest_database, "_database_tf.csv")) %>% data.frame
reestimate <- paste0("estimated_models/", target_variable, "/2020-01-01_", target_variable, "_output_dfm.rds") # put file path of esimtated dfm here, or TRUE to reestimate from catalog, e.g. "estimated_models/x_world/2020-01-01_x_world_output_dfm.rds"
target_period <- as.Date("2020-09-01")
save_directory <- "~/Downloads/"

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
database_dates <- c("2020-08-07","2020-08-16","2020-08-25", "2020-09-01", "2020-09-08", "2020-09-15")
which_months <- c((seq(target_period, length=4, by="-1 months") %>% sort), (seq(target_period, length=5, by="1 months") %>% sort)) %>% unique
which_months <- which_months[which_months < Sys.Date()]
which_months <- which_months[!(which_months %in% as.Date(database_dates))] # don't add dates already in the manual database dates
df_list <- list()
for (month in which_months) {
  df_list[[length(df_list)+1]] <- lag_data(data, catalog, month) %>% select(c("date", vars))
}
# add manual databases
if (T) {
  for (db_date in database_dates) {
    df_list[[length(df_list)+1]] <- read_csv(paste0(output_directory, db_date, "_database_tf.csv")) %>% data.frame %>% select(c("date", vars))
    which_months[length(which_months) + 1] <- as.Date(db_date)
  } 
}

rm("final_df")
result <- gen_news_graphs(output_dfm, target_variable, target_period, which_months, df_list)
result$p
ggsave(paste0(save_directory, "plot.png"), height=10, width=10)
plot_df <- result$plot_df
write_csv(plot_df, paste0(save_directory, "plot_df.csv"))