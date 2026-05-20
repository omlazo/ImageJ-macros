// _Neuron_Morphology.ijm
// Morphological description of neurons in culture (Dotti et al. 1988 framework).
//
// For each neuron in a single image the user traces:
//   Step 1 — The cell body (freehand ROI): records soma area and centroid position.
//   Step 2 — The full cell outline including lamellipodia (optional freehand ROI):
//            lamellipodia area = full-contour area − soma area.
//   Step 3 — Each neurite as a polyline from soma centre to tip: records length.
//
// Each neuron's rows are written to the CSV immediately after data collection so
// that a mid-session crash does not discard earlier neurons.  The two nearest-
// neighbour columns are filled with "NA" during the loop and patched in a second
// pass once all centroids are known.
//
// OUTPUT: tidy CSV — one row per neurite (one row per neuron if no neurites traced).
// Columns: filename, neuron_type, DIV, pic_number, neuron_number,
//          soma_area, lamellipodia, lamellipodia_area,
//          neurite_number, neurite_length,
//          nearest_neighbour_1, nearest_neighbour_2
//
// Saved as:  ~/Desktop/[neuronType]-DIV[div]-pic[picNum]-[imageName].csv
// by omlazo 2026


//Preliminar settings
fullname = getTitle();
dotIndex = lastIndexOf(fullname, ".");
if (dotIndex >= 0) name = substring(fullname, 0, dotIndex); else name = "" + fullname;
setOption("DebugMode", true);
setOption("BlackBackground", true);
if (nSlices > 1) Stack.setDisplayMode("composite");   // guard: single-plane images have no stack
run("8-bit");
run("Set Measurements...", "area mean min integrated display redirect=None decimal=4");
run("Colors...", "foreground=white background=black selection=yellow");
run("Options...", "iterations=1 count=1 black");
run("Misc...", "divide=NaN");


//So, the script starts here:

// Override measurements for this macro: area (soma and lamellipodia ROIs),
// centroid XY (neuron position for nearest-neighbour computation),
// perimeter (reports as "Length" for polyline selections — neurite length).
run("Set Measurements...", "area centroid perimeter display redirect=None decimal=4");
run("Clear Results");


// --- Metadata dialog ---
// All fields are stored in every output row so that files from different
// images can be safely concatenated downstream (R, Python, etc.).
Dialog.create("Neuron Morphology — Metadata");
Dialog.addString("Neuronal type", "Hippocampal");
Dialog.addNumber("DIV", 2);
Dialog.addNumber("Picture number", 1);
Dialog.show();
neuronType = Dialog.getString();
div        = d2s(Dialog.getNumber(), 0);   // integer string, e.g. "2"
picNum     = d2s(Dialog.getNumber(), 0);   // integer string, e.g. "1"


// --- CSV output path ---
// Deleted and recreated fresh on each run to prevent duplicate headers.
csvPath = "/Users/omlazo/Desktop/" + neuronType + "-DIV" + div + "-pic" + picNum + "-" + name + ".csv";
if (File.exists(csvPath)) File.delete(csvPath);
csvHeader = "filename,neuron_type,DIV,pic_number,neuron_number,soma_area,lamellipodia,lamellipodia_area,neurite_number,neurite_length,nearest_neighbour_1,nearest_neighbour_2\n";
File.append(csvHeader, csvPath);


// --- Centroid arrays for nearest-neighbour computation ---
// These are the only data arrays that need to survive the outer loop.
// All other per-neuron values are written to the CSV immediately and
// do not need to be stored between iterations.
maxNeurons = 100;
cxArr      = newArray(maxNeurons);   // soma centroid X (pixels)
cyArr      = newArray(maxNeurons);   // soma centroid Y (pixels)
neuronCount = 0;


// =====================================================================
// OUTER LOOP — one iteration per neuron
// Each neuron's rows are appended to the CSV before moving to the next,
// so data is safe even if the macro is interrupted mid-session.
// =====================================================================
keepTracing = getBoolean("Start tracing neurons in this picture?");

