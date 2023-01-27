
# Lakes included in LSTM represent the full footprint of what is included in this release
# The vector returned here is used for filtering other targets. This can be used to identify
# any vector of `site_id` values as long as that column exists in the `in_file`.
prep_site_ids <- function(in_file, is_lstm = FALSE) {
  in_data <- read_csv(in_file)
  if(is_lstm) in_data <- filter(in_data, lstm_predictions)
  site_ids <- unique(in_data$site_id)
  return(site_ids)
}

prep_lake_locations <- function(data_file, lakes_in_release, repo_path = '../lake-temperature-model-prep/') {
  scipiper_freshen_files(data_files = data_file, repo_path = repo_path)
  
  # Load lake centroids and filter to those included in this release
  readRDS(data_file) %>% 
    filter(site_id %in% lakes_in_release) 
}

prep_lake_metadata <- function(out_file, lake_centroids_sf, lstm_metadata_file, glm_nldas_sites, glm_gcm_sites,
                               lake_gnis_names_file, lake_depths_file, repo_path = '../lake-temperature-model-prep/') {
  
  scipiper_freshen_files(data_files = c(lake_gnis_names_file, lake_depths_file), repo_path = repo_path)
  
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

prep_lake_id_crosswalk <- function(out_file, all_crosswalk_files, lakes_in_release, repo_path = '../lake-temperature-model-prep/') {
  
  # Get all crosswalk RDS files locally (takes a long time if you don't have them):
  crosswalk_inds <- all_crosswalk_files[grepl('.ind', all_crosswalk_files)]
  scipiper_freshen_files(ind_files = crosswalk_inds, repo_path = repo_path)
  
  # Now that all inds have a corresponding data file, we can reset the list 
  # of crosswalk RDS files then filter to just the crosswalks we want to use
  crosswalk_files <- gsub('.ind', '', crosswalk_inds)
  crosswalk_files <- crosswalk_files[!grepl('gnis|Iowa|isro|lake_to_state|navico|norfork|univ_mo|wqp', crosswalk_files)]
  
  # Load in the crosswalks
  crosswalks_raw <-purrr::map(crosswalk_files, readRDS) %>% setNames(basename(crosswalk_files))
  
  # Select only the site_id and xwalk id columns + harmonize some of the xwalks naming patterns
  crosswalks <- purrr::map2(crosswalks_raw, names(crosswalks_raw), function(xwalk, xwalk_nm) {
    
    # Special fixes to harmonize crosswalk IDs to follow our patterns
    if(grepl('micorps', xwalk_nm, ignore.case=T)) {
      names(xwalk) <- c('MICORPS_ID', 'site_id')
      xwalk[['MICORPS_ID']] <- sprintf('MICORPS_%s', xwalk[['MICORPS_ID']])
    }
    
    if(grepl('winslow', xwalk_nm, ignore.case=T)) {
      xwalk[['WINSLOW_ID']] <- as.character(xwalk[['WINSLOW_ID']])
    }
    
    # Edit lagos xwalk_nm before it gets used to match the id_col (need to change lagosus to lagos)
    if(grepl('lagosus', xwalk_nm)) {
      xwalk_nm <- 'lagos_nhdhr_xwalk.rds'
    }
    
    # Select only the organization ID and site_id columns
    id_col <- names(xwalk)[grepl(gsub('_nhdhr_xwalk.rds', '', xwalk_nm), names(xwalk), ignore.case = TRUE)]
    xwalk_updated <- xwalk[,c('site_id', id_col)]
    
    # Capitalize some of the actual site id prefixes that are not currently capitalized
    need_capitalization_regex <- 'iadnr|lagos|mndow|mo_usace|ndgf'
    if(grepl(need_capitalization_regex, id_col, ignore.case=T)) {
      # All column names should be capitalized, except `site_id`
      cap_id_col <- toupper(id_col)
      names(xwalk_updated) <- c('site_id', cap_id_col)
      
      # Now replace prefixes with uppercase versions
      xwalk_updated[[cap_id_col]] <- gsub(need_capitalization_regex, gsub("_ID", "", cap_id_col), xwalk_updated[[cap_id_col]])
    }
    
    return(xwalk_updated)
  })
  
  # Join them all together into a single crosswalk
  crosswalks_all <- purrr::reduce(crosswalks, full_join, by="site_id") %>% 
    select(site_id, order(colnames(.))) %>% 
    # Filter to site_ids that appear in our models but use `right_join()` to
    # keep the modeled sites that don't appear in any of the crosswalks
    right_join(tibble(site_id = lakes_in_release), by = "site_id")
  
  write_csv(crosswalks_all, out_file)
  
}

prep_lake_hypsography <- function(out_file, data_file, lakes_in_release, repo_path = '../lake-temperature-model-prep/') {
  scipiper_freshen_files(data_files = data_file, repo_path = repo_path)
  
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

prep_lake_temp_obs <- function(out_file, data_file, lakes_in_release, earliest_prediction, repo_path = '../lake-temperature-model-prep/') {
  scipiper_freshen_files(data_files = data_file, repo_path = repo_path)
  
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
