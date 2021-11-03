# R Script and docker files sambamba\_coverage\_uniformity v1.2

## What does this app do?
This RScript uses the calculated Sambamba coverage bed files for x samples to visualise the variability in coverage at each genomic region across all these samples.  Results are available as an interactive plot, simplified pdf plot, and csv table.  A Dockerfile is included to aid sharing the scripts and is used in the dx app sambamba\_coverage\_uniformity v1.2 (See moka-guys/dnanexus\_coverage\_uniformity\_report)

## What are typical use cases for this script?

This app can be used during the development of new diagnositic tests to identify regions which have low coverage.

## What inputs are required for this app to run?
This app requires the following inputs:
 - Name of project containing the samabamba output folder coverage/raw\_output/. 

Optional Inputs & flags:
- input\_directory: Folder containing sambamba output. Default = /coverage/raw\_output/
- group\_by: By default the app produces a plot for each unique Pan number which coverage was calculated for.  If the user would like to group Pan numbers together they can provide a string in the format of `VCP1=PanA,PanB;VCP2=PanX,PanY,PanZ;`. Typical use cases would be where the Pan number represents a disease area and you want to group these together by the capture kit used.
- plot\_figures: Produce plots of output (PDF & HTML) Default = True
- simple\_plot\_only: Use with plot\_figures flag to produce only the PDF plot (Useful for large samples which may cause performance issues when producing interactive plots) Default = False
- no\_jitter: Turn off the overlayed jittered geom\_points in the interactive plots leaving the data as summarised boxplots only (Showing all the data points for large data sets may cause performance issues)  Default = False
 
## How does this script work?
The R script which reads in all data from the folder coverage/raw\_output/ in the project, cleans up the data, and outputs html, pdf, and csv reports.

## What does this script output?

This app outputs:
 - An interactive HTML report with boxplots of every region sorted by coverage from low > high
 - A static plot showing the average for each region
 - A csv file with the region data in tabular form

## What are the limitations of this app?

Large data sets containing many regions/samples may require turning off the interactive plots due to performance issues. 


