# ------------------------------------------------------------------------------
# args
# ------------------------------------------------------------------------------
library(argparse)
parser <- argparse::ArgumentParser()
parser$add_argument('--sub', type = 'character', help = 'subject id', required = TRUE)
parser$add_argument("--ses", type = "character", help = "session id", required = TRUE)
parser$add_argument('-i', "--in_dir", type = "character", help = "input nii directory", required = TRUE, nargs = '+')
parser$add_argument('-o', "--out_path", type = "character", help = "output csv path (default: <in_dir>/bids.csv)", default = NULL, required = FALSE)
args <- parser$parse_args()

# ------------------------------------------------------------------------------
# pkgs
# ------------------------------------------------------------------------------
pkgs <- c('stringr', 'dplyr', 'glue', 'rlang', 'jsonlite')
xfun::pkg_attach2(pkgs, message = F)

# ------------------------------------------------------------------------------
# opts
# ------------------------------------------------------------------------------
sub <- args$sub
ses <- args$ses

# ------------------------------------------------------------------------------
# paths
# ------------------------------------------------------------------------------
in_dir <- args$in_dir
if (is.null(args$out_path)) {
  out_path <- glue("{in_dir}/bids.csv")
} else {
  out_path <- args$out_path
}

# ------------------------------------------------------------------------------
# functions
# ------------------------------------------------------------------------------
# str_snake_to_camel <- function(str) {
#   str_parts <- str_split(str, "_|-") %>% unlist()
#   str_camel <- str_to_lower(str_parts[1])
#   if (length(str_parts) > 1) {
#     str_camel_tail <- paste0(str_to_title(str_parts[2:length(str_parts)]), collapse = '')
#     str_camel <- paste0(str_camel, str_camel_tail, collapse = '')
#   }
#   return(str_camel)
# }

get_acq <- function(in_path) {
  acq <- read_json(str_replace(in_path, '.nii.gz', '.json'))$ProtocolName %>% 
    str_to_lower() %>%
    str_replace_all(., '_', '-') %>%
    str_replace_all(., ' ', '-') %>%
    str_replace('-dir', '_dir') %>%
    str_split(., '_') %>%
    unlist() %>%
    .[[1]]
  return(acq)
}

get_datatype <- function(acq) {
  case_when(
    acq == "mprage" ~ "anat",
    acq == "3d-t2" ~ "anat",
    acq == "3d-t2-repeat" ~ "anat",
    acq == "hires-t2" ~ "anat",
    acq == "t2w-flair-2d" ~ "anat",
    str_detect(acq, "fmri-task-dj-run") ~ "func",
    str_detect(acq, "fmri-task-nback-run") ~ "func",
    acq == "noddi" ~ "dwi",
    str_detect(acq, 'swi') ~ "anat",
    acq == "tgse-pcasl-ve11c-multidelay" ~ "perf",
    str_detect(acq, 'b1map') ~ "fmap",
    str_detect(acq, "fmap") ~ "fmap",
    TRUE ~ NA
  )
}

get_suffix <- function(acq) {
  case_when(
    acq == "mprage" ~ "T1w",
    acq == "3d-t2" ~ "T2w",
    acq == "3d-t2-repeat" ~ "T2w",
    acq == "hires-t2" ~ "T2w",
    acq == "t2w-flair-2d" ~ "FLAIR",
    str_detect(acq, "fmri-task-dj-run") ~ "bold",
    str_detect(acq, "fmri-task-nback-run") ~ "bold",
    acq == "noddi" ~ "dwi",
    str_detect(acq, 'swi') ~ "MEGRE",
    acq == "tgse-pcasl-ve11c-multidelay" ~ "asl",
    str_detect(acq, 'b1map') ~ "TB1TFL",
    str_detect(acq, "fmap") ~ "epi",
    TRUE ~ NA
  )
}

get_echo <- function(in_path) {
  echo <- read_json(str_replace(in_path, '.nii.gz', '.json'))$EchoNumber %>%
    str_pad(., 2, 'left', 0)
  if (is_empty(echo)) {
    echo <- NA
  }
  return(echo)
}

