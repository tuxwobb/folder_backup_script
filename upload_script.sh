#!/bin/bash

# ========================
#       CONFIG
# ========================
SFTP_HOST="sftp_server"
SFTP_USER="user"
SFTP_TARGET_DIR="/path/to/destination"

# Use SSH key if needed
SFTP_OPTIONS="-i /home/user/.ssh/id_ed25519"

LOGGING=0
VERBOSE=0
TRANSFER_MODE="copy"
LOCAL_DEST=""

# ========================
#       HELP
# ========================
show_help() {
  cat <<EOF
Usage: ${0} [options] <source_directory> [destination_directory]

Options:
  -l                Enable logging (via logger)
  -v                Verbose output
  -m                Move instead of copy
  -h                Show this help

Behavior:
  - If destination_directory exists, transfer is done locally.
  - If destination_directory is missing, SFTP upload is used.
  - Default mode: copy
  - With -m: move
EOF
}

# ========================
#   Logging helpers
# ========================
log() {
  ((VERBOSE)) && echo "$1"
  ((LOGGING)) && logger -t sftp_backup "$1"
}

# ========================
#   Parse options
# ========================
while getopts ":lvmh-:" option; do
  case ${option} in
  l) LOGGING=1 ;;
  v) VERBOSE=1 ;;
  m) TRANSFER_MODE="move" ;;
  h)
    show_help
    exit 0
    ;;
  -)
    echo "Unknown option --${OPTARG}"
    exit 1
    ;;
  *)
    echo "Invalid option"
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

# ========================
#   Validate arguments
# ========================
[[ $# -lt 1 ]] && {
  echo "Missing source directory"
  exit 1
}

SOURCE_DIR="${1}"
[[ ! -d "${SOURCE_DIR}" ]] && {
  echo "Source directory does not exist"
  exit 1
}

if [[ $# -eq 2 ]]; then
  [[ -d "${2}" ]] || {
    echo "Destination directory does not exist"
    exit 1
  }
  LOCAL_DEST="${2}"
fi

# ========================
#   Helpers
# ========================
get_folder_year() {
  stat -c %y "$1" | cut -d'-' -f1
}

is_month_folder() {
  [[ "$1" =~ ^[0-9]{2}$ ]]
}

# ========================
#   SFTP upload
# ========================
upload_sftp() {
  local path="$1"
  local month="$2"
  local year="$3"

  log "Uploading ${year}/${month}"

  # Create year directory (ignore if exists)
  sftp ${SFTP_OPTIONS} "${SFTP_USER}@${SFTP_HOST}" <<EOF
mkdir ${SFTP_TARGET_DIR}/${year}
EOF

  # Create month directory
  sftp ${SFTP_OPTIONS} "${SFTP_USER}@${SFTP_HOST}" <<EOF
mkdir ${SFTP_TARGET_DIR}/${year}/${month}
EOF

  # Upload folder
  sftp ${SFTP_OPTIONS} "${SFTP_USER}@${SFTP_HOST}" <<EOF
put -r "${path}" ${SFTP_TARGET_DIR}/${year}/
EOF

  log "Uploaded ${year}/${month}"
}

# ========================
#   Local transfer
# ========================
transfer_local() {
  local path="$1"
  local month="$2"
  local year="$3"

  local target="${LOCAL_DEST}/${year}"

  mkdir -p "${target}"

  if [[ "${TRANSFER_MODE}" == "copy" ]]; then
    cp -r "${path}" "${target}/"
  else
    mv "${path}" "${target}/"
  fi

  log "Local ${TRANSFER_MODE}: ${year}/${month}"
}

# ========================
#   Main loop
# ========================
CURRENT_MONTH=$(date +%m | sed 's/^0//')

log "Start job (mode=${TRANSFER_MODE})"

for dir in "${SOURCE_DIR}"/*; do
  [[ -d "${dir}" ]] || continue

  folder=$(basename "${dir}")

  if ! is_month_folder "${folder}"; then
    log "Skipping invalid folder: ${folder}"
    continue
  fi

  folder_month=$((10#${folder}))
  folder_year=$(get_folder_year "${dir}")

  if ((folder_month == CURRENT_MONTH)); then
    log "Skipping current month: ${folder}"
    continue
  fi

  log "Processing ${folder_year}/${folder}"

  if [[ -n "${LOCAL_DEST}" ]]; then
    transfer_local "${dir}" "${folder}" "${folder_year}"
  else
    upload_sftp "${dir}" "${folder}" "${folder_year}"

    if [[ "${TRANSFER_MODE}" == "move" ]]; then
      rm -rf "${dir}"
      log "Removed ${folder}"
    fi
  fi
done

log "Job finished."
echo "Done."
