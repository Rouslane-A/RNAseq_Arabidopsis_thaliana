#!/bin/bash

# ================================
# HISAT2 RNA-seq Batch Pipeline
# ================================

# --- SETTINGS ---
THREADS=8

# --- DIRECTORIES ---
#OUT_DIR="./hisat2_results"
OUT_DIR="/media/rouslane/WD/rnaseq"
LOG_DIR="./logs"
QC_DIR="./multiqc_report"
INDEX_DIR="./index"

# Create output folders
mkdir -p $OUT_DIR $LOG_DIR $QC_DIR $INDEX_DIR

# --- INPUT FILES ---
READS_DIR="/home/rouslane/Documents/Bioinformatics-Projects/RNA-seq/00_RawData"
GENOME_FA="/home/rouslane/Documents/Bioinformatics-Projects/RNA-seq/00_RefData/ncbi_dataset/ncbi_dataset/data/GCF_000001735.4/GCF_000001735.4_TAIR10.1_genomic.fna"
GTF_FILE="/home/rouslane/Documents/Bioinformatics-Projects/RNA-seq/00_RefData/ncbi_dataset/ncbi_dataset/data/GCF_000001735.4/genomic.gtf"
INDEX_PREFIX=$INDEX_DIR

# --- OUTPUT SUMMARY ---
SUMMARY_FILE="${LOG_DIR}/mapping_summary.tsv"
echo -e "Sample\tTotal_Reads\tMapped_Reads\tPercent_Mapped" > $SUMMARY_FILE

# --------------------
# Step 1: Build HISAT2 index (only if not already done)
# --------------------
if [ ! -f "${INDEX_PREFIX}.1.ht2" ]; then
    echo "Building HISAT2 index..."
    hisat2_extract_splice_sites.py $GTF_FILE > splice_sites.txt
    hisat2_extract_exons.py $GTF_FILE > exons.txt
    hisat2-build --ss splice_sites.txt --exon exons.txt \
        $GENOME_FA $INDEX_PREFIX
fi

# --------------------
# Step 2: Loop through samples
# --------------------
echo "Starting batch mapping..."

for R1 in ${READS_DIR}/*_1.fastq.gz; do
    SAMPLE=$(basename $R1 _1.fastq.gz)
    R2=${READS_DIR}/${SAMPLE}_2.fastq.gz

    echo "Processing sample: $SAMPLE"

    # Run HISAT2 (log saved separately)
    hisat2 -p $THREADS \
        -x $INDEX_PREFIX \
        -1 $R1 -2 $R2 \
        -S ${OUT_DIR}/${SAMPLE}.sam \
        2> ${LOG_DIR}/${SAMPLE}_hisat2.log

    # Convert SAM → sorted BAM
    samtools view -@ $THREADS -bS ${OUT_DIR}/${SAMPLE}.sam | \
        samtools sort -@ $THREADS -o ${OUT_DIR}/${SAMPLE}.sorted.bam

    # Index BAM
    samtools index ${OUT_DIR}/${SAMPLE}.sorted.bam

    # Cleanup SAM
    rm ${OUT_DIR}/${SAMPLE}.sam

    # Alignment summary (flagstat)
    samtools flagstat ${OUT_DIR}/${SAMPLE}.sorted.bam > ${LOG_DIR}/${SAMPLE}_flagstat.txt

    # Extract key stats
    TOTAL=$(grep "in total" ${LOG_DIR}/${SAMPLE}_flagstat.txt | awk '{print $1}')
    MAPPED=$(grep "mapped (" ${LOG_DIR}/${SAMPLE}_flagstat.txt | awk '{print $1}')
    PERCENT=$(grep "mapped (" ${LOG_DIR}/${SAMPLE}_flagstat.txt | awk '{print $5}' | tr -d '()%')

    echo -e "${SAMPLE}\t${TOTAL}\t${MAPPED}\t${PERCENT}" >> $SUMMARY_FILE

    echo "✅ Finished: ${OUT_DIR}/${SAMPLE}.sorted.bam"
done

# --------------------
# Step 3: MultiQC Report
# --------------------
echo "Running MultiQC..."
multiqc $LOG_DIR -o $QC_DIR

echo "🎉 All samples processed!"
echo "📊 BAM files in: $OUT_DIR"
echo "📑 Logs + summary in: $LOG_DIR"
echo "📈 MultiQC report in: $QC_DIR"

