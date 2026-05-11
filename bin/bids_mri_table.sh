#!/bin/bash

# ------------------------------------------------------------------------------
# modules
# ------------------------------------------------------------------------------
module load bashHelperKennedyRodrigue
source bashHelperKennedyRodrigueFunctions.sh
module load R/3.6.0

# ------------------------------------------------------------------------------
# args
# ------------------------------------------------------------------------------
parse_args "${@}"
req_args=(study sub ses)
check_req_args ${req_args[@]}
print_header
set -e

# ------------------------------------------------------------------------------
# paths
# ------------------------------------------------------------------------------
root_dir=`get_root_dir kenrod`
code_dir=$(which bids_mri_table.sh)

declare -A in_paths
in_paths[dir]="${root_dir}/study-${study}/sourcedata/nii_software-dcm2niix_v-1.0.20210317/KENROD_DALLAS_????????_${sub}_${wave}_3T"

declare -A out_paths
out_paths[table]="${root_dir}/study-${study}/sourcedata/bids/derivatives/bids_mri_tables_software-dcm2niix/sub-${sub}_ses-${ses}_3T.csv"

# ------------------------------------------------------------------------------
# check paths
# ------------------------------------------------------------------------------
check_in_paths ${in_paths[@]}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
cmd="Rscript ${code_dir}/bids_mri_table.R \
-i ${in_paths[dir]} \
-o ${out_paths[table]} \
--sub ${sub} \
--ses ${ses}"
eval_cmd -c "${cmd}" -o ${out_paths[table]} --overwrite ${overwrite} --print ${print}

# ------------------------------------------------------------------------------
# end
# ------------------------------------------------------------------------------
print_footer

