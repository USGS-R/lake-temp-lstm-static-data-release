
prep_lake_locations <- function(data_file, lstm_metadata_file, repo_path = '../lake-temperature-model-prep') {
  scipiper_freshen_files(data_file)
  lake_centroids_sf <- readRDS(data_file) # Load lake centroids
  lstm_lakes <- read_csv(lstm_metadata_file) %>% filter(lstm_predictions) %>% pull(site_id)
  lake_centroids_sf_lstm <- lake_centroids_sf %>% filter(site_id %in% lstm_lakes) # Filter lake centroids sf object to LSTM lakes only
  return(lake_centroids_sf_lstm)
}
