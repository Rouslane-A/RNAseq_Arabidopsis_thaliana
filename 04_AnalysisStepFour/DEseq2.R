library("DESeq2")
library("ggplot2")

# Set working directory
setwd("/home/rouslane/Documents/Bioinformatics-Projects/RNA-seq/03_AnalysisStepThree/featurecounts_results")

# Load counts table
dat <- read.table("all_samples_counts.txt", header = TRUE, quote = "", row.names = 1)

# Convert to matrix
dat <- as.matrix(dat)

# Remove genes with zero counts across all samples
dat <- dat[rowSums(dat) > 0, ]

# Assign conditions
condition <- factor(c(rep("WT", 3), rep("Mut", 3)))
condition <- relevel(condition, ref = "WT")

# Create colData
coldata <- data.frame(row.names = colnames(dat), condition)

# Create DESeq dataset
dds <- DESeqDataSetFromMatrix(countData = dat, colData = coldata, design = ~ condition)

# Run DESeq pipeline
dds <- DESeq(dds)

# Dispersion plot
png("qc-dispersions.png", 1000, 1000, pointsize = 20)
plotDispEsts(dds, main = "Dispersion plot")
dev.off()

# rlog transformation (stabilizes variance)
rld <- rlog(dds)

# Check transformed values
head(assay(rld))

# Histogram of transformed counts
hist(assay(rld), breaks = 100, main = "Histogram of rlog-transformed counts")

# PCA plot
plotPCA(rld, intgroup = "condition")



# Define sample colors: WT = blue, Mut = red
sampleColors <- ifelse(coldata$condition == "WT", "blue", "red")

# Sample distance matrix
sampleDists <- dist(t(assay(rld)))
sampleDistMatrix <- as.matrix(sampleDists)
rownames(sampleDistMatrix) <- colnames(rld)
colnames(sampleDistMatrix) <- colnames(rld)

# Heatmap with nice colors and labels
library(gplots)
png("qc-heatmap-samples.png", w=1200, h=1200, pointsize=18)

heatmap.2(sampleDistMatrix, 
          key = FALSE, trace = "none",
          col = colorRampPalette(c("blue", "white", "red"))(200),
          ColSideColors = sampleColors,
          RowSideColors = sampleColors,
          margin = c(12, 12), # bigger margins for sample names
          main = "Sample Distance Matrix",
          lhei = c(1, 6), lwid = c(1, 6),
          dendrogram = "both", # show row & col clustering
          scale = "none", # no scaling (distance already standardized)
          labRow = rownames(sampleDistMatrix), # sample names on rows
          labCol = colnames(sampleDistMatrix)) # sample names on cols

# Legend for sample conditions
legend("topright", 
       legend = levels(coldata$condition), 
       fill = c("blue", "red"), 
       border = FALSE, bty = "n", cex = 1.2)

dev.off()


# Get differential expression results
res <- results(dds)
table(res$padj<0.05)


## Order by adjusted p-value
res <- res[order(res$padj), ]
## Merge with normalized count data
resdata <- merge(as.data.frame(res), as.data.frame(counts(dds, normalized=TRUE)), by="row.names", sort=FALSE)
names(resdata)[1] <- "Gene"
head(resdata)
## Write results
write.csv(resdata, file="diffexpr-results.csv",quote = FALSE,row.names = F)

## Examine plot of p-values
hist(res$pvalue, breaks=50, col="grey")



## MA plot
## Could do with built-in DESeq2 function:
## DESeq2::plotMA(dds, ylim=c(-1,1), cex=1)
## This is Stephen Turner's code:
maplot <- function (res, thresh=0.05, labelsig=TRUE, textcx=1, ...) {
  with(res, plot(baseMean, log2FoldChange, pch=20, cex=.5, log="x", ...))
  with(subset(res, padj<thresh), points(baseMean, log2FoldChange, col="red", pch=20, cex=1.5))
  if (labelsig) {
    require(calibrate)
    with(subset(res, padj<thresh), points(baseMean, log2FoldChange, labs=Gene, cex=textcx, col=2))
  }
}
png("diffexpr-maplot.png", 1500, 1000, pointsize=20)
maplot(resdata, main="MA Plot")
dev.off()

## Plots to Examine Results:

## Volcano plot with "significant" genes labeled
volcanoplot <- function (res, lfcthresh=2, sigthresh=0.05, main="Volcano Plot", legendpos="bottomright", labelsig=TRUE, textcx=1, ...) {
  with(res, plot(log2FoldChange, -log10(pvalue), pch=20, main=main, ...))
  with(subset(res, padj<sigthresh ), points(log2FoldChange, -log10(pvalue), pch=20, col="red", ...))
  with(subset(res, abs(log2FoldChange)>lfcthresh), points(log2FoldChange, -log10(pvalue), pch=20, col="orange", ...))
  with(subset(res, padj<sigthresh & abs(log2FoldChange)>lfcthresh), points(log2FoldChange, -log10(pvalue), pch=20, col="green", ...))
  if (labelsig) {
    require(calibrate)
    with(subset(res, padj<sigthresh & abs(log2FoldChange)>lfcthresh), points(log2FoldChange, -log10(pvalue), labs=Gene, cex=textcx, ...))
  }
  legend(legendpos, xjust=1, yjust=1, legend=c(paste("FDR<",sigthresh,sep=""), paste("|LogFC|>",lfcthresh,sep=""), "both"), pch=20, col=c("red","orange","green"))
}
png("diffexpr-volcanoplot.png", 1200, 1000, pointsize=20)
volcanoplot(resdata, lfcthresh=1, sigthresh=0.05, textcx=.8, xlim=c(-2.3, 2))
dev.off()

