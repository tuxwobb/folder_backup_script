#!/bin/bash

# ========================
#       CONFIG
# ========================
SFTP_HOST="sftp.example.com"
SFTP_USER="username"
SFTP_TARGET_DIR="/remote/path"

# Use SSH key if needed
# SFTP_OPTIONS="-i /home/user/.ssh/id_rsa"
SFTP_OPTIONS=""

LOGGING=0
VERBOSE=0
LOCAL_DEST=""
TRANSFER_MODE="copy" # default copy
DRY_RUN=0

# ========================
#       HELP
# ========================
show_help() {
  echo "Usage: ${0} [options] <source_directory> [destination_directory]"
  echo
  echo "Options:"
  echo "  -l                Enable logging (via logger)"
  echo "  -v                Verbose output"
  echo "  -m                Move instead of copy"
  echo "  -d, --dry-run     Show actions but perform nothing"
  echo "  -h                Show this help"
  echo
  echo "Behavior:"
  echo "  - If destination_directory exists, transfer is done locally."
  echo "  - If destination_directory is missing, SFTP upload is used."
  echo "  - Default mode: copy"
  echo "  - With -m: move"
  echo
  echo "Examples:"
  echo "  ${0} /data/months                      # copy via SFTP"
  echo "  ${0} -m /data/months /archive         # move locally"
  echo "  ${0} -v -l --dry-run /data/months     # preview everything"
}

# ========================
#   Parse options
# ========================
while getopts ":lvmhd-:" option; do
  case ${option} in
  l) LOGGING=1 ;;
  v) VERBOSE=1 ;;
  m) TRANSFER_MODE="move" ;;
  d) DRY_RUN=1 ;;
  h)
    show_help
    exit 0
    ;;
  -)
    case "${OPTARG}" in
    dry-run) DRY_RUN=1 ;;
    *)
      echo "Error: Unknown option --${OPTARG}"
      exit 1
      ;;
    esac
    ;;
  \?)
    echo "Error: Invalid option"
    show_help
    exit 1
    ;;
  esac
done

shift $((OPTIND - 1))

