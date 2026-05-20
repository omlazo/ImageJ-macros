//Preliminar settings
fullname = getTitle();
dotIndex = lastIndexOf(fullname, ".");
if (dotIndex >= 0) name = substring(fullname, 0, dotIndex); else name = "" + fullname;  // keep base name as string

setOption("DebugMode", true);
setOption("BlackBackground", true);
Stack.setDisplayMode("composite");
run("8-bit");
run("Set Measurements...", "area mean min integrated display redirect=None decimal=4");
run("Colors...", "foreground=white background=black selection=yellow");
run("Options...", "iterations=1 count=1 black");
run("Misc...", "divide=NaN");

//Output folder (choose once)
Dialog.create("Output folder");
Dialog.addDirectory("Choose where to save the Results CSV", "");
Dialog.show();
outDir = Dialog.getString();
if (outDir == "") outDir = getDirectory("home");
if (!endsWith(outDir, File.separator)) outDir += File.separator;
if (!File.exists(outDir)) File.makeDirectory(outDir);

//So, the script starts here:

run("Split Channels");

//CHANNELS (new dataset):
// C1 is RAB to be quantified
// C2 is SMI32 (axonal marker for masking)
// C3 is MAP2 (unused)
// C4 is DAPI (unused)


//Axonal masking and filtering (SMI32 in C2)
selectWindow("C2-"+fullname);
run("Brightness/Contrast...");
waitForUser("Adjust levels");
run("Apply LUT");
run("Duplicate...", "title=[AXONAL_MARKER] duplicate");
selectWindow("C2-"+fullname);
run("Duplicate...", "title=[AXONS_MASK] duplicate");
run("Threshold...");
waitForUser("Adjust the threshold to make the mask");
run("Convert to Mask", "method=Default background=Default black");
run("Median...", "radius=1 stack");
run("Divide...", "value=255.000 stack");

//Apply mask to Rab (C1) and project
imageCalculator("Multiply create stack", "C1-"+fullname, "AXONS_MASK");
run("Z Project...", "projection=[Max Intensity]");
rename("AXONAL_RAB—"+fullname);

//Close unused channels and intermediates
selectWindow("C1-"+fullname); run("Close");
selectWindow("C2-"+fullname); run("Close");
if (isOpen("C3-"+fullname)) { selectWindow("C3-"+fullname); run("Close"); }
if (isOpen("C4-"+fullname)) { selectWindow("C4-"+fullname); run("Close"); }
if (isOpen("Result of C1-"+fullname)) { selectWindow("Result of C1-"+fullname); run("Close"); }

//Create a composite and projection of the original axonal marker to select
selectWindow("AXONAL_MARKER");
run("Z Project...", "projection=[Max Intensity]");
run("Duplicate...", "title=[REFERENCE] duplicate");
selectWindow("MAX_AXONAL_MARKER"); run("Close");
selectWindow("AXONAL_MARKER");     run("Close");


//Measure (loop for multiple axon segments)
state = getBoolean("Ready to start the analysis of this picture?");
while (state==1) {
    selectWindow("REFERENCE");
    setTool("polyline");
    waitForUser("Trace an axon segment nearby");
    run("Line to Area");

    selectWindow("AXONAL_RAB—"+fullname);
    run("Restore Selection");
    run("Measure");

    state = getBoolean("Are you going to analyse another region?");
}

//Save results with the same name as the original image
saveAs("Results", outDir + name + ".csv");

//Closing
selectWindow("REFERENCE");               run("Close");
selectWindow("AXONAL_RAB—"+fullname);    run("Close");
if (isOpen("AXONS_MASK")) { selectWindow("AXONS_MASK"); run("Close"); }

//Optionally, close everything else left open
// macro "Close All Windows" {
//     while (nImages>0) {
//         selectImage(nImages);
//         close();
//     }
// }
