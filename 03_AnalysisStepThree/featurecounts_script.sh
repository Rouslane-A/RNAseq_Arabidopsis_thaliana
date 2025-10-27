#!/bin/bash
set -euo pipefail

# ============================
# featureCounts Parallel Script
# ============================

# --- SETTINGS (edit these) ---
THREADS=4                         # Threads per sample
ANNOTATION="/home/rouslane/Documents/Bioinformatics-Projects/RNA-seq/00_RefData/ncbi_dataset/ncbi_dataset/data/GCF_000001735.4/genomic.gtf"
BAM_DIR="/media/rouslane/WD/rnaseq"
OUT_DIR="./featurecounts_results"
LOG_DIR="./logs"

# --- CREATE DIRECTORIES ---
mkdir -p "$OUT_DIR" "$LOG_DIR"

# --- CHECK INPUTS ---
if [[ ! -f "$ANNOTATION" ]]; then
  echo "ERROR: Annotation file not found: $ANNOTATION" >&2
  exit 1
fi

shopt -s nullglob
BAMS=("$BAM_DIR"/*.bam)
if [[ ${#BAMS[@]} -eq 0 ]]; then
  echo "ERROR: No BAM files found in $BAM_DIR" >&2
  exit 1
fi

# --- RUN FEATURECOUNTS IN PARALLEL ---
echo "Running featureCounts on ${#BAMS[@]} BAM files ..."

parallel -j 4 "
  SAMPLE=\$(basename {} .bam);
  echo 'Processing' \$SAMPLE;
  featureCounts \
    -T $THREADS \
    -a $ANNOTATION \
    -o $OUT_DIR/\${SAMPLE}_counts.txt \
    -g gene_id \
    -t exon \
    -p -B -C \
    {} \
    > $LOG_DIR/\${SAMPLE}_featureCounts.log 2>&1
" ::: "${BAMS[@]}"

# --- BUILD CLEAN COUNT MATRIX ---
echo "Merging per-sample count files into clean matrix..."

# Extract gene IDs from first sample
FIRST_SAMPLE=$(basename "${BAMS[0]}" .bam)
tail -n +3 "$OUT_DIR/${FIRST_SAMPLE}_counts.txt" | cut -f1 > "$OUT_DIR/gene_id_column.txt"

# Extract counts per sample
for f in "$OUT_DIR"/*_counts.txt; do
    SAMPLE=$(basename "$f" _counts.txt)
    tail -n +3 "$f" | cut -f7 > "$OUT_DIR/${SAMPLE}.col"
done

# Combine into one file
paste "$OUT_DIR/gene_id_column.txt" "$OUT_DIR"/*.col > "$OUT_DIR/all_samples_counts.txt"

# Add header row
HEADER="GeneID"
for f in "$OUT_DIR"/*.col; do
    SAMPLE=$(basename "$f" .col)
    HEADER="$HEADER\t$SAMPLE"
done
sed -i "1i $HEADER" "$OUT_DIR/all_samples_counts.txt"

# Clean temporary files
rm "$OUT_DIR"/*.col "$OUT_DIR"/gene_id_column.txt

echo "✅ All done!"
echo "   Final count matrix: $OUT_DIR/all_samples_counts.txt"
echo "   Logs per sample:    $LOG_DIR"


