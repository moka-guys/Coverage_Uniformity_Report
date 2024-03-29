library(tidyverse)
library(plotly)
library(htmlwidgets)
library(argparser)
library(methods)

# Purpose: This script takes the RAW output from sambamba and produces summary tables and plots highlighting the uniformity of coverage

# Usage: Rscript sambamba_exon_coverage.R --args "/path_to_folder/exon_coverage"

# Functions:

p <-
  arg_parser("Calculate the uniformity of coverage over multiple samples")
p <-
  add_argument(p, "--input_directory", help = "Input data directory containing the sambamba output files")
p <-
  add_argument(p, "--output_directory", help = "Output directory for results")
p <-
  add_argument(p, "--suffix_pattern", help = "Suffix pattern to match Sambamba input", default =
                 ".sambamba_output.bed")
p <-
  add_argument(p, "--group_by", help = "User provided Pan numbers to group results together in the format ParentPan=ChildPan1,ChildPan2;", default =
                 "")
p <-
  add_argument(p, "--plot_figures", help = "Plot figures (May be very slow for large data sets)", flag =
                 TRUE)
p <-
  add_argument(p, "--simple_plot_only", help = "Plot only the simplified static figure (May speed up drawing plots for large data sets)", flag =
                 TRUE)
p <-
  add_argument(p, "--no_jitter", help = "Don't plot data points on barplots (May speed up drawing plots for large data sets)", flag =
                 TRUE)
args <- parse_args(p)

generate_coverage_plot <- function(df, panel, simplify) {
  # Remove rows with NAs caused by regions not included between panels
  df <- df[complete.cases(df),]
  # Reorder the factors in region by median (Ensures the boxplots are plotted in order form lowest to highest)
  df$region <-
    fct_reorder(df$region,
                df$scaled_meanCoverage,
                .fun = median,
                .desc = FALSE)
  # Create a color palette to highlight samples by gene/transcript
  col = rainbow(length(levels(factor(df$gene))))[factor(df$gene)]
  # Plot coverage data (A series of boxplots showing coverage for each region, ordered by median)
  p <- df %>%
    ggplot(aes(x = region, y = scaled_meanCoverage)) +
    geom_boxplot(outlier.size = 0.5, aes(fill = gene)) +
    { if (args$no_jitter == FALSE) geom_jitter(color = "grey", width = 0.01, size = 1, alpha = 0.25 , shape = 1 ) } +
    theme(
    plot.title = element_text(size = 11),
    axis.text.x = element_text(angle = 45,hjust = 1,size = 6)
    ) +
  theme(
    plot.title = element_text(size = 11),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1,
      size = 6
    )
  ) +
    ggtitle(
      paste0(
        "Run ",
        run_name,
        ",  ",
        panel ,
        " (",
        num_target_regions,
        " target regions), Coverage over ",
        num_samples,
        " samples"
      )
    ) +
    xlab("Target Region") +
    ylab("Scaled average coverage")
  return(p)
}

generate_simple_coverage_plot <- function(df, panel) {
  # Remove rows with NAs caused by regions not included between panels
  df <- df[complete.cases(df),]
  # Group the tibble data structure by 'region'
  region_mean <- df %>%
    group_by(region) %>%
    summarise(
      gene = unique(gene),
      transcript = unique(transcript),
      genomicCoordinates = unique(genomicCoordinates),
      region_meanCoverage = mean(scaled_meanCoverage)
    )
  # Order region factors by region_meanCoverage to produce plot in correct order
  region_mean$region <- as.factor(region_mean$region)
  region_mean$region <-
    fct_reorder(
      region_mean$region,
      region_mean$region_meanCoverage,
      .fun = median,
      .desc = FALSE
    )
  # Plot region
  region_mean %>%
    ggplot(aes(x = region, y = region_meanCoverage)) +
    geom_point(col = "red",
               shape = 20,
               size = 0.1) +
    theme(
      legend.position = "none",
      plot.title = element_text(size = 11),
      axis.text.x = element_text(
        angle = 45,
        hjust = 1,
        size = 1
      )
    ) +
    ggtitle(
      paste0(
        "Run ",
        run_name,
        ",  ",
        panel ,
        " (",
        num_target_regions,
        " target regions), Coverage over ",
        num_samples,
        " samples"
      )
    ) +
    xlab("Target Region") +
    ylab("Scaled average coverage")
}

# Uses scale() function on data - scaling is done by dividing the columns for each sample by their root mean square.
# This allows easier comparison between samples.
scale_rms <-
  function(x)
    as.vector(scale(x, scale = TRUE, center = FALSE))

# Main Script:

# Get directory location from commandline - directory should contain the raw exon level coverage files
data_directory <- args$input_directory
output_directory <- args$output_directory
suffix_pattern <- args$suffix_pattern
pan_numbers_for_grouping <-
  args$group_by # Optional comma delimited string of pan numbers to group together

# Create output directory if it does not already exists
dir.create(output_directory, showWarnings = FALSE)

# Get all files with the suffix "*..refined.sambamba_output.bed" from data directory
sambamba_files <-
  list.files(
    path = data_directory,
    pattern = paste0("*", suffix_pattern),
    full.names = TRUE
  )

