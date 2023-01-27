
# Lakes included in LSTM represent the full footprint of what is included in this release
# The vector returned here is used for filtering other targets. This can be used to identify
# any vector of `site_id` values as long as that column exists in the `in_file`.
prep_site_ids <- function(in_file, is_lstm = FALSE) {
  in_data <- read_csv(in_file)
  if(is_lstm) in_data <- filter(in_data, lstm_predictions)
  site_ids <- unique(in_data$site_id)
  return(site_ids)
}

prep_lake_locations <- function(data_file, lakes_in_release, repo_path = '../lake-temperature-model-prep') {
  scipiper_freshen_files(data_file, repo_path)
  
  # Load lake centroids and filter to those included in this release
  readRDS(data_file) %>% 
    filter(site_id %in% lakes_in_release) 
}

prep_lake_metadata <- function(out_file, lake_centroids_sf, lstm_metadata_file, glm_nldas_sites, glm_gcm_sites,
                               lake_gnis_names_file, lake_depths_file, repo_path = '../lake-temperature-model-prep') {
  
  scipiper_freshen_files(c(lake_gnis_names_file, lake_depths_file), repo_path)
  
  lake_metadata <- lake_centroids_sf %>% 
    st_coordinates() %>% 
    as_tibble() %>% 
    mutate(site_id = lake_centroids_sf$site_id) %>% 
    left_join(readRDS(lake_gnis_names_file), by = "site_id") %>% 
    left_join(ungroup(readRDS(lake_depths_file)), by = "site_id") %>% 
    # ADD LSTM-specific metadata
    left_join(read_csv(lstm_metadata_file), by = "site_id") %>% 
    # Remove sites that don't have any LSTM predictions (those are outside of our scope)
    filter(lstm_predictions) %>% 
    # Add three additional columns indicating whether a particular model is available for that site
    mutate(model_preds_ealstm_nldas = TRUE, # All sites here have EA-LSTM available (we used that to filter)
           model_preds_glm_nldas = site_id %in% glm_nldas_sites,
           model_preds_glm_gcm = site_id %in% glm_gcm_sites) %>% 
    # Rename and organize final columns
    select(site_id, 
           lake_name = GNIS_Name,
           state,
           centroid_lat = Y,
           centroid_lon = X,
           depth = lake_depth,
           area,
           elevation,
           model_preds_ealstm_nldas,
           model_preds_glm_nldas,
           model_preds_glm_gcm,
           ea_lstm_group = lstm_group)
  
  write_csv(lake_metadata, out_file)
  
  # TODO: Still need to add these columns:
  # NLDAS filepath (e.g. `readRDS('../lake-temperature-model-prep/7_config_merge/out/nml_meteo_fl_values.rds')`)
  # GCM filepath (NA if none)
}

prep_lake_hypsography <- function(out_file, data_file, lakes_in_release, repo_path = '../lake-temperature-model-prep') {
  scipiper_freshen_files(data_file, repo_path)
  
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
  scipiper_freshen_files(data_file, repo_path)
  
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
