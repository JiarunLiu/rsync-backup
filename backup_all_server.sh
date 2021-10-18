#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Backup files for all server in one scripts.
#
# Author: Jiarun Liu
# Date: 2021/10/12
# 
# -----------------------------------------------------------------------------


fn_log_info()  { echo "$APPNAME: $1"; }
fn_log_warn()  { echo "$APPNAME: [WARNING] $1" 1>&2; }
fn_log_error() { echo "$APPNAME: [ERROR] $1" 1>&2; }

fn_read_from_list() {
    BACKUP_LIST=()
    fn_log_info "Loading backup list..."
    while read line
    do
        # This will delete all blank lines and lines started with "#" or " "
        if [ -z "${line}" ]; then 
            # echo "BLANK: ${line}"
            continue
        elif [ "${line: 0:1}" = "#" ]; then
            # echo "COMMENT: ${line}"
            continue 
        else
            BACKUP_LIST=("${BACKUP_LIST[@]}" "${line}")
        fi
    done < $1

    # Remove duplicated item
    BACKUP_LIST=($(awk -v RS=' ' '!a[$1]++' <<< ${BACKUP_LIST[@]}))

    echo "============================ BACKUP LIST ============================"
    # for backup_host in ${BACKUP_LIST[@]}; do
    for ((i=0;i<${#BACKUP_LIST[*]};i++)); do
        echo " # ${i}:"$'\t'"${BACKUP_LIST[i]}"
    done
    echo "---------------------------------------------------------------------"
    fn_log_info "Total ${#BACKUP_LIST[*]} backup directories."
    echo "====================================================================="
}

fn_backup_marker_path() { echo "$1/backup.marker"; }

fn_write_md5_info() {
    # $1: MD5CODE
    # $2: HOST_INFO

    if [ ! -f "${MD5_FILE}" ]; then
        fn_log_info "generating md5 list file: ${MD5_FILE}"
        touch "${MD5_FILE}"
    fi

    local md5_info="${2} ${1}"

    # if md5 not logged, write md5 code to log file
    if [ $(grep -c "${md5_info}" "${MD5_FILE}") -eq 0 ]; then
        fn_log_warn "Writing MD5_INFO to ${MD5_FILE}"
        echo "${md5_info}" >> "${MD5_FILE}"
    fi

    local md5_count=$(grep -c ${1} ${MD5_FILE})
    local info_count=$(grep -c ${2} ${MD5_FILE})

    # Avoid potential md5 code mismatch
    if [ ${info_count} -gt 1 ]; then
        fn_log_error "MD5 Encoding ERROR"
        fn_log_error "Current MD5: ${1}"
        fn_log_error "Current Info: ${2}"
        fn_log_error "# INFO & MD5: ${info_count} vs ${md5_count}"
    fi

}

fn_init_md5_code() {
    fn_log_info "Generating MD5CODE by Str: ${1}"
    md5_output=($(echo "$1" | md5sum))
    MD5CODE=${md5_output[0]}
    fn_log_info "Generated MD5CODE: ${MD5CODE}"
}

fn_name_backup_dir() {
    fn_init_md5_code "${HOST_DIR}"
    BACKUP_DIR="${BACKUP_ROOT}/${HOST_IP}-${HOST_USER}-${MD5CODE}"
    fn_log_info "Update BACKUP_DIR: ${BACKUP_DIR}"
}

fn_init_backup_dir() {
    # get md5 code and backup_dir
    fn_name_backup_dir
    fn_log_info "Backup directory: ${BACKUP_DIR}"

    # write md5 code to md5 list file
    fn_write_md5_info "${MD5CODE}" "${HOST_INFO}"

    # Ensure backup folder exists
    fn_log_info "Evaluating backup directory: ${BACKUP_DIR}"
    if [ ! -d "${BACKUP_DIR}" ]; then
        # Create BACKUP_DIR and backup marker if it doesn't exists
        fn_log_warn "Creating directory for first time backup."
        eval "mkdir -p -- \"$BACKUP_DIR\""
    fi

    # Ensure backup marker exists
    if [ ! -e "$(fn_backup_marker_path "$BACKUP_DIR")" ]; then
        # Create backup marker if it doesn't exists
        fn_log_warn "Creating backup marker in backup directory."
        eval "touch \"$(fn_backup_marker_path "$BACKUP_DIR")\""
    fi
}

fn_backup() {
    # Setting parameters
    IFS='@:' read -r -a h <<< "$1"
    HOST_USER="${h[0]}"
    HOST_IP="${h[1]}"
    HOST_DIR="${h[2]}"

    # make sure target backup file exists
    if ! ssh "${HOST_USER}@${HOST_IP}" test -e "${HOST_DIR}"; then 
        fn_log_error "Target backup file don't exists or can't accessed!!!"
        fn_log_error "We will skip the backup for: ${HOST_INFO}"
        return 0
    fi

    # initialize backup directory
    fn_init_backup_dir
    fn_log_info "Backup file from $1 to ${BACKUP_DIR}"
    
    # start backup script
    echo "=====================================================================" >> "${LOG_FILE}"
    echo "Starting an rsync backup for ${HOST_INFO}" >> "${LOG_FILE}"
    eval "bash "${BACKUP_SCRIPT} ${1} ${BACKUP_DIR}" >> "${LOG_FILE}""
}


# -----------------------------------------------------------------------------
# Parameters
# -----------------------------------------------------------------------------

BACKUP_ROOT="/backup/ailib/data" # directory to save backup data
BACKUP_FILE="backup_list.txt"  # servers to backup with ssh permited
BACKUP_SCRIPT="rsync_tmbackup.sh"  # backup script

MD5_FILE="md5_list.txt"  # save the relation between path and md5-code

# -----------------------------------------------------------------------------
# Starting Service
# -----------------------------------------------------------------------------

echo "################### `date` ####################"

# Swith to working path
CURPATH=$(cd "$(dirname "$0")"; pwd)
fn_log_info "Swich to script path: ${CURPATH}"
cd "$CURPATH"
fn_log_info "Working at $(pwd $CURPATH)"

fn_log_info "Starting File Backup Service..."
TOTAL_START_TIME=$(date +%s)

# -----------------------------------------------------------------------------
# Create Log file directory for rsync logging
# -----------------------------------------------------------------------------

LOG_FILE="rsync_logs/`date`.log"
LOG_FILE=$(echo "${LOG_FILE}" | sed  -e 's/ [ ]*/_/g' )
if [ ! -d "$(dirname "$LOG_FILE")" ]; then
    mkdir "$(dirname "$LOG_FILE")"
fi

# -----------------------------------------------------------------------------
# Load backup list
# -----------------------------------------------------------------------------

fn_read_from_list "${BACKUP_FILE}"

# -----------------------------------------------------------------------------
# Backup one-by-one for each server
# -----------------------------------------------------------------------------

fn_log_info "Start Backup!!!"
for HOST_INFO in ${BACKUP_LIST[@]}; do
    echo "---------------------------------------------------------------------"
    fn_log_info "Current backup: ${HOST_INFO}"

    current_start_time=$(date +%s)

    # backup
    fn_backup "${HOST_INFO}"
    
    current_end_time=$(date +%s)
    current_cost_time=$((current_end_time-$current_start_time))

    fn_log_info "Finished: ${HOST_INFO}"
    fn_log_info "Current elapsed time: $(($current_cost_time/3600)) Hour $(((current_cost_time%3600)/60)) Min $((current_cost_time%60)) Sec"
    fn_log_info "Current time: `date`"
done

echo "====================================================================="
TOTAL_END_TIME=$(date +%s)
TOTAL_COST_TIME=$((TOTAL_END_TIME-TOTAL_START_TIME))
fn_log_info "Total elapsed time: $(($TOTAL_COST_TIME/3600)) Hour $(((TOTAL_COST_TIME%3600)/60)) Min $(($TOTAL_COST_TIME%60)) Sec"
fn_log_info "All Backup Finished at: `date`"
echo "#####################################################################"
echo ""



