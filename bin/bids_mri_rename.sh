#!/bin/bash

# ------------------------------------------------------------------------------
# modules
# ------------------------------------------------------------------------------
module load bashHelperKennedyRodrigue
source bashHelperKennedyRodrigueFunctions.sh
module load R/3.6.0
# module load containers/r

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
# code_dir=`dirname $(realpath ${0})`
code_dir=$(which bids_mri_rename.sh)

declare -A in_paths
in_paths[nii_dir]="${root_dir}/study-${study}/sourcedata/nii_software-dcm2niix_v-1.0.20210317"
in_paths[table]="$(get_bids_dir ${study})/derivatives/bids_mri_tables_software-dcm2niix/sub-${sub}_ses-${ses}_3T.csv"

declare -A out_paths
out_paths[bids_dir]="$(get_bids_dir ${study})"
out_paths[bids_spec]="$(get_bids_dir ${study})/sub-${sub}/ses-0${ses}"

# ------------------------------------------------------------------------------
# check paths
# ------------------------------------------------------------------------------
check_in_paths ${in_paths[@]}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
cmd="Rscript ${code_dir}/bids_mri_rename.R \
--in_table ${in_paths[table]} \
--in_nii ${in_paths[nii_dir]} \
-o ${out_paths[bids_dir]}"
echo -e "\ncommand:\n${cmd}\n"
eval ${cmd}
ensure_permissions ${out_paths[bids_spec]}
# eval_cmd -c "${cmd}" -o ${out_paths[bids]} --overwrite ${overwrite} --print ${print}

# ------------------------------------------------------------------------------
# end
# ------------------------------------------------------------------------------
print_footer

