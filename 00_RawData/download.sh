#!/bin/bash

# Usage: ./download_sra_fastq.sh runs.txt
# Input: runs.txt = file with one SRR/ERR/DRR accession per line

if [ $# -lt 1 ]; then
    echo "Usage: $0 runs.txt"
    exit 1
fi

RUNS_FILE=$1

while read accession; do
    echo ">>> Processing $accession ..."

    # 1. Try ENA download with wget
    urls=$(wget -qO - "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${accession}&result=read_run&fields=fastq_ftp" | \
           grep -v "fastq_ftp" | tr ";" "\n")

    if [ -n "$urls" ]; then
        echo "Found ENA FASTQ files for $accession"
        for url in $urls; do
            echo "Downloading: ftp://$url"
            wget -c "ftp://$url"
        done
    else
        echo "No ENA links found for $accession, using fastq-dump..."
        # 2. Fallback to SRA Toolkit
        fastq-dump --split-files --gzip "$accession"
    fi

done < "$RUNS_FILE"