get_part <- function(in_path) {
  acq <- get_acq(in_path)
  if (!str_detect(acq, 'swi')) {
    return(NA)
  }
  part <- read_json(str_replace(in_path, '.nii.gz', '.json'))$ImageType[[5]]
  if (part == 'PHASE') {
    part <- 'phase'
  } else {
    part <- 'mag'
  }
  return(part)
}

get_dir <- function(in_path) {
  acq <- get_acq(in_path)
  dir <- read_json(str_replace(in_path, '.nii.gz', '.json'))$PhaseEncodingDirection
  if (is_empty(dir)) {
    dir <- NA
  } else if (str_detect(acq, 'fmap') & dir == 'j') {
    dir <- 'PA'
  } else if (str_detect(acq, 'fmap') & dir == 'j-') {
    dir <- 'AP'
  } else {
    dir <- NA
  }
  return(dir)
}

rename_acq <- function(acq) {
  # not currently being used, might be dangerous? (need more thought)
  case_when(
    acq == "3d-t2" ~ "wb",
    acq == "3d-t2-repeat" ~ "wb",
    acq == "hires-t2" ~ "hc",
    acq == "swi-nounwrap" ~ "swi-no-unwrap",
    TRUE ~ acq
  )
}

get_task <- function(acq) {
  if (str_detect(acq, 'task-dj')) {
    task <- 'dj'
  } else if (str_detect(acq, 'task-nback')) {
    task <- 'nback'
  } else {
    task <- NA
  }
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
ses_pad <- str_pad(ses, 2, 'left', 0)
files <- list.files(in_dir, 
                    full.names = TRUE, 
                    pattern = '.nii.gz')

if (length(files) == 0) {
  stop(glue("[ERROR] no files found (in_dir: {in_dir})"))
}

cat('[INFO]\tobtaining key-value pairs\n')
acq_list <- unlist(lapply(files, get_acq))
datatype_list <- unlist(lapply(acq_list, get_datatype))
suffix_list <- as.character(unlist(lapply(acq_list, get_suffix)))
echo_list <- unlist(lapply(files, get_echo))
part_list <- unlist(lapply(files, get_part))
dir_list <- unlist(lapply(files, get_dir))
task_list <- unlist(lapply(acq_list, get_task))
cat('[INFO]\tcreating table\n')

files_dir <- basename(dirname(files))
files_clean <- str_remove(basename(files), '.nii.gz')
files_path <- glue("{files_dir}/{files_clean}")
df <- data.frame(original = files_path,
                 sub = sub,
                 ses = ses,
                 datatype = datatype_list,
                 task = task_list,
                 acq = acq_list,
                 dir = dir_list,
                 echo = echo_list,
                 part = part_list,
                 suffix = suffix_list) %>%
  group_by(datatype, acq, dir, echo, part, suffix) %>%
  mutate(run = str_pad(row_number(), side = 'left', 2, 0)) %>%
  ungroup() %>%
  as.data.frame() %>%
  select(sub, ses, datatype, task, acq, dir, run, echo, part, suffix, original) %>%
  arrange(datatype, suffix, task, acq, dir, run, echo, part)

key_order <- c('task', 'acq', 'dir', 'run', 'echo', 'part')

for (i in 1:nrow(df)) {
  datatype <- as.character(df[i, "datatype"])
  # cat(i, datatype, '\n')
  file <- glue("sub-{sub}/ses-{ses_pad}/{datatype}/sub-{sub}_ses-{ses_pad}")
  for (key in key_order) {
    value <- df[i, key]
    if (!is.na(value)) {
      file <- glue("{file}_{key}-{value}")
    }
  }
  suffix <- as.character(df[i, 'suffix'])
  file <- glue("{file}_{suffix}")
  if (!is.na(suffix)) {
    df[i, 'bids'] <- file
  }
}
print(df)

df_warn <- df %>%
  filter(is.na(bids)) %>%
  filter(acq != 'localizer')

if (nrow(df_warn) > 0) {
  warning("[WARN]\tthere are some files without bids names (excluding localizer)", immediate. = TRUE)
  print(df_warn)
}

cat('[INFO]\tsaving table\n')
write.csv(df, out_path, row.names = F)
cat('[INFO]\tfinished\n')