#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Download the GSE280318 subset used by this notebook.
#
# GSE280318 — Oliveira, Romero, Chung et al., Nature Genetics 2025
#   Visium HD (8 um bins) of human colorectal cancer.
#
# The series has five sections. This notebook uses the three tumour sections
# (P1, P2, P5), which are the ones carrying the published per-bin annotation.
#
# Two kinds of file:
#   *_Metadata.parquet.gz   per-bin coordinates, cell-type labels and the
#                           tumour/non-tumour call. ~11 MB each. Everything
#                           in the distance analysis runs off these alone.
#   *_filtered_feature_bc_matrix.h5
#                           the count matrix, needed only for the expression
#                           gradient in the last section. Downloaded for P1
#                           only, which is the smallest of the three.
#
# Total is roughly 150 MB.
#
# Usage:  bash 00_download_data.sh [target_dir]      (default: ./data)
# ---------------------------------------------------------------------------
set -euo pipefail

DEST="${1:-$(cd "$(dirname "$0")" && pwd)/data}"
mkdir -p "$DEST"
cd "$DEST"

# gsm : section : subtype-of-file
META=(
  "GSM8594567:P1CRC"
  "GSM8594568:P2CRC"
  "GSM8594569:P5CRC"
)
COUNTS=("GSM8594567:P1CRC")      # expression gradient is shown for one section

geo_url () {
  local gsm="$1" fname="$2"
  echo "https://ftp.ncbi.nlm.nih.gov/geo/samples/${gsm:0:7}nnn/${gsm}/suppl/${fname}"
}

fetch () {                       # fetch <url> <outfile>
  if [ -f "$2" ]; then echo "  cached      $2"; return; fi
  echo "  downloading $2 ..."
  curl -fsSL -o "$2.part" "$1"
  mv "$2.part" "$2"
}

echo "section,metadata,counts" > section_manifest.csv

for entry in "${META[@]}"; do
  IFS=: read -r gsm sec <<< "$entry"
  f="${gsm}_${sec}_Metadata.parquet.gz"
  fetch "$(geo_url "$gsm" "$f")" "$f"
  [ -f "${sec}_Metadata.parquet" ] || gunzip -c "$f" > "${sec}_Metadata.parquet"

  counts=""
  for c in "${COUNTS[@]}"; do
    IFS=: read -r cgsm csec <<< "$c"
    if [ "$csec" = "$sec" ]; then
      h5="${cgsm}_${csec}_filtered_feature_bc_matrix.h5"
      fetch "$(geo_url "$cgsm" "$h5")" "$h5"
      counts="$h5"
    fi
  done
  echo "${sec},${sec}_Metadata.parquet,${counts}" >> section_manifest.csv
done

echo
echo "done. $(du -sh . | cut -f1) in $(basename "$DEST")/"
cat section_manifest.csv
