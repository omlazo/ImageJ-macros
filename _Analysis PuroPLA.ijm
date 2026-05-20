// _Analysis PuroPLA Refined.ijm
// Optimized for throughput, robustness and readability.
// Solves "Window not found" errors by using Image IDs explicitly.
// Refined with Reference Guide tips (v1.46d).
// Now measures BOTH Particles and Maxima.

// Preliminar settings
fullname = getTitle();
dotIndex = lastIndexOf(fullname, ".");
if (dotIndex >= 0) name = substring(fullname, 0, dotIndex); else name = "" + fullname;

setOption("DebugMode", true);
setOption("BlackBackground", true);
setOption("DisableUndo", true); // Optimize memory
Stack.setDisplayMode("composite");
run("Set Measurements...", "area mean median min integrated redirect=None decimal=4");
run("Colors...", "foreground=white background=black selection=yellow");
run("Options...", "iterations=1 count=1 black");
run("Misc...", "divide=NaN");

// Output & detection dialog
Dialog.create("Puro-PLA Analysis Settings");
Dialog.addDirectory("Output folder", "");
Dialog.addMessage("--- Detection Parameters ---");
Dialog.addCheckbox("Pre-blur PLA channel?", true);
Dialog.addNumber("Sigma for pre-blur (px)", 1.0); // Default adjusted to 1.0 per user request
Dialog.addMessage("Method 1: Analyze Particles (Threshold-based)");
Dialog.addString("Particle size (unit^2)", "0.04-2.00");
Dialog.addString("Circularity (0.00–1.00)", "0.20-1.00");
Dialog.addMessage("Method 2: Find Maxima (Peak-based)");
Dialog.addNumber("Maxima tolerance (Prominence)", 50);
Dialog.show();

outDir   = Dialog.getString();
doBlur   = Dialog.getCheckbox();
sigma    = Dialog.getNumber();
sizeStr  = Dialog.getString();
circStr  = Dialog.getString();
maxTol   = Dialog.getNumber();

if (outDir == "") outDir = getDirectory("home");
if (!endsWith(outDir, File.separator)) outDir += File.separator;
File.makeDirectory(outDir);
File.makeDirectory(outDir + name);

// CSV Header
csvPath = outDir + name + ".csv";
if (!File.exists(csvPath)) {
    // Updated header for BOTH metrics
    header = "Image,Subfield,Region,Area,Mean,Median,IntDen,Part_Count,Part_Dens,Max_Count,Max_Dens,Params\n";
    File.append(header, csvPath);
}

// ================= HELPER FUNCTIONS =================

function safeClose(t) {
    if (t != 0 && isOpen(t)) {
        selectImage(t);
        setOption("Changes", false); // Prevent "Save changes?" dialog
        close();
    }
}

function threshold_interactive_id(imgID, message, method) {
    setBatchMode("show");
    selectImage(imgID);
    run("Threshold...");
    if (method != "") setAutoThreshold(method + " dark");
    waitForUser(message + "\nAdjust threshold then Click OK.");
    
    run("Convert to Mask", "method=Default background=Default black");
    run("Median...", "radius=1 stack"); // Smooth mask
    setBatchMode("hide");
}

function measure_region_id(maskID, intensityID, particlesMaskID, maximaInputID, regionName, sf_index, params_str) {
    // 1. Measure Intensity
    selectImage(maskID);
    run("Create Selection");
    
    // If selection is empty (no pixels), handle gracefully
    type = selectionType();
    
    area=0; mean=0; median=0; intDen=0; 
    partCount=0; partDens=0;
    maxCount=0; maxDens=0;
    
    if (type != -1) {
        // A. Intensity Stats
        selectImage(intensityID);
        run("Restore Selection");
        run("Measure");
        
        r = nResults - 1;
        area   = getResult("Area", r);
        mean   = getResult("Mean", r);
        median = getResult("Median", r);
        intDen = getResult("IntDen", r);
        run("Clear Results");
        
        // B. Count Particles (from Mask)
        selectImage(particlesMaskID);
        run("Restore Selection");
        run("Analyze Particles...", "size="+sizeStr+" circularity="+circStr+" show=Nothing display");
        partCount = nResults;
        run("Clear Results");

        // C. Count Maxima (from Intensity/Blurred Image)
        selectImage(maximaInputID);
        run("Restore Selection");
        run("Find Maxima...", "noise="+maxTol+" output=[List]");
        maxCount = nResults;
        run("Clear Results");
    }
    
    if (area > 0) {
        partDens = partCount / area;
        maxDens = maxCount / area;
    }

    // "Image,Subfield,Region,Area,Mean,Median,IntDen,Part_Count,Part_Dens,Max_Count,Max_Dens,Params"
    line = name + "," + sf_index + "," + regionName + "," + area + "," + mean + "," + median + "," + intDen + "," + partCount + "," + partDens + "," + maxCount + "," + maxDens + "," + params_str + "\n";
    File.append(line, csvPath);
}

