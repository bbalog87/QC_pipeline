#!/bin/bash

# =============================================================
# 🧬 QC Module: FastQC Pre/Post + MultiQC Summary
# Author: Julien Nguinkal
# Description:
#   This pipeline performs quality control in 4 steps:
#     1. FastQC on raw paired-end FASTQ reads
#     2. fastp trimming and filtering (output used only for re-analysis)
#     3. FastQC on trimmed reads
#     4. MultiQC summary report (FastQC only, clean and reproducible)
# ================================================================

# -------------------------------
# ⚙️ Safety & strict error handling
# -------------------------------
set -euo pipefail

# -------------------------------
# 🎨 Terminal Colors
# -------------------------------
GREEN='\033[1;32m'   # Success
RED='\033[1;31m'     # Error
YELLOW='\033[1;33m'  # Warning
BLUE='\033[1;36m'    # Info
BOLD='\033[1m'
NC='\033[0m'         # Reset

# -------------------------------
# 🧮 Default Parameters
# -------------------------------
THREADS=8
READS_DIR=""
OUTDIR=""

# -------------------------------
# 📘 Usage Function
# -------------------------------
usage() {
  echo -e "${BLUE}Usage: $0 -i <input_reads_folder> -o <output_folder> [-t <threads>]${NC}"
  echo -e "  -i   Folder with raw FASTQ files (required)"
  echo -e "  -o   Output folder for all results (required)"
  echo -e "  -t   Number of threads [default: 8]"
  echo -e "  -h   Show this help and exit"
  exit 1
}

# -------------------------------
# 🔍 Parse CLI Arguments
# -------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input) READS_DIR="$2"; shift 2 ;;
    -o|--outdir) OUTDIR="$2"; shift 2 ;;
    -t|--threads) THREADS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo -e "${RED}❌ Unknown option: $1${NC}"; usage ;;
  esac
done

# -------------------------------
# ✅ Validate Required Inputs
# -------------------------------
if [[ -z "$READS_DIR" || -z "$OUTDIR" ]]; then
  echo -e "${RED}❌ ERROR: Both -i and -o are required.${NC}"
  usage
fi

if [[ ! -d "$READS_DIR" ]]; then
  echo -e "${RED}❌ ERROR: Input folder '$READS_DIR' not found.${NC}"
  exit 1
fi

if ! mkdir -p "$OUTDIR" 2>/dev/null; then
  echo -e "${RED}❌ ERROR: Cannot create or write to output folder '$OUTDIR'${NC}"
  exit 1
fi

# -------------------------------
# Check Required Tools
# -------------------------------
for tool in fastqc fastp multiqc; do
  if ! command -v $tool &> /dev/null; then
    echo -e "${RED}❌ ERROR: Required tool '$tool' not found in PATH.${NC}"
    exit 1
  fi
done

# -------------------------------
# 📁 Define Folder Structure
# -------------------------------
RAW_FASTQC_DIR="$OUTDIR/fastqc_pre_trim"
TRIMMED_DIR="$OUTDIR/trimmed"
TRIMMED_FASTQC_DIR="$OUTDIR/fastqc_post_trim"
MULTIQC_DIR="$OUTDIR/multiqc"
LOGDIR="$OUTDIR/logs"

mkdir -p "$RAW_FASTQC_DIR" "$TRIMMED_DIR" "$TRIMMED_FASTQC_DIR" "$MULTIQC_DIR" "$LOGDIR"

# -------------------------------
# 🚀 Start QC Pipeline
# -------------------------------
echo -e "${BOLD}${BLUE}🔧 QC pipeline started at [$(date)]${NC}"
echo -e "${BLUE}📂 Output folder: $OUTDIR${NC}"

