#!/usr/bin/env bash
set -euo pipefail

# qc_pipeline_fixed.sh
# Usage: ./qc_pipeline_fixed.sh /path/to/fastq_dir
# Requirements: seqkit, fastq-scan, fastqc, multiqc (jq is optional but recommended)

FASTQ_DIR="${1:-.}"

if [[ ! -d "$FASTQ_DIR" ]]; then
  echo "Error: directory '$FASTQ_DIR' not found." >&2
  exit 1
fi

# Make outputs
mkdir -p MultiQC_reports FastQC_results Seqkit_stats FastqScan_stats logs

echo "[$(date +'%F %T')] Finding FASTQ files in: $FASTQ_DIR"


# find files (non-recursive, handles spaces)
mapfile -d '' files < <(find "$FASTQ_DIR" -maxdepth 1 -type f \( -iname '*.fastq' -o -iname '*.fq' -o -iname '*.fastq.gz' -o -iname '*.fq.gz' \) -print0)

if (( ${#files[@]} == 0 )); then
  echo "No FASTQ files found in $FASTQ_DIR. Exiting."
  exit 0
fi

echo "Found ${#files[@]} FASTQ file(s)."

# 1) seqkit stats -- run once on all files so header appears only once
echo "[$(date +'%F %T')] Running seqkit stats on all files..."
if command -v seqkit >/dev/null 2>&1; then
  # run seqkit once on the whole list (preserves single header)
  seqkit stats "${files[@]}" -a -T 2>/dev/null | tee Seqkit_stats/seqkit_summary.txt
else
  echo "seqkit not found. Skipping seqkit stats." >&2
fi

# 2) fastq-scan per file (use zcat for gzipped files)
echo "[$(date +'%F %T')] Running fastq-scan per file..."
if command -v fastq-scan >/dev/null 2>&1; then
  for f in "${files[@]}"; do
    base=$(basename "$f")
    outjson="FastqScan_stats/${base}_fastqscan.json"
    echo "  -> $base"
    if [[ "$f" == *.gz ]]; then
      # read from stdin (fastq-scan -)
      if ! zcat "$f" | fastq-scan - > "$outjson" 2>logs/"${base}.fastqscan.log"; then
        echo "     fastq-scan failed on $base (see logs/${base}.fastqscan.log)" >&2
        continue
      fi
    else
      if ! fastq-scan "$f" > "$outjson" 2>logs/"${base}.fastqscan.log"; then
        echo "     fastq-scan failed on $base (see logs/${base}.fastqscan.log)" >&2
        continue
      fi
    fi

    # Pretty print if jq available, else copy raw json as .txt
    if command -v jq >/dev/null 2>&1; then
      jq . "$outjson" > "FastqScan_stats/${base}_fastqscan.txt"
    else
      cp "$outjson" "FastqScan_stats/${base}_fastqscan.txt"
    fi
  done
else
  echo "fastq-scan not found. Skipping fastq-scan step." >&2
fi

# 3) FastQC (bulk)
echo "[$(date +'%F %T')] Running FastQC on all files..."
if command -v fastqc >/dev/null 2>&1; then
  fastqc -o FastQC_results "${files[@]}" 2>logs/fastqc_all.log || {
    echo "FastQC returned non-zero; check logs/fastqc_all.log" >&2
  }
else
  echo "fastqc not found. Skipping FastQC." >&2
fi

# 4) MultiQC
echo "[$(date +'%F %T')] Running MultiQC (on FastQC_results)..."
if command -v multiqc >/dev/null 2>&1; then
  multiqc FastQC_results -o MultiQC_reports 2>logs/multiqc.log || {
    echo "MultiQC returned non-zero; check logs/multiqc.log" >&2
  }
else
  echo "multiqc not found. Skipping MultiQC." >&2
fi

# Paired-end detection / missing mate checks
echo "[$(date +'%F %T')] Detecting pairs and missing mates..."
declare -A groups

for f in "${files[@]}"; do
  base=$(basename "$f")
  name="$base"
  # strip known extensions
  for ext in .fastq.gz .fq.gz .fastq .fq; do
    name="${name%$ext}"
  done
  # remove trailing PE marker like _R1, _R2, .1, .2, -1, -2, _1, _2 (case-insensitive)
  prefix=$(printf '%s' "$name" | sed -E 's/([._-]R?[12]|[._-][12])$//I')
  groups["$prefix"]+="$f||"
done

paired=0
single=0
multi=0

for p in "${!groups[@]}"; do
  IFS='||' read -r -a arr <<< "${groups[$p]}"
  # remove empty elements
  elems=()
  for v in "${arr[@]}"; do
    [[ -n "$v" ]] && elems+=("$v")
  done
  cnt=${#elems[@]}
  if (( cnt == 2 )); then
    echo "Paired: $(basename "${elems[0]}")  <-->  $(basename "${elems[1]}")"
    paired=$((paired+1))
  elif (( cnt == 1 )); then
    echo "Single / missing mate: $(basename "${elems[0]}")"
    single=$((single+1))
  else
    echo "Multiple files sharing a prefix (${p}):"
    for vv in "${elems[@]}"; do echo "   - $(basename "$vv")"; done
    multi=$((multi+1))
  fi
done

echo "Summary: paired groups=${paired}, singletons=${single}, multi-groups=${multi}"

echo "[$(date +'%F %T')] Done. Outputs:"
echo " - Seqkit summary: Seqkit_stats/seqkit_summary.txt"
echo " - Fastq-scan results: FastqScan_stats/"
echo " - FastQC results: FastQC_results/"
echo " - MultiQC report: QC_reports/multiqc_report.html"
echo " - Logs: logs/"

exit 0

