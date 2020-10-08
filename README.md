# UNCTAD Nowcast news update
All files related to the UNCTAD nowcast news update. This repo only hosts the code, for datafiles see the onedrive link below.

## Links:
- [Git repo](https://github.com/dhopp1-UNCTAD/nowcast_news_update)
- [OneDrive](https://unitednations-my.sharepoint.com/personal/daniel_hopp_un_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdaniel%5Fhopp%5Fun%5Forg%2FDocuments%2Fnowcasts%2Fnowcast%5Fnews%5Fupdate)

## Setup instructions
- Download the entire `nowcast_news_update` folder from OneDrive to your computer.
- Install necessary R packages: `tidyverse`, `nowcastDFM`. For `nowcastDFM` follow install instructions [here](https://github.com/dhopp1-UNCTAD/nowcastDFM).

## Update instructions
- open the `gen_news_graphs.r` file and change parameters as necessary. They are:
	- `output_directory`: the location of the output data files from the nowcast data update on your computer. Equivalent to [this OneDrive directory](https://unitednations-my.sharepoint.com/personal/daniel_hopp_un_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdaniel%5Fhopp%5Fun%5Forg%2FDocuments%2Fnowcasts%2Fnowcast%5Fdata%5Fupdate%2Foutput).
	- `helper_directory`: the location of the helper files (catalog, etc.) from the nowcast data update on your computer. Equivalent to [this OndeDrive directory](https://unitednations-my.sharepoint.com/personal/daniel_hopp_un_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdaniel%5Fhopp%5Fun%5Forg%2FDocuments%2Fnowcasts%2Fnowcast%5Fdata%5Fupdate%2Fhelper).
	- `unctad_nowcast_web_directory`: the location of the repo for the UNCTAD nowcast bokeh web app. Comment out this entire line if you're not sure what this is.
	- `target_period`: the target date for the nowcast, e.g. Q3 2020 = `as.Date("2020-09-01")`
- on linux: close the file and run `Rscript gen_news_graph.r`
- on windows: highlight all the code in Rstudio and run
- this will create: 
	- a plot of the most recent nowcast, saved in `output/YYYY-MM-DD_target_plot.png`
	- a CSV of the data required for that plot, saved in `output/YYYY-MM-DD_target_plot_df.csv`. The `forecast` entries in that CSV show the evolution of the nowcast over time.
- upload the `output` directory to [OneDrive](https://unitednations-my.sharepoint.com/personal/daniel_hopp_un_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fdaniel%5Fhopp%5Fun%5Forg%2FDocuments%2Fnowcasts%2Fnowcast%5Fnews%5Fupdate) and finished.
