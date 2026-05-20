# ImageJ-macros
Humble and customised macros for things I do using ImageJ/FIJI. Most of them have been written in modules to be remixed, combined and recycled. Feel free to do that yourself as well.
You can put them in the folder /FIJI/plugins/macros/ to be visible from the Macros menu (the _ at the beginning of the file name is required to appear in the menu).
Advice on how to make them better is always welcome and much appreciated.

### Biosensor
It was made to analyse live biosensors that change nucleus/cytoplasm distribution when phosphorylated (kinase translocator reporters). The macro implements NanoJ-Drift Correction (you need NanoJ-core package: https://github.com/HenriquesLab/NanoJ-Core), then guides you to trace a profile of each cell in the field and to identify nucleus and cytoplasm. The output is a folder in the desktop that contains: the drift-corrected time series, a max projection of the time series, color-coded summaries of the average intensity along time and tables with the intensity values per frame.  

### Rab10 in brain tissue
It analyses z-stacks from brain tissue to answer the question: how much of Rab10 is in neurons and how much of that neuronal Rab10 is in neurons with hyperphosphorylated Tau. The macro separates the amount of Rab10 fluorescence that is in CaMKII domains, and from that, the amount that is also in AT8 positive domains too, makes 3D projection of the merge of both and a table with the intensity measurements. The process is documented in a folder containing the masks and the filtered images.

### Retrograde Accumulation 
It guides you through the process of tracing the soma of the neuron of interest based on the EGFP channel (or equivalent marker) and then quantifies the intensity of the maximum projection in other 2 channels (in my case TrkB and CTB, for example). It gives you a file, with the same name of the reference image, containing the size of the ROI and the mean intensity for each channel.

### retroTrkB in Rab10 domains
Answers the question: What proportion of total retro-TrkB is in Rab10 positive compartments?
This macro takes a 3-channel z-stack, selects a neurite and first determine the TrkB signal that is in HcT positive fields (retro_TrkB), then select the retro_TrkB that is in Rab10-positive fields and measure total and Rab10-correlated. Don't close the results table, because every time you run the macro, the table file is overwritten (if you keep the "Results" window open, this will result in the file being updated). If the axon is not visible in the EGFP channel, run "Preliminars" first (it just makes a projection and offer you to change the brightness and contrast to make the tracing possible).

### Segmentation and CDA
Segments organelles (based for example in TrkB and Rab5 signals) and establishes the borders of the confined domain (a subcellular compartment, axons, dendrites, etc.). Then it measures co-localisation within those boundaries by using Confined Displacement Algorithm. You need GDSC plugins to implement CDA (http://www.sussex.ac.uk/gdsc/intranet/microscopy/UserSupport/AnalysisProtocol/imagej/gdsc_plugins/).

### Topological distributions
The idea here is to be able to manipulate and analyse the data about topological distribution of the signal within the axon along the ortogonal axis. Is like doing a transect, but instead you will have as many transects as pixel lines your image has. The macro straightens, delimitates and then gives you a table .txt with the intensity value of every pixel.

### Background NaN and Measure
A minimal utility to isolate and quantify signal above background in a single channel. It generates a maximum intensity projection of the active stack, splits the channels, and lets you select the one of interest. That channel is duplicated, converted to 32-bit, and thresholded interactively; pixels below the threshold are set to NaN so that subsequent measurements reflect only genuine signal. The result is a single intensity measurement of the thresholded image.

### Intensity Quantification
It measures ERK (or equivalent) signal in three spatially distinct neuronal compartments: the soma, the nucleus, and two axonal segments of comparable length. The macro splits channels, creates a standard deviation projection of the MAP2 channel and a maximum projection of the tubulin channel, merges them as a composite for reference, and then guides you through tracing each compartment in a loop so that multiple neurons can be processed in a single session. The output is a CSV saved to the desktop with the area and mean intensity of every traced region.

### Basic Neuronal Development
A semi-automated morphological survey of neurons in culture, built around the five-stage developmental framework described by Dotti, Sullivan and Banker (1988). For each neuron in a picture the macro guides you to trace the cell body, flag and outline lamellipodia when present, and trace every visible neurite as a polyline from the soma to the tip. It records soma area, lamellipodia area, and individual neurite lengths, and appends the distances to the two nearest neighbouring somas. The output is a tidy CSV — one row per neurite — named after the neuronal type, DIV and picture number, ready to be concatenated across sessions and analysed in R or Python.

***
