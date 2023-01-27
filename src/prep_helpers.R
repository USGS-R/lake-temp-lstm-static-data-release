
# Lakes included in LSTM represent the full footprint of what is included in this release
# The vector returned here is used for filtering other targets
prep_site_ids <- function(lstm_metadata_file) {
  read_csv(lstm_metadata_file) %>% 
    filter(lstm_predictions) %>% 
    pull(site_id)
}

prep_lake_locations <- function(data_file, lakes_in_release, repo_path = '../lake-temperature-model-prep') {
  scipiper_freshen_files(data_file)
  
  # Load lake centroids and filter to those included in this release
  readRDS(data_file) %>% 
    filter(site_id %in% lakes_in_release) 
}