while (keepTracing) {

    neuronCount++;
    n = neuronCount - 1;   // zero-based index into centroid arrays


    // ---------- Step 1: Soma ----------
    // Freehand ROI tightly around the cell body, excluding lamellipodia.
    // Records area and centroid; centroid is stored for nearest-neighbour maths.
    setTool("freehand");
    waitForUser("Neuron " + neuronCount + " — Step 1: Soma\nDraw the cell body outline, then click OK.");
    run("Clear Results");          // clear before measuring so index 0 is always the fresh result
    run("Measure");
    somaArea = getResult("Area", 0);
    cxArr[n] = getResult("X",    0);   // centroid X of the soma selection
    cyArr[n] = getResult("Y",    0);   // centroid Y of the soma selection
    run("Select None");


    // ---------- Step 2: Lamellipodia ----------
    // If lamellipodia are present the user re-draws a larger freehand ROI
    // covering the full cell including those structures.
    // Lamellipodia area = full-contour area − soma area.
    lamelStr  = "FALSE";
    lamelArea = 0;
    hasLamel = getBoolean("Neuron " + neuronCount + " — Step 2: Lamellipodia\nDoes this neuron have lamellipodia?");

    if (hasLamel) {
        lamelStr = "TRUE";
        setTool("freehand");
        waitForUser("Neuron " + neuronCount + " — Step 2: Lamellipodia\nDraw full outline including lamellipodia, then click OK.");
        run("Clear Results");
        run("Measure");
        lamelArea = getResult("Area", 0) - somaArea;   // isolate lamellipodia-only area
        run("Select None");
    }


    // ---------- Step 3: Neurites ----------
    // Each neurite is traced as a polyline from soma centre to process tip.
    // ImageJ reports line selection length in the "Length" column automatically.
    // One CSV row is appended per neurite, with "NA" placeholders for NN columns.
    neuriteCount = 0;
    traceNeurite = getBoolean("Neuron " + neuronCount + " — Step 3: Neurites\nTrace a neurite for this neuron?");

    while (traceNeurite) {
        neuriteCount++;
        setTool("polyline");
        waitForUser("Neuron " + neuronCount + ", neurite " + neuriteCount + "\nTrace from soma centre to the neurite tip, then click OK.");
        run("Clear Results");
        run("Measure");
        nLen = getResult("Length", 0);   // length of the polyline selection
        run("Select None");

        // Write this neurite immediately — data is safe on disk from this point on
        csvLine = fullname + "," + neuronType + "," + div + "," + picNum + "," + neuronCount + "," +
                  d2s(somaArea, 4) + "," + lamelStr + "," + d2s(lamelArea, 4) + "," +
                  neuriteCount + "," + d2s(nLen, 4) + ",NA,NA\n";
        File.append(csvLine, csvPath);

        traceNeurite = getBoolean("Neuron " + neuronCount + " — Step 3: Neurites\nTrace another neurite for this neuron?");
    }

    // If no neurites were traced, write one placeholder row for this neuron
    if (neuriteCount == 0) {
        csvLine = fullname + "," + neuronType + "," + div + "," + picNum + "," + neuronCount + "," +
                  d2s(somaArea, 4) + "," + lamelStr + "," + d2s(lamelArea, 4) + ",0,0,NA,NA\n";
        File.append(csvLine, csvPath);
    }

    keepTracing = getBoolean("Trace another neuron in this picture?");
}
// end outer while


// =====================================================================
// NEAREST NEIGHBOUR COMPUTATION
// Euclidean distance between every pair of soma centroids (pixels).
// Tracks the two running minima per neuron without needing a sort.
// "NA" is used when fewer than 2 or 3 neurons are available.
// =====================================================================
nn1Arr = newArray(neuronCount);   // distance to nearest neighbour
nn2Arr = newArray(neuronCount);   // distance to second nearest neighbour

i = 0;
while (i < neuronCount) {
    d1 = 999999999;   // running minimum
    d2 = 999999999;   // running second minimum

    j = 0;
    while (j < neuronCount) {
        if (j != i) {
            dx   = cxArr[i] - cxArr[j];
            dy   = cyArr[i] - cyArr[j];
            dist = sqrt(dx*dx + dy*dy);
            if (dist < d1) {
                d2 = d1;   // demote previous nearest to second nearest
                d1 = dist;
            } else if (dist < d2) {
                d2 = dist;
            }
        }
        j++;
    }
    nn1Arr[i] = d1;
    nn2Arr[i] = d2;
    i++;
}


// =====================================================================
// PATCH NN COLUMNS
// Re-reads the CSV written during the loop, replaces the "NA" placeholders
// in the last two columns with the computed nearest-neighbour distances,
// then overwrites the file.  The neuron_number field (column index 4,
// 1-indexed) maps each data row back to its centroid array entry.
// =====================================================================
rawContent = File.openAsString(csvPath);
allLines   = split(rawContent, "\n");

// Build the entire new file content in memory first.
// Only delete and rewrite the file once the full string is ready,
// so a crash mid-loop can never leave the CSV empty.
newContent = csvHeader;

li = 1;   // start at 1 to skip the header line
while (li < lengthOf(allLines)) {
    line = replace(allLines[li], "\r", "");   // strip Windows-style carriage return if present
    if (lengthOf(line) > 0) {
        fields = split(line, ",");
        ni = parseFloat(fields[4]) - 1;   // parseFloat() forces numeric coercion before subtraction;
                                           // fields[4] is the neuron_number string (1-indexed) → 0-based index

        if (neuronCount >= 2) { nn1Str = d2s(nn1Arr[ni], 4); } else { nn1Str = "NA"; }
        if (neuronCount >= 3) { nn2Str = d2s(nn2Arr[ni], 4); } else { nn2Str = "NA"; }

        // Reconstruct the first 10 fields unchanged, then append the patched NN values
        newLine = "";
        fi = 0;
        while (fi < 10) {
            if (fi > 0) newLine = newLine + ",";
            newLine = newLine + fields[fi];
            fi++;
        }
        newLine = newLine + "," + nn1Str + "," + nn2Str + "\n";
        newContent = newContent + newLine;
    }
    li++;
}

// Full content is ready — now safe to overwrite the file
File.delete(csvPath);
File.append(newContent, csvPath);

showMessage("Analysis complete!\n" +
            neuronCount + " neuron(s) recorded.\n \nSaved to:\n" + csvPath);


// =====================================================================
// CLOSE ALL WINDOWS
// =====================================================================
run("Clear Results");
if (isOpen("ROI Manager")) { selectWindow("ROI Manager"); run("Close"); }
while (nImages > 0) {
    selectImage(nImages);
    close();
}

// by omlazo 2026 — use, copy and distribute freely.