# ========================
#   Validate source directory
# ========================
if [[ $# -lt 1 ]]; then
  echo "Error: Missing source directory"
  show_help
  exit 1
fi

SOURCE_DIR="${1}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Error: Source directory does not exist: ${SOURCE_DIR}"
  ((LOGGING)) && logger -t sftp_backup "ERROR: Source dir '${SOURCE_DIR}' does not exist"
  exit 1
fi

# ========================
#   Optional local destination
# ========================
if [[ $# -eq 2 ]]; then
  if [[ -d "${2}" ]]; then
    LOCAL_DEST="${2}"
    ((VERBOSE)) && echo "Local destination enabled → ${LOCAL_DEST}"
    ((LOGGING)) && logger -t sftp_backup "Local destination: ${LOCAL_DEST}"
  else
    echo "Error: Destination directory does not exist: ${2}"
    exit 1
  fi
fi

# ========================
#   Current month
# ========================
CURRENT_MONTH=$(date +%m)
CURRENT_MONTH=$((10#${CURRENT_MONTH}))

((VERBOSE)) && echo "Current month: ${CURRENT_MONTH}"
((VERBOSE)) && echo "Transfer mode: ${TRANSFER_MODE}"
((VERBOSE)) && ((DRY_RUN)) && echo "DRY RUN MODE ENABLED"
((LOGGING)) && logger -t sftp_backup "Start job (month ${CURRENT_MONTH}, mode ${TRANSFER_MODE}, dry ${DRY_RUN})"

# ========================
#   SFTP upload function
# ========================
upload_sftp() {
  local folder_path="${1}"
  local folder_name="${2}"

  if ((DRY_RUN)); then
    echo "[DRY-RUN] Would upload to SFTP: ${folder_name}"
    echo "[DRY-RUN]   mkdir ${SFTP_TARGET_DIR}/${folder_name}"
    echo "[DRY-RUN]   put -r \"${folder_path}\" ${SFTP_TARGET_DIR}/"
    ((LOGGING)) && logger -t sftp_backup "DRY-RUN: Would upload ${folder_name}"
    return 0
  fi

  echo "Uploading to SFTP: ${folder_name}"
  ((LOGGING)) && logger -t sftp_backup "Uploading via SFTP: ${folder_name}"

  local TMPFILE
  TMPFILE=$(mktemp)

  cat >"${TMPFILE}" <<EOF
mkdir ${SFTP_TARGET_DIR}/${folder_name}
put -r "${folder_path}" ${SFTP_TARGET_DIR}/
EOF

  sftp ${SFTP_OPTIONS} "${SFTP_USER}@${SFTP_HOST}" <"${TMPFILE}"
  local RESULT=$?

  rm -f "${TMPFILE}"

  if ((RESULT != 0)); then
    echo "❌ SFTP upload failed: ${folder_name}"
    ((LOGGING)) && logger -t sftp_backup "ERROR: Upload failed for ${folder_name}"
    return 1
  fi

  echo "✅ Uploaded: ${folder_name}"
  ((LOGGING)) && logger -t sftp_backup "Uploaded: ${folder_name}"
  return 0
}

# ========================
#   Local copy/move function
# ========================
transfer_local() {
  local folder_path="${1}"
  local folder_name="${2}"

  if ((DRY_RUN)); then
    echo "[DRY-RUN] Would ${TRANSFER_MODE} ${folder_path} -> ${LOCAL_DEST}/"
    ((LOGGING)) && logger -t sftp_backup "DRY-RUN: Would ${TRANSFER_MODE} ${folder_name} locally"
    return
  fi

  echo "Local ${TRANSFER_MODE}: ${folder_name}"
  if [[ "${TRANSFER_MODE}" == "copy" ]]; then
    cp -r "${folder_path}" "${LOCAL_DEST}/"
  else
    mv "${folder_path}" "${LOCAL_DEST}/"
  fi

  if [[ $? -ne 0 ]]; then
    echo "❌ Local ${TRANSFER_MODE} failed: ${folder_name}"
    ((LOGGING)) && logger -t sftp_backup "ERROR: Local ${TRANSFER_MODE} failed: ${folder_name}"
  else
    echo "✅ Local ${TRANSFER_MODE} OK: ${folder_name}"
    ((LOGGING)) && logger -t sftp_backup "Local ${TRANSFER_MODE}: ${folder_name}"
  fi
}

# ========================
#   Process month folders
# ========================
for dir in "${SOURCE_DIR}"/*; do
  if [[ -d "${dir}" ]]; then
    folder=$(basename "${dir}")

    # must match 01..12
    if [[ ${folder} =~ ^[0-9]{2}$ ]]; then
      folder_month=$((10#${folder}))

      if ((folder_month != CURRENT_MONTH)); then
        ((VERBOSE)) && echo "Processing: ${folder}"

        # Local mode
        if [[ -n "${LOCAL_DEST}" ]]; then
          transfer_local "${dir}" "${folder}"
          continue
        fi

        # SFTP mode
        upload_sftp "${dir}" "${folder}"
        if [[ $? -eq 0 && "${TRANSFER_MODE}" == "move" ]]; then
          if ((DRY_RUN)); then
            echo "[DRY-RUN] Would remove: ${dir}"
            ((LOGGING)) && logger -t sftp_backup "DRY-RUN: Would rm ${dir}"
          else
            rm -rf "${dir}"
            echo "✅ Removed after upload: ${folder}"
            ((LOGGING)) && logger -t sftp_backup "Removed source ${folder}"
          fi
        fi

      else
        echo "Skipping current month: ${folder}"
        ((LOGGING)) && logger -t sftp_backup "Skip: ${folder}"
      fi

    else
      echo "Skipping invalid folder name: ${folder}"
      ((LOGGING)) && logger -t sftp_backup "Invalid folder ${folder}"
    fi
  fi
done

echo "Done."
((LOGGING)) && logger -t sftp_backup "Job finished."
