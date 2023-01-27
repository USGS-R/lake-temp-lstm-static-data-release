
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

prep_lake_hypsography <- function(out_file, data_file, lakes_in_release, repo_path = '../lake-temperature-model-prep') {
  scipiper_freshen_files(data_file)
  
  # Load the full list of hypsography available and then  
  # filter out lakes that are not included in this release
  H_A_list <- readRDS(data_file)
  H_A_list_in_release <- H_A_list[names(H_A_list) %in% lakes_in_release]
  
  hypso_list <- purrr::map(H_A_list_in_release, function(H_A_df) {
    H_A_df %>% 
      mutate(depths = max(H) - H, areas = A) %>% 
      arrange(depths) %>% 
      select(depths, areas)
  })
  hypso_df <- purrr::map_df(hypso_list, ~as.data.frame(.x), .id="site_id")
  write_csv(hypso_df, out_file)
}

prep_lake_temp_obs <- function(out_file, data_file, lakes_in_release, earliest_prediction, repo_path = '../lake-temperature-model-prep') {
  scipiper_freshen_files(data_file)
  
  # Load temperature observations and filter to the appropriate lakes and dates
  temp_obs_all <- arrow::read_feather(data_file) %>% 
    filter(date >= as.Date(earliest_prediction)) %>% # Filter to the earliest date available
    filter(site_id %in% lakes_in_release) %>% # Filter to only sites included in the data release
    select(-source_id)
  
  # Save the CSV in a temporary location
  tmp_space <- tempdir()
  obs_csv <- file.path(tmp_space, 'lake_temperature_observations.csv')
  write_csv(temp_obs_all, obs_csv)
  
  # Compress the CSV into a single zip file in this directory
  zip::zip(out_file, files = obs_csv)
}