# =============================================================
#  STEP 1: FastQC on Raw Reads
# =============================================================
echo -e "\n${BLUE}▶ Step 1: FASTQC on raw reads...${NC}"
for r1 in "$READS_DIR"/*_R1_001.fastq.gz "$READS_DIR"/*_1.fastq.gz; do
  [[ -e "$r1" ]] || continue
  r2="${r1/_R1_001/_R2_001}"
  r2="${r2/_1./_2.}"
  [[ -f "$r2" ]] || { echo -e "${YELLOW}⚠️ Skipping $r1: R2 missing.${NC}"; continue; }
  sample=$(basename "$r1" | cut -d_ -f1-2)
  echo -e "${GREEN}➤ FASTQC (raw): $sample${NC}"
  fastqc -t "$THREADS" -o "$RAW_FASTQC_DIR" "$r1" "$r2" &> "$LOGDIR/${sample}_fastqc_raw.log"
done

# =============================================================
# ✂️ STEP 2: Trimming with fastp (only to generate improved input)
# =============================================================
echo -e "\n${BLUE}▶ Step 2: Trimming with fastp...${NC}"
for r1 in "$READS_DIR"/*_R1_001.fastq.gz "$READS_DIR"/*_1.fastq.gz; do
  [[ -e "$r1" ]] || continue
  r2="${r1/_R1_001/_R2_001}"
  r2="${r2/_1./_2.}"
  [[ -f "$r2" ]] || { echo -e "${YELLOW}⚠️ Skipping $r1: R2 missing.${NC}"; continue; }
  sample=$(basename "$r1" | cut -d_ -f1-2)
  outdir="$TRIMMED_DIR/$sample"; mkdir -p "$outdir"
  echo -e "${GREEN}➤ fastp: $sample${NC}"
  fastp \
    -i "$r1" -I "$r2" \
    -o "$outdir/${sample}_R1_trimmed.fastq.gz" \
    -O "$outdir/${sample}_R2_trimmed.fastq.gz" \
    -q 28 -p -g -l 40 --cut_tail -t 5 \
    -w "$THREADS" &> "$LOGDIR/${sample}_fastp.log"
done

# =============================================================
#  STEP 3: FastQC on Trimmed Reads
# =============================================================
echo -e "\n${BLUE}▶ Step 3: FASTQC on trimmed reads...${NC}"
for r1 in "$TRIMMED_DIR"/*/*_R1_trimmed.fastq.gz; do
  [[ -e "$r1" ]] || continue
  r2="${r1/_R1/_R2}"
  sample=$(basename "$r1" | cut -d_ -f1-2)
  echo -e "${GREEN}➤ FASTQC (trimmed): $sample${NC}"
  fastqc -t "$THREADS" -o "$TRIMMED_FASTQC_DIR" "$r1" "$r2" &> "$LOGDIR/${sample}_fastqc_trimmed.log"
done

# =============================================================
# 📊 STEP 4: MultiQC Summary (FastQC only, with timezone fix)
# =============================================================
echo -e "\n${BLUE}▶ Step 4: Aggregating reports with MultiQC (FastQC only)...${NC}"
TZ=UTC multiqc "$RAW_FASTQC_DIR" "$TRIMMED_FASTQC_DIR" \
  --module fastqc \
  --force --no-ansi \
  --filename multiqc_report.html \
  --outdir "$MULTIQC_DIR" \
  --verbose &> "$LOGDIR/multiqc_final.log"


# 🛡️ Sanity check: did MultiQC generate anything?
if [[ ! -s "$MULTIQC_DIR/multiqc_report.html" ]]; then
  echo -e "${YELLOW}⚠️ WARNING: MultiQC ran but no report was generated.${NC}"
  echo -e "${YELLOW}   ➤ Check if FastQC or fastp reports exist."
  echo -e "${YELLOW}   ➤ See MultiQC log: $LOGDIR/multiqc.log${NC}"
fi


# =============================================================
# ✅ DONE - Final Summary
# =============================================================
echo -e "\n${GREEN}✅ QC pipeline completed successfully! [$(date)]${NC}"
echo -e "${BLUE}📦 Output written to: $OUTDIR${NC}"
echo -e "${BLUE} ├── fastqc_pre_trim/     ← FASTQC before trimming"
echo -e "${BLUE} ├── trimmed/             ← trimmed reads + fastp reports"
echo -e "${BLUE} ├── fastqc_post_trim/    ← FASTQC after trimming"
echo -e "${BLUE} ├── multiqc/             ← final report summary"
echo -e "${BLUE} └── logs/                ← tool logs per sample${NC}"
