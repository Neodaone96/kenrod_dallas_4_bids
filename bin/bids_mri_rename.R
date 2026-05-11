# ------------------------------------------------------------------------------
# args
# ------------------------------------------------------------------------------
library(argparse)
parser <- argparse::ArgumentParser()
parser$add_argument("--in_table", type = "character", help = "path to bids table", required = TRUE)
parser$add_argument("--in_nii", type = "character", help = "path to original nii directory", required = TRUE)
parser$add_argument("-o", "--bids_dir", type = "character", help = "path to output bids directory", required = TRUE)
args <- parser$parse_args()

# ------------------------------------------------------------------------------
# pkgs
# ------------------------------------------------------------------------------
pkgs <- c('glue', 'dplyr')
xfun::pkg_attach2(pkgs, message = F)

# ------------------------------------------------------------------------------
# paths
# ------------------------------------------------------------------------------
# in_path <- "/Users/ekarinpongpipat/mnt/cvl/kenrod/study-pams/sourcedata/nii_software-dcm2niix_v-1.0.20210317/KENROD_PAMS_20221207_3056_1/bids.csv"
# bids_dir <- "/Users/ekarinpongpipat/mnt/cvl/kenrod/study-pams/sourcedata/bids"
in_nii <- args$in_nii
in_table <- args$in_table
bids_dir <- args$bids_dir

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
cat('[INFO]\treading table\n')
df <- read.csv(in_table) %>%
  filter(!is.na(suffix))
  
cat('[INFO]\trsyncing/renaming files\n')
for (i in 1:nrow(df)) {
  datatype_temp <- df[i, 'datatype']
  if (datatype_temp == 'dwi') {
    ext_list <- c(".bval", ".bvec", ".json", ".nii.gz")
  } else {
    ext_list <- c(".json", ".nii.gz")
  }
  for (ext in ext_list) {
    in_temp <- glue("{in_nii}/{df[i, 'original']}{ext}")
    out_temp <- glue("{bids_dir}/{df[i, 'bids']}{ext}")
    out_dir_temp <- dirname(out_temp)
    if (!dir.exists(out_dir_temp)) {
      dir.create(out_dir_temp, recursive = TRUE)
    }
    cmd <- glue("rsync -u {in_temp} {out_temp}")
    cat(i, cmd, "\n")
    system(cmd)
  }
}
cat('[INFO]\tfinished\n')
