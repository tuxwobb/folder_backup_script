#!/bin/bash

set -e

echo "=== Creating sandbox environment ==="
SANDBOX=$(mktemp -d)
SRC="${SANDBOX}/source"
DST="${SANDBOX}/dest"
mkdir -p "${SRC}" "${DST}"

# Create dummy month folders
for m in 01 02 03 04 11 12; do
  mkdir -p "${SRC}/${m}"
  echo "Test file" >"${SRC}/${m}/test.txt"
done

echo "Source: ${SRC}"
echo "Dest:   ${DST}"

echo
echo "=== Test 1: dry-run (SFTP mode) ==="
../upload_script.sh --dry-run "${SRC}"

echo
echo "=== Test 2: local copy ==="
../upload_script.sh "${SRC}" "${DST}"

echo
echo "=== Test 3: local move ==="
../upload_script.sh -m "${SRC}" "${DST}"

echo
echo "=== Test 4: combined verbose + dry-run + move ==="
../upload_script.sh -v -m --dry-run "${SRC}" "${DST}"

echo
echo "=== Sandbox directory left at: ${SANDBOX}"
echo "You may inspect it manually."
