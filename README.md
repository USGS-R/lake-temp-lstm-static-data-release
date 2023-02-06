# slim-data-release-template


## code

Need to have non-CRAN packages`dssecrets`, `meddle`, and `scipiper` installed, among other packages. 
Need to have CRAN package `sbtools` installed

- Create a data release or create a child item on sciencebase to experiment on
- Add "write" permissions on the release item for `cidamanager` (this is the `dssecrets` service account)
- Change the files and the functions in `src/` to what you need
- Edit data release information in `in_text/text_data_release.yml` to fit your data release and your file names and contents
- modify the sciencebase indentifier to your parent data release identifier (should be a string that is something like "5faaac68d34eb413d5df1f22")
- run `scmake()` (see `building this pipeline` section below for details)
- validate your `out_xml/fgdc_metadata.xml` file with the [validator tool](https://mrdata.usgs.gov/validation/)
- fix any validation errors (usually this requires filling in metadata information in the `in_text/text_data_release.yml` and perhaps looking a the [metadata template](https://raw.githubusercontent.com/USGS-R/meddle/master/inst/extdata/FGDC_template.mustache))
- win

## building this pipeline

For this pipeline specifically, it is being built on the USGS Tallgrass HPC system. Follow instructions in the DSP manual in order to start an R session on Tallgrass. Since the code uses `scipiper::gd_get()` along with `lake-temperature-model-prep`, you will likely need to setup authorization to the Google Drive folder if you are to build targets the call `scipiper_freshen_files()`. To do so, follow these instructions.

To allow `gd_get()` to actually download files, you need to prep your credentials to avoid the browser-mediated authorization (does not work on the HPC systems). I used the "Project-level OAuth cache" section of [this vignette](https://cran.r-project.org/web/packages/gargle/vignettes/non-interactive-auth.html) to develop this workflow. 

*Step 1:* Locally, run the following to authorize GoogleDrive and create a token file. Important: DON'T COMMIT THIS FILE ANYWHERE. You only need to do this the one time. Once you have this setup, you can skip to Step 3.

```
options(gargle_oauth_cache = ".secrets")
googledrive::drive_auth(cache = ".secrets")
```

*Step 2:* Upload the file to the `.secrets/` directory in `lake-temperature-model-prep/` on Caldera. Be sure that `.secrets/*` appears in the gitignore (it already should, but please check!).

*Step 3:* Verify that the authorization will work by running the following code. If it returns at least one file, then you can carry on with the build. The `options()` here will need to be run every time you are building the pipeline (unless everything has been "freshened" already).

```
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = "YOUREMAIL@gmail.com"
)
googledrive::drive_find(n_max = 1)
```
