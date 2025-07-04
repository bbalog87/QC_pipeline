
# Building a Command-Line Bioinformatics QC Pipeline with Bash

This tutorial walks you through constructing a fully functional Bash pipeline for performing quality control (QC) on paired-end sequencing reads using FastQC, fastp, and MultiQC.

Each step is explained **piece by piece**, to help students and professionals **understand what happens**, **why it matters**, and **how to write robust command-line tools**.

---

## 🔧 Prerequisites

- Bash shell
- Installed tools:
  - `fastqc`
  - `fastp`
  - `multiqc`
- Basic paired-end FASTQ data (e.g. `sample_R1_001.fastq.gz` and `sample_R2_001.fastq.gz`)

---

## Overview of the Pipeline Steps

1. **Run FastQC on raw FASTQ reads**
2. **Trim/filter the reads using fastp**
3. **Re-run FastQC on trimmed reads**
4. **Summarize with MultiQC (FastQC reports only)**

---

## 🏗️ Step-by-Step Bash Pipeline Construction

## 📌  Goal
We will **demystify** what each part of the script does:
- What is happening in the code
- Why it’s written this way
- What each syntax means (like `"$@"`, `shift`, `-z`, etc.)
- How to write help menus and parse user input


---

### Step 1 – Argument Parsing and Error Handling : strict Bash mode

```bash
set -euo pipefail
```

- `-e`: exit if any command fails
- `-u`: exit if a variable is undefined
- `-o pipefail`: fail if any command in a pipeline fails


| Part        | Explanation |
|-------------|-------------|
| `set`       | A Bash command to configure script behavior |
| `-e`        | Exit the script immediately if any command fails |
| `-u`        | Exit if a variable is used before being set |
| `pipefail`  | If part of a pipeline (`\|`) fails, the whole pipeline fails |


Parse arguments (`-i` for input folder, `-o` for output folder, `-t` for threads):

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input) READS_DIR="$2"; shift 2 ;;
    -o|--outdir) OUTDIR="$2"; shift 2 ;;
    -t|--threads) THREADS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done
```

---

### 📂 Step 2 – Create Output Folder Structure

We separate results into subfolders:

```bash
RAW_FASTQC_DIR="$OUTDIR/fastqc_pre_trim"
TRIMMED_DIR="$OUTDIR/trimmed"
TRIMMED_FASTQC_DIR="$OUTDIR/fastqc_post_trim"
MULTIQC_DIR="$OUTDIR/multiqc"
LOGDIR="$OUTDIR/logs"

mkdir -p "$RAW_FASTQC_DIR" "$TRIMMED_DIR" "$TRIMMED_FASTQC_DIR" "$MULTIQC_DIR" "$LOGDIR"
```

---

### Step 3 – Run FastQC on Raw Reads

Detect paired-end files (forward `R1` and reverse `R2`), then run FastQC:

```bash
for r1 in "$READS_DIR"/*_R1_001.fastq.gz "$READS_DIR"/*_1.fastq.gz; do
  r2="${r1/_R1_001/_R2_001}"
  r2="${r2/_1./_2.}"
  fastqc -t "$THREADS" -o "$RAW_FASTQC_DIR" "$r1" "$r2"
done
```

---

### ✂️ Step 4 – Trim Reads with fastp

Output goes into `trimmed/SAMPLE/`:

```bash
fastp   -i "$r1" -I "$r2"   -o "$TRIMMED_DIR/$sample/${sample}_R1_trimmed.fastq.gz"   -O "$TRIMMED_DIR/$sample/${sample}_R2_trimmed.fastq.gz"   -q 28 -p -g -l 40 --cut_tail -t 5 -w "$THREADS"
```

---

### 🔁 Step 5 – Run FastQC on Trimmed Reads

```bash
for r1 in "$TRIMMED_DIR"/*/*_R1_trimmed.fastq.gz; do
  r2="${r1/_R1/_R2}"
  fastqc -t "$THREADS" -o "$TRIMMED_FASTQC_DIR" "$r1" "$r2"
done
```

---

### 📊 Step 6 – MultiQC Summary (FastQC-only)

**Avoids fastp bug** by setting `TZ=UTC`:

```bash
TZ=UTC multiqc "$RAW_FASTQC_DIR" "$TRIMMED_FASTQC_DIR"   --module fastqc   --force --no-ansi   --outdir "$MULTIQC_DIR"   --filename multiqc_report.html
```

---

## ✅ Final Output Structure

```bash
$ tree $OUTDIR

QC_RESULTS/
├── fastqc_pre_trim/        ← FastQC before trimming
├── trimmed/                ← fastp-trimmed reads
├── fastqc_post_trim/       ← FastQC after trimming
├── multiqc/                ← summary HTML report
└── logs/                   ← logs per tool/sample
```

---


## 🧠 Bonus Exercise
- Modify the script to support `.fq`, `.fq.gz`, `.fastq`
- Add chimera removal or adapter stats comparison
- Use MultiQC `--title` and `--comment`

---

## 🧪 That’s it!
Change mode ansd run :

```bash
chmod +x run_QC_module.sh
./run_QC_module.sh -i rawreads -o QC_RESULTS -t 8
```

---

**Author**: Julien Nguinkal  
**For**: Africa CDC / Linux Regional Bioinformatics Training  
**Topic**: Robust Bash Pipelines for QC in Genomics
