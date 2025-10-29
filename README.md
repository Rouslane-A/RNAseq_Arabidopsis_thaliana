Here’s a polished and well-formatted version of your text using **Markdown** for better readability and professional presentation:

---

# 🧬 RNAseq Analysis of *Arabidopsis thaliana*

This project involves building a complete **RNA-Seq analysis pipeline** using the genome of *Arabidopsis thaliana*.

---

## 📂 Project Structure

### **00_RawData**

Contains scripts for downloading the raw sequencing data.

### **00_RefData**

Includes the reference genome and annotation data used for alignment and downstream analyses.

### **01_AnalysisStepOne — Quality Control**

Scripts and results for the **quality control** step can be found here.
Tools like *FastQC* and *MultiQC* were likely used to assess read quality.

### **02_AnalysisStepTwo — Alignment**

Contains scripts and results for the **alignment step** using **HISAT2** to map reads to the reference genome.

### **03_AnalysisStepThree — Feature Counting**

Includes scripts and output for **feature counting**, where read counts per gene are obtained (e.g., using *featureCounts*).

### **04_AnalysisStepFour — Differential Expression Analysis**

Contains R scripts and results for **differential expression analysis** performed with the **DESeq2** package.

---


This pipeline automates the full RNA-Seq workflow — from raw data download to differential expression analysis — providing a reproducible framework for transcriptomic studies in *A. thaliana*.