// ================= MAIN LOOP =================

setBatchMode(true); 

// Prepare global preview
selectWindow(fullname); 
if (nSlices > 1) {
    run("Z Project...", "projection=[Max Intensity]");
    rename("GLOBAL_PREVIEW");
} else {
    run("Duplicate...", "title=GLOBAL_PREVIEW");
}
previewID = getImageID(); 
selectImage(previewID);
run("Enhance Contrast", "saturated=0.35");

sf = 0;
running = true;

while (running) {
    sf++;
    showStatus("Processing Subfield " + sf + "...");
    
    setBatchMode("show");
    selectImage(previewID);
    setTool("rectangle");
    waitForUser("SUBFIELD " + sf + "\nDraw rectangle for subfield " + sf + ", then Click OK.");
    
    getSelectionBounds(x, y, w, h);
    
    setBatchMode(true); 
    
    // 1. EXTRACT SUBFIELD
    selectWindow(fullname); // Original stack
    makeRectangle(x, y, w, h);
    run("Duplicate...", "title=[Processing_Stack] duplicate");
    stackID = getImageID();
    
    selectImage(stackID);
    run("Split Channels");
    
    selectWindow("C1-Processing_Stack"); c1_ID = getImageID(); rename("C1_temp");
    selectWindow("C2-Processing_Stack"); c2_ID = getImageID(); rename("C2_temp");
    
    c3_ID = 0;
    if (isOpen("C3-Processing_Stack")) {
        selectWindow("C3-Processing_Stack");
        c3_ID = getImageID();
        rename("C3_temp");
    }
    
    baseName = name + "__SF_" + sf;
    tub_mask_name  = baseName + "_TUB_MASK.tif";
    soma_mask_name = baseName + "_SOMA_MASK.tif";
    neur_mask_name = baseName + "_NEUR_MASK.tif";
    dapi_mask_name = baseName + "_DAPI_MASK.tif";
    part_mask_name = baseName + "_PARTICLES_MASK.tif";
    max_points_name= baseName + "_MAXIMA_POINTS.tif";
    
    // 2. PREPARE PROJECTIONS & RAW IDs
    
    // Tubulin (C1)
    selectImage(c1_ID);
    if (nSlices>1) {
        run("Z Project...", "projection=[Max Intensity]");
        tub_raw_ID = getImageID();
        safeClose(c1_ID); 
    } else {
        tub_raw_ID = c1_ID;
    }
    selectImage(tub_raw_ID); rename("TUB_RAW_ID");
    
    // PLA (C2)
    selectImage(c2_ID);
    if (nSlices>1) {
        run("Z Project...", "projection=[Max Intensity]");
        pla_raw_ID = getImageID();
        safeClose(c2_ID);
    } else {
        pla_raw_ID = c2_ID;
    }
    selectImage(pla_raw_ID); rename("PLA_RAW_ID");
    
    // DAPI (C3)
    dapi_raw_ID = 0;
    if (c3_ID != 0) {
        selectImage(c3_ID);
        if (nSlices>1) {
            run("Z Project...", "projection=[Max Intensity]");
            dapi_raw_ID = getImageID();
            safeClose(c3_ID);
        } else {
            dapi_raw_ID = c3_ID;
        }
        selectImage(dapi_raw_ID); rename("DAPI_RAW_ID");
    }
    
    // 3. CREATE MASKS
    
    // --- A. DAPI Mask ---
    dapi_mask_ID = 0;
    if (dapi_raw_ID != 0) {
        selectImage(dapi_raw_ID);
        run("Duplicate...", "title=DAPI_MASK_TEMP");
        dapi_mask_ID = getImageID();
        setAutoThreshold("Otsu dark");
        run("Convert to Mask");
        run("Fill Holes");
        run("Median...", "radius=2");
    }
    
    // --- B. Tubulin Mask (Manual) ---
    selectImage(tub_raw_ID);
    run("Duplicate...", "title=TUB_MASK_TEMP");
    tub_mask_ID = getImageID();
    threshold_interactive_id(tub_mask_ID, "Adjust TUBULIN threshold.", "Default");
    
    // --- C. Soma Mask (Manual + DAPI) ---
    selectImage(tub_raw_ID); run("Duplicate...", "title=Tub_Ref"); tub_ref = getImageID();
    run("Enhance Contrast", "saturated=0.35");
    ref_ID = 0;
    if (dapi_raw_ID != 0) {
        selectImage(dapi_raw_ID); run("Duplicate...", "title=Dapi_Ref"); dapi_ref = getImageID();
        run("Merge Channels...", "c1=Tub_Ref c2=Dapi_Ref create");

        ref_ID = getImageID();
    } else {
        selectImage(tub_ref);
        ref_ID = tub_ref; 
    }
    selectImage(ref_ID);
    Stack.setDisplayMode("composite");
    
    // Manual Trace
    setBatchMode("show");
    selectImage(ref_ID);
    Overlay.remove; 
    setTool("freehand");
    waitForUser("TRACE SOMATA\nTrace outlines -> Press 'b' -> OK when done.");
    
    newImage("Soma_Mask_Temp", "8-bit black", w, h, 1);
    soma_mask_ID = getImageID();
    
    selectImage(ref_ID);
    roiManager("reset");
    run("To ROI Manager"); 
    count = roiManager("count");
    setBatchMode("hide");
    
    if (count > 0) {
        selectImage(soma_mask_ID);
        roiManager("Select All");
        roiManager("Combine");
        setForegroundColor(255, 255, 255);
        run("Fill");
        run("Select None");
    }
    
    if (dapi_mask_ID != 0) {
        imageCalculator("OR", soma_mask_ID, dapi_mask_ID);
    }
    imageCalculator("AND", soma_mask_ID, tub_mask_ID);
    
    // --- D. Neurite Mask ---
    imageCalculator("Subtract create", tub_mask_ID, soma_mask_ID);
    neur_mask_ID = getImageID();
    
    // Save Region Masks
    selectImage(tub_mask_ID); saveAs("Tiff", outDir + name + File.separator + tub_mask_name);
    selectImage(soma_mask_ID); saveAs("Tiff", outDir + name + File.separator + soma_mask_name);
    selectImage(neur_mask_ID); saveAs("Tiff", outDir + name + File.separator + neur_mask_name);
    
    safeClose(ref_ID);

    // 4. PUNCTA DETECTION PREP
    // We work on a duplicate of PLA for detections
    selectImage(pla_raw_ID);
    run("Duplicate...", "title=PLA_For_Detection");
    pla_detect_ID = getImageID();
    
    if (doBlur) {
        selectImage(pla_detect_ID);
        run("Gaussian Blur...", "sigma="+sigma);
    }
    
    // --- Method 1: Particles (Threshold -> Mask) ---
    selectImage(pla_detect_ID);
    run("Duplicate...", "title=ROI_Particles");
    part_mask_ID = getImageID();
    threshold_interactive_id(part_mask_ID, "Adjust PLA Puncta threshold (Particles).", "Default");
    selectImage(part_mask_ID); saveAs("Tiff", outDir + name + File.separator + part_mask_name);
    
    // --- Method 2: Maxima (Intensity Peaks) ---
    // We use the 'pla_detect_ID' (blurred or raw) for finding maxima. 
    // We visualize/save points for record.
    selectImage(pla_detect_ID);
    run("Duplicate...", "title=ROI_Maxima_Points");
    max_points_ID = getImageID();
    // Use 'output=[Single Points]' to generate a mask of points
    run("Find Maxima...", "noise="+maxTol+" output=[Single Points]");
    selectImage(max_points_ID); saveAs("Tiff", outDir + name + File.separator + max_points_name);
    
    // 5. MEASUREMENTS
    // We pass 'part_mask_ID' for particles.
    // We pass 'pla_detect_ID' for Maxima detection (count on intensity image), or 'max_points_ID' if we just count points.
    // 'measure_region_id' logic below uses Find Maxima on intensity image again for counting. 
    // Let's stick to that to be safe, so we pass 'pla_detect_ID'.
    
    params = "PreBlur="+doBlur+"_Sigma="+sigma;
    
    measure_region_id(tub_mask_ID,  pla_raw_ID, part_mask_ID, pla_detect_ID, "TUBULIN_TOTAL", sf, params);
    measure_region_id(soma_mask_ID, pla_raw_ID, part_mask_ID, pla_detect_ID, "SOMA", sf, params);
    measure_region_id(neur_mask_ID, pla_raw_ID, part_mask_ID, pla_detect_ID, "NEURITES", sf, params);
    
    // CLEANUP
    safeClose(tub_mask_ID);
    safeClose(soma_mask_ID);
    safeClose(neur_mask_ID);
    safeClose(dapi_mask_ID);
    safeClose(part_mask_ID);
    safeClose(max_points_ID);
    safeClose(pla_detect_ID);
    safeClose(pla_raw_ID);
    safeClose(dapi_raw_ID);
    safeClose(tub_raw_ID);
    roiManager("reset");
    
    setBatchMode("show"); 
    selectImage(previewID); 
    running = getBoolean("Analyze another subfield?");
}

selectImage(previewID);
close(); 
setBatchMode(false);
showMessage("Analysis Finished!");

// by omlazo 2026 — use, copy and distribute freely.
