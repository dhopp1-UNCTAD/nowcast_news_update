# UNCTAD Nowcast news update
All files related to the UNCTAD nowcast news update. This repo only hosts the code, for datafiles see the onedrive link below.

## Links:
- [Git repo](https://github.com/dhopp1-UNCTAD/nowcast_news_update)
- [OneDrive](https://unitednations-my.sharepoint.com/personal/daniel_hopp_un_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdaniel%5Fhopp%5Fun%5Forg%2FDocuments%2Fnowcasts%2Fnowcast%5Fnews%5Fupdate)

## Setup instructions
- Download the entire `nowcast_news_update` folder from OneDrive to your computer.
- Install necessary R packages: `tidyverse`, `nowcastDFM`. For `nowcastDFM` follow install instructions [here](https://github.com/dhopp1-UNCTAD/nowcastDFM).

## Update instructions
- in the `update_news.r` file, at the top, set the following parameters:
	- `reestimate_model`: whether or not to reestimate a new DFM model on the latest data.
	- `newest_database`: the date of the newest/latest database. Leave as NA to automatically take the latest one.
	- `second_newest_database`: the date of the database prior to the latest. We want to calculate the news between this prior data and the newest data. Leave NA to calculate automatically.
	- `which_model`: the date of the estimated DFM model you want to run, if `reestimate_model` set to false. Leave as NA to automatically take the latest model.
	- `target_variable`: a string of either "x\_world" for global trade value, "x\_vol\_world2" for global trade volume, "x\_servs\_world" for global trade in services.
	- `target_period`: the date you want to be forecasting for. E.g. `as.Date("2020-06-01")` for Q2, 2020, etc.
	- `output_directory` and `helper_directory`: the file paths of the output and helper directory of the [nowcast\_data\_update](https://unitednations-my.sharepoint.com/personal/daniel_hopp_un_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdaniel%5Fhopp%5Fun%5Forg%2FDocuments%2Fnowcasts%2Fnowcast%5Fdata%5Fupdate). This contains the databases and catalog, respectively.
	- `historical_news_directory` and `estimated_models_directory`: the file paths of these two directories contained in this, `nowcast_news_update`, folder.

- now run the `update_news.r` file, which will create three files in the directory of `historical_news/target_variable/target_period/`:
	- `old_date_to_new_date_news.rds`: where `old_date` and `new_date` are `newest_database` and `second_newest_database` dates. This is the output of the `gen_news` function of the `nowcastDFM` package, containing all informating regarding the news between the two datasets.
	- `new_date_plot_data.csv`: a CSV containing the development of the forecast of the target over past historical news runs, as well as the impact of data revisions and each variable on the forecast.
	- `new_date_plot_data.png`: a png plot of the development of the forecast and impact of data releases on it.
	- the update is finished, now upload the whole `nowcast_news_update` folder back to OneDrive. You may have to delete the existing folder first.
