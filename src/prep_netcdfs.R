
# This R file contains code that will compress NetCDF files created by the lake-temperature-process-models 
# pipeline and save into one or more zips. It will create a bash script with a line per NetCDF file that 
# needs to be compressed, execute that bash script, and then zip up the resulting compressed NetCDF files.

list_uncompressed_ncs <- function(tar_dir, group_regex = '.*') {
  
  # List out the files included in that directory and filter to only the 
  # ones match the `group_regex` (default is to match everything)
  ncs_all <- list.files(tar_dir, full.names=TRUE)
  ncs_out <- ncs_all[grepl(group_regex, ncs_all)]
  
  names(ncs_out) <- NULL # Drop names attribute
  return(ncs_out)
}

do_compression <- function(uncompressed_ncs, shell_fn, allow_skip = FALSE) {
  temp_dir_for_compression <- 'compress_tmp'
  if(!dir.exists(temp_dir_for_compression)) dir.create(temp_dir_for_compression)
  
  # Prep new file names
  uncompressed_ncs_fn <- basename(uncompressed_ncs)
  compressed_ncs_fn <- gsub('_gcm_', '_GCM_', gsub('_glm_', '_GLM_', gsub('_uncompressed', '', uncompressed_ncs_fn)))
  compressed_ncs <- file.path(temp_dir_for_compression, compressed_ncs_fn)
  
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
  full_cmds <- c('#!/bin/bash', compress_cmds)
  write_lines(full_cmds, shell_fn)
  
  # Actually do the compression
  message('Began compression')
  system(sprintf('bash %s', shell_fn))
  message('Completed compression')
  return(compressed_ncs)
}

# Use the two functions above to identify the NetCDF files from the other pipeline, compress
# each NetCDF individually, and then zip them up into a single file.
# `tar_dir` defaults to the GCM directory just so that the remake.yml file instructions can
# be shorter since the call to `prep_netcdfs` is repeated 6 times.
prep_netcdfs <- function(out_file, tar_dir = '../../lake-temp/lake-temperature-process-models/3_extract/out/lake_temp_preds_glm_gcm', group_regex = NULL, shell_fn = 'compress_ncs.sh') {
  
  # List out uncompressed NetCDF filepaths
  uncompressed_ncs <- list_uncompressed_ncs(tar_dir, group_regex)
  
  # Compress the files
  compressed_ncs <- do_compression(uncompressed_ncs, shell_fn)
  
  # Then zip them up (do this part with error handling)
  tryCatch({
    zip::zip(out_file, files = compressed_ncs)
  }, error = function(e) {
    error_to_catch <- sprintf('zip error: `Could not create zip archive `%s`` in file `zip.c:364`', out_file)
    time_since_mod <- difftime(Sys.time(), file.info(out_file)$mtime, units = 'mins')
    file_was_updated <- file.exists(out_file) & time_since_mod < 1
    if(file_was_updated & grepl(error_to_catch, e)) {
      # This error seems to pop up every time the GCM - Minnesota NetCDF file is included
      # and I think it has to do with how large it is. The zip is still created, though,
      # so we are just going to catch the error and keep going.
      message('Caught known error, but file was still created. Continuing on.')
    } else {
      stop(sprintf('Tried to catch the error, but couldnt:\n\n%s', e))
    }
  })
  
  # Clean up the intermediate file that we won't need outside of this function
  file.remove(shell_fn)
  return(out_file)
}
