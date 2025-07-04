
# 🧬 Teaching-Level Breakdown: Bash QC Pipeline Script

This guide provides **line-by-line teaching explanations** of the core elements in a Bash script for NGS quality control. It is meant for **complete beginners** in Bash scripting, particularly those working in bioinformatics.

---

## 📌 Goal

We will **demystify** what each part of the script does:
- What is happening in the code
- Why it’s written this way
- What each syntax means (like `"$@"`, `shift`, `-z`, etc.)
- How to write help menus and parse user input

---

## 🧱 Part 1: Start With Strict Bash Mode

```bash
set -euo pipefail
```

| Part        | Explanation |
|-------------|-------------|
| `set`       | A Bash command to configure script behavior |
| `-e`        | Exit the script immediately if any command fails |
| `-u`        | Exit if a variable is used before being set |
| `pipefail`  | If part of a pipeline (`|`) fails, the whole pipeline fails |

🧠 Why: This protects us from silent errors — critical in processing FASTQ files where failures can otherwise go unnoticed.

---

## 🧮 Part 2: Declaring Variables

```bash
THREADS=8
READS_DIR=""
OUTDIR=""
```

- `THREADS` is default number of CPU cores the user can override
- `READS_DIR` and `OUTDIR` are initialized empty and populated later

💡 `""` ensures that the variables exist but are unset — so we can validate them later.

---

## 📘 Part 3: Define a Usage/Help Function

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

## 🔍 Part 4: Parse Command-Line Arguments

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

---

## ✅ Part 5: Input Validation

```bash
if [[ -z "$READS_DIR" || -z "$OUTDIR" ]]; then
  echo "❌ Missing required arguments"
  usage
fi
```

- `-z` checks if string is empty
- `||` is OR: if either variable is empty, print usage and exit

💡 Always validate user input early.

---

## 🛠️ Part 6: Check Tool Availability

```bash
for tool in fastqc fastp multiqc; do
  if ! command -v $tool &> /dev/null; then
    echo "❌ $tool not found"
    exit 1
  fi
done
```

| Element | Explanation |
|---------|-------------|
| `command -v` | Checks if tool is in `$PATH` |
| `!` | Negates the condition (not found) |
| `&> /dev/null` | Silences output |

---

## 📂 Part 7: Folder Creation

```bash
mkdir -p "$RAW_FASTQC_DIR" "$TRIMMED_DIR" ...
```

- `mkdir -p` creates folders if they don’t exist
- Folders are grouped per tool to stay organized

---

## 🔁 Part 8: Loops Over Input Reads

```bash
for r1 in "$READS_DIR"/*_R1_001.fastq.gz; do
  r2="${r1/_R1_001/_R2_001}"
```

- `for` loop walks over all forward reads
- `${var/pattern/replacement}` substitutes `_R1_001` with `_R2_001`

💡 This finds the correct reverse read file.

---

## ✂️ Part 9: Run Tools With Logging

```bash
fastqc -t "$THREADS" -o "$OUTDIR" "$r1" "$r2" &> "$LOGDIR/sample_fastqc.log"
```

- `-t` is number of threads
- `-o` is output folder
- `&>` redirects both stdout and stderr to a file (for debugging)

---

## 📊 Part 10: MultiQC Run

```bash
TZ=UTC multiqc "$RAW_FASTQC_DIR" "$TRIMMED_FASTQC_DIR" --module fastqc ...
```

- `TZ=UTC` fixes timezone-related bugs in plotting
- `--module fastqc` ensures only FastQC is parsed
- `--outdir` and `--filename` let us control output layout

---

## 🧪 Final Check

```bash
if [[ ! -s "$MULTIQC_DIR/multiqc_report.html" ]]; then
  echo "⚠️ MultiQC failed or produced empty report"
fi
```

- `-s` checks if file is non-zero in size
- Fails safely and helps users debug quickly

---

## 👨🏽‍🏫 Summary for Trainers

| Teaching Focus | Code Feature |
|----------------|--------------|
| Robust scripting | `set -euo pipefail` |
| CLI design | `usage()`, `shift`, `case` |
| Tool safety | `command -v`, file checks |
| Modular outputs | `mkdir -p`, structured logs |
| Debugging | `&> log.txt` for every tool |
| Extensibility | Add new tools easily via steps |

---

Would you like to:
- Add new options like `--skip-fastqc`?
- Allow `.fq.gz` or `.fastq`?
- Build a classroom assignment version?