# Import coverage data and add relevant sample ID to each imported row
tbl <-
  sapply(sambamba_files ,
         read_tsv,
         col_types = "ciicicccinnc",
         simplify = FALSE) %>%
  bind_rows(.id = "sample_id")

# Simplify & cleanup sample names
tbl$sample_id <-
  gsub(basename(tbl$sample_id),
       pattern = suffix_pattern,
       replacement = "")
# Rename 2nd column to remove proceding '#'
colnames(tbl)[2] <- "chrom"
# Replace F1:F6 labels with meaningful names
colnames(tbl)[5:9] <-
  c("genomicCoordinates",
    "score",
    "strand",
    "gene_transcript",
    "accessionNum")

# Add new column 'region' so that each target region is represented by unique ID
tbl$region <- paste(tbl$chrom,
                    tbl$chromStart,
                    tbl$chromEnd,
                    tbl$gene_transcript,
                    sep = ";")

# Group the tibble data structure by samples so that average can be calculated accross samples
tbl <- tbl %>%
  group_by(sample_id) %>%
  mutate(scaled_meanCoverage = scale_rms(meanCoverage))

# Identify Run ID from sample name and add as additional column
tbl$run_name <-
  stringr::str_split(string = tbl$sample_id,
                     pattern = "_",
                     simplify = TRUE)[, 1]
# Extract gene and transcript names into separate columns:
tbl$gene <-
  stringr::str_split(
    string = tbl$gene_transcript,
    pattern = ";",
    simplify = TRUE
  )[, 1]
tbl$transcript <-
  stringr::str_split(
    string = tbl$gene_transcript,
    pattern = ";",
    simplify = TRUE
  )[, 2]
# Any SNPs referenced by their RS accession number will not have a transcript - label as 'dbSNP'
tbl$gene[tbl$transcript == ""] <- "dbSNP"
# Identify Pan number from sample name and add as additional column
tbl$pan_number <-
  stringr::str_extract(string = tbl$sample_id, pattern = "Pan[0-9]+")

# If commandline argument group_by is provided collapse all child Pan numbers into Parent PanNumber
print(pan_numbers_for_grouping)
if (pan_numbers_for_grouping != "") {
  group_by_input <- strsplit(pan_numbers_for_grouping, ";")[[1]]
  for (line in group_by_input) {
    print(line)
    parent_pan <- strsplit(line, "=")[[1]][1]
    print(parent_pan)
    child_pans <- strsplit(strsplit(line, "=")[[1]][2], ",")[[1]]
    print(child_pans)
    # Replace child terms with parent term
    print(tbl$pan_number)
    tbl$pan_number[tbl$pan_number %in% child_pans] <- parent_pan 
  }
}

# Produce separate output for each panel

# Extract meta data from sample name
for (run_name in unique(tbl$run_name)) {
  print(paste("Processing run name =", run_name))
  for (panel in unique(tbl$pan_number)) {
    print(paste("Processing panel number =", panel))

    df <- tbl[tbl$pan_number == panel, ]

    # Update number of samples to be plotted
    num_samples <- length(unique(df$sample_id))
    print(paste("Number of samples =", num_samples))

    # Update number of target regions for this panel
    num_target_regions <- length(unique(df$region))
    print(paste("Number of target regions =", num_target_regions))

    # Generate file name:
    filename <- paste0(run_name, "_", panel)

    # Create simple plot
    if (args$plot_figures == TRUE){
        # Create coverage plot of means for PDF
        print("Generating simplified plot")
        simplified_plot <- generate_simple_coverage_plot(df, panel)

        # Save simplified plot to pdf:
        filepath <-
          paste0(output_directory, "/", filename, "_coverage.pdf")
        print(paste0("Saving file", filepath))
        ggsave(
          filename = filepath,
          simplified_plot,
          device = "pdf",
          width = 297,
          height = 200,
          units = "mm"
        )
    }

    # Generate interactive plot
    if (args$plot_figures == TRUE && args$simple_plot_only == FALSE){

        # Generate static plot of data for each
        print("Generating static ggplot")
        static_plot <- generate_coverage_plot(df, panel)

        # Add interactivity to plot:
        print("Generating Interactive plot")
        interactive_plot <- ggplotly(static_plot)

        # Save interactive plot as a single html file:
        filepath <-
          paste0(output_directory, '/', filename, "_coverage.html")
        print(paste0("Saving file", filepath))
        saveWidget(ggplotly(interactive_plot), file = filepath)
    }else{
      print("Skipping Interactive plot")  
    }

    if (args$plot_figures == FALSE){
      print("Skipping all plots")
    }

    # Save table
    filepath <-
      paste0(output_directory, "/", filename, "_coverage.csv")
    print(paste0("Saving file", filepath))
    summary_df <- df %>%
      group_by(region) %>%
      # Summarise data by region
      summarise(
        gene = unique(gene),
        run_name = unique(run_name),
        panel = unique(panel),
        transcript = unique(transcript),
        genomicCoordinates = unique(genomicCoordinates),
        accessionNum = unique(accessionNum),
        region_meanCoverage = mean(scaled_meanCoverage)
      ) %>%
      arrange(region_meanCoverage)
    print("Saving CSV file")
    write_delim(summary_df, filepath, delim = "\t")
  }
}
