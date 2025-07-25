
# Building a Command-Line Bioinformatics QC Pipeline with Bash

This tutorial walks you through constructing a fully functional Bash pipeline for performing quality control (QC) on paired-end sequencing reads using FastQC, fastp, and MultiQC.

Each step is explained **piece by piece**, to **understand what happens**, **why it matters**, and **how to write robust command-line tools**.

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
### 💡 Key Bash Concepts

| Element     | Meaning |
|-------------|---------|
| `"$1"`      | First argument (flag like `-i`) |
| `"$2"`      | Its value (e.g. folder path) |
| `shift 2`   | Remove `$1` and `$2` from argument list |
| `[[ $# -gt 0 ]]` | Loop while arguments remain |

This lets you call the script like:

```bash
./run_pipeline.sh -i rawreads -o results -t 12
```

## Input Validation

```bash
if [[ -z "$READS_DIR" || -z "$OUTDIR" ]]; then
  echo "❌ Missing required arguments"
  usage
fi
```

- `-z` checks if string is empty
- `||` is OR: if either variable is empty, print usage and exit

💡 Always validate user input early.


## 🛠️  Tool Availability Check in Bash

```bash
for tool in fastqc fastp multiqc; do
  if ! command -v $tool &> /dev/null; then
    echo "❌ $tool not found"
    exit 1
  fi
done
```

The following Bash loop checks if all required tools (`fastqc`, `fastp`, `multiqc`) are installed **before** running the pipeline.

### 🔁 Loop Elements


| Element | Explanation |
|---------|-------------|
| `command -v` | Checks if tool is in `$PATH` |
| `!` | Negates the condition (not found) |
| `&> /dev/null` | Silences output |
---

## 📘 Part 2: Define a Usage/Help Function

```bash
usage() {
  echo "Usage: $0 -i <input_dir> -o <output_dir> [-t <threads>]"
  echo "  -i   Input FASTQ folder (required)"
  echo "  -o   Output folder (required)"
  echo "  -t   Threads [default: 8]"
  exit 1
}
```

- `$0` is the name of the script (e.g., `./run_pipeline.sh`)
- This function prints help when user runs `-h` or forgets arguments
- `exit 1` exits with error code (used by tools to detect failure)

---

### 📂 Step 3 – Create Output Folder Structure

We separate results into subfolders:

```bash
RAW_FASTQC_DIR="$OUTDIR/fastqc_pre_trim"
TRIMMED_DIR="$OUTDIR/trimmed"
TRIMMED_FASTQC_DIR="$OUTDIR/fastqc_post_trim"
MULTIQC_DIR="$OUTDIR/multiqc"
LOGDIR="$OUTDIR/logs"

mkdir -p "$RAW_FASTQC_DIR" "$TRIMMED_DIR" "$TRIMMED_FASTQC_DIR" "$MULTIQC_DIR" "$LOGDIR"
```
- `mkdir -p` creates folders if they don’t exist
- Folders are grouped per tool to stay organized


### Step 4 – Run FastQC on Raw Reads

Detect paired-end files (forward `R1` and reverse `R2`), then run FastQC:

```bash
for r1 in "$READS_DIR"/*_R1_001.fastq.gz "$READS_DIR"/*_1.fastq.gz; do
  r2="${r1/_R1_001/_R2_001}"
  r2="${r2/_1./_2.}"
  fastqc -t "$THREADS" -o "$RAW_FASTQC_DIR" "$r1" "$r2"
done
```

---

### ✂️ Step 5 – Trim Reads with fastp

Output goes into `trimmed/SAMPLE/`:

```bash
fastp   -i "$r1" -I "$r2"   -o "$TRIMMED_DIR/$sample/${sample}_R1_trimmed.fastq.gz"   -O "$TRIMMED_DIR/$sample/${sample}_R2_trimmed.fastq.gz"   -q 28 -p -g -l 40 --cut_tail -t 5 -w "$THREADS"
```

---

### 🔁 Step 6 – Run FastQC on Trimmed Reads

```bash
for r1 in "$TRIMMED_DIR"/*/*_R1_trimmed.fastq.gz; do
  r2="${r1/_R1/_R2}"
  fastqc -t "$THREADS" -o "$TRIMMED_FASTQC_DIR" "$r1" "$r2"
done
```

---

### 📊 Step 7 – MultiQC Summary (FastQC-only)

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
## 👨🏽‍🏫 Summary

| Teaching Focus | Code Feature |
|----------------|--------------|
| Robust scripting | `set -euo pipefail` |
| CLI design | `usage()`, `shift`, `case` |
| Tool safety | `command -v`, file checks |
| Modular outputs | `mkdir -p`, structured logs |
| Debugging | `&> log.txt` for every tool |
| Extensibility | Add new tools easily via steps |

---

## Bonus Exercise
- Modify the script to support `.fq`, `.fq.gz`, `.fastq`
- Add new options like `--skip-fastqc`
- Ad a flog -ref --reference for eteh reference genome for reads mapping
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
