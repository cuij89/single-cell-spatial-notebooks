#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Download the GSE193911 subset used by this notebook.
#
# GSE193911 — Onkar, Cui, Zou et al., Nature Cancer 2023
#   "Immune landscape in ER+ breast cancer subtypes identifies a differential
#    role for macrophages"
#
# The full series has 27 samples. This notebook uses a balanced 6-patient
# subset. Six patients were hashed (PBMC and TIL on one lane); five more
# contribute separate libraries whose compartment is already known, which
# lifts the tumour comparison to 5 IDC vs 6 ILC.
# A seventh patient (BC2) is downloaded as well. Its hashing failed, and the
# notebook keeps it only long enough to show how that is detected and why it
# is excluded — see the demultiplexing section.
# Every patient was hashed so that peripheral blood (PBMC) and tumour
# (TIL) were loaded on the same 10x lane, which gives a crossed
# subtype x compartment design with the patient as the unit of replication.
#
# Each patient contributes two archives:
#   *_GEX.tar.gz      gene expression matrix (10x triplet)
#   *_CITEseq.tar.gz  TotalSeq hashtag matrix used to recover PBMC vs TIL
#
# Total download is roughly 35 MB.
#
# Usage:  bash 00_download_data.sh [target_dir]      (default: ./data)
# ---------------------------------------------------------------------------
set -euo pipefail

DEST="${1:-$(cd "$(dirname "$0")" && pwd)/data}"
mkdir -p "$DEST"
cd "$DEST"

# gsm : archive file name : patient : subtype : assay : compartment
#
# "hashed" means PBMC and TIL share a lane and the compartment has to be
# recovered from the hashtag matrix. The BC11-BC15 samples were run as
# separate libraries, so their compartment is known from the GEO title and
# they need no demultiplexing — they join the analysis after §2.
SAMPLES=(
  # --- hashed: PBMC + TIL pooled, HTO required -----------------------------
  "GSM5823462:GSM5823462_BC1_PBMC_TIL_GEX.tar.gz:BC1:ILC:GEX:hashed"
  "GSM5823479:GSM5823479_BC1_PBMC_TIL_CITEseq.tar.gz:BC1:ILC:HTO:hashed"
  "GSM5823465:GSM5823465_BC4_PBMC_TIL_GEX.tar.gz:BC4:ILC:GEX:hashed"
  "GSM5823482:GSM5823482_BC4_PBMC_TIL_CITESEQ.tar.gz:BC4:ILC:HTO:hashed"
  "GSM5823466:GSM5823466_BC5_PBMC_TIL_GEX.tar.gz:BC5:ILC:GEX:hashed"
  "GSM5823483:GSM5823483_BC5_PBMC_TIL_CITESEQ.tar.gz:BC5:ILC:HTO:hashed"
  "GSM5823463:GSM5823463_BC2_PBMC_TIL_GEX.tar.gz:BC2:IDC:GEX:hashed"
  "GSM5823480:GSM5823480_BC2_PBMC_TIL_CITEseq.tar.gz:BC2:IDC:HTO:hashed"
  "GSM5823464:GSM5823464_BC3_PBMC_TIL_GEX.tar.gz:BC3:IDC:GEX:hashed"
  "GSM5823481:GSM5823481_BC3_PBMC_TIL_CITEseq.tar.gz:BC3:IDC:HTO:hashed"
  "GSM5823467:GSM5823467_BC6_PBMC_TIL_GEX.tar.gz:BC6:IDC:GEX:hashed"
  "GSM5823484:GSM5823484_BC6_PBMC_TIL_CITESEQ.tar.gz:BC6:IDC:HTO:hashed"
  "GSM5823469:GSM5823469_BC8_PBMC_TIL_GEX.tar.gz:BC8:IDC:GEX:hashed"
  "GSM5823486:GSM5823486_BC8_PBMC_TIL_CITESEQ.tar.gz:BC8:IDC:HTO:hashed"
  # --- separate libraries: compartment already known -----------------------
  "GSM5823472:GSM5823472_BC11_TIL_GEX.tar.gz:BC11:ILC:GEX:TIL"
  "GSM5823473:GSM5823473_BC12_TIL_GEX.tar.gz:BC12:ILC:GEX:TIL"
  "GSM5823474:GSM5823474_BC13_PBMC_GEX.tar.gz:BC13:IDC:GEX:PBMC"
  "GSM5823475:GSM5823475_BC13_TIL_GEX.tar.gz:BC13:IDC:GEX:TIL"
  "GSM5823476:GSM5823476_BC14_TIL_GEX.tar.gz:BC14:IDC:GEX:TIL"
  "GSM5823477:GSM5823477_BC15_PBMC_GEX.tar.gz:BC15:ILC:GEX:PBMC"
  "GSM5823478:GSM5823478_BC15_TIL_GEX.tar.gz:BC15:ILC:GEX:TIL"
)

geo_url () {                       # GEO serves per-sample suppl files here
  local gsm="$1" fname="$2"
  echo "https://ftp.ncbi.nlm.nih.gov/geo/samples/${gsm:0:7}nnn/${gsm}/suppl/${fname}"
}

echo "patient,subtype,assay,gsm,dir,compartment" > sample_manifest.csv

for entry in "${SAMPLES[@]}"; do
  IFS=: read -r gsm fname patient subtype assay compartment <<< "$entry"
  if [ ! -f "$fname" ]; then
    echo "  downloading $patient ($subtype, $assay, $compartment) ..."
    curl -fsSL -o "$fname" "$(geo_url "$gsm" "$fname")"
  else
    echo "  cached      $patient ($subtype, $assay, $compartment)"
  fi
  # each archive holds a single directory with the 10x triplet.
  # ( ... ) with pipefail off: `head -1` closes the pipe early and would
  # otherwise make tar exit on SIGPIPE and trip `set -e`.
  dir=$(set +o pipefail; tar -tzf "$fname" | head -1 | cut -d/ -f1)
  [ -d "$dir" ] || tar -xzf "$fname"
  echo "$patient,$subtype,$assay,$gsm,$dir,$compartment" >> sample_manifest.csv
done

echo
echo "done. $(ls -d */ 2>/dev/null | wc -l) directories in $DEST"
echo "manifest: $DEST/sample_manifest.csv"
