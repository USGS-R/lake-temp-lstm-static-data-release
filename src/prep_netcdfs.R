
# This R file contains code that will compress NetCDF files created by the lake-temperature-process-models 
# pipeline and save into one or more zips. It will create a bash script with a line per NetCDF file that 
# needs to be compressed, execute that bash script, and then zip up the resulting compressed NetCDF files.

list_uncompressed_ncs <- function(tar_nm, tar_dir = '../lake-temperature-process-models', group_regex = '.*') {
  # In order to use targets helper functions, you need to be 
  # in the targets pipeline working directory.
  startwd <- getwd()
  setwd(tar_dir)
  
  # List out the files included in that target and filter to only the 
  # ones match the `group_regex` (default is to match everything)
  ncs_all <- targets::tar_read_raw(tar_nm)
  ncs_out <- ncs_all[grepl(group_regex, ncs_all)]
  
  names(ncs_out) <- NULL # Drop names attribute
  on.exit(setwd(startwd)) # Reset working directory
  return(ncs_out)
}

do_compression <- function(uncompressed_ncs, shell_fn, allow_skip = FALSE) {
  # Prep new file names
  uncompressed_ncs_dir <- dirname(uncompressed_ncs)
  uncompressed_ncs_fn <- basename(uncompressed_ncs)
  compressed_ncs_fn <- gsub('_gcm_', '_GCM_', gsub('_glm_', '_GLM_', gsub('_uncompressed', '', uncompressed_ncs_fn)))
  compressed_ncs <- file.path(uncompressed_ncs_dir, compressed_ncs_fn)
  
  if(allow_skip) {
    # Only compress ones that have not yet been compressed
    skip_file <- file.exists(compressed_ncs)
    uncompressed_ncs_to_compress <- uncompressed_ncs[!skip_file]
    compressed_ncs_to_compress <- compressed_ncs[!skip_file]
  } else {
    uncompressed_ncs_to_compress <- uncompressed_ncs
    compressed_ncs_to_compress <- compressed_ncs
  }
  
  # Prep compression command strings
  compress_cmds <- sprintf("ncks --overwrite -h --fl_fmt=netcdf4 --cnk_plc=g3d --cnk_dmn time,10 --ppc temp=.2#ice=1 %s %s",
                           uncompressed_ncs_to_compress, compressed_ncs_to_compress)
  full_cmds <- c('#!/bin/bash', 'module load nco', 'module load netcdf', compress_cmds)
  write_lines(full_cmds, shell_fn)
  
  # Actually do the compression
  message('Began compression')
  system(sprintf('bash %s', shell_fn))
  message('Completed compression')
  return(compressed_ncs)
}

# Use the two functions above to identify the NetCDF files from the other pipeline, compress
# each NetCDF individually, and then zip them up into a single file.
prep_netcdfs <- function(out_file, tar_nm, tar_dir = '../lake-temperature-process-models', group_regex = NULL, shell_fn = 'compress_ncs.sh') {
  
  # List out uncompressed NetCDF filepaths
  uncompressed_ncs <- list_uncompressed_ncs(tar_nm, tar_dir, group_regex)
  
  # Compress the files
  compressed_ncs <- do_compression(uncompressed_ncs, shell_fn, allow_skip = TRUE)
  message(paste(compressed_ncs, collapse='\n'))
  # Then zip them up
  zip::zip(out_file, files = compressed_ncs[-6])
  
  # Clean up the intermediate file that we won't need outside of this function
  file.remove(shell_fn)
  return(out_file)
}
