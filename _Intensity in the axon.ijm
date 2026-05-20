
//Preliminar settings
fullname = File.name
name= File.nameWithoutExtension
setOption("DebugMode", true);
setOption("BlackBackground", true);
Stack.setDisplayMode("composite");
run("8-bit");
run("Set Measurements...", "area mean min integrated display redirect=None decimal=4");
run("Colors...", "foreground=white background=black selection=yellow");
run("Options...", "iterations=1 count=1 black");
run("Misc...", "divide=NaN");



//So, the script starts here:

run("Split Channels");

//CHANNELS:
// C1 is RAB to be quantified
// C2 is TrkB
// C3 is SMI31


//Axonal masking and filtering
selectWindow("C3-"+fullname);
run("Brightness/Contrast...");
waitForUser("Adjust levels");
run("Apply LUT");
run("Duplicate...", "title=[AXONAL_MARKER] duplicate");
selectWindow("C3-"+fullname);
run("Duplicate...", "title=[AXONS_MASK] duplicate");
run("Threshold...");
waitForUser("Adjust the threshold to make the mask");
run("Convert to Mask", "method=Default background=Default black");
run("Median...", "radius=1 stack");
run("Divide...", "value=255.000 stack");
imageCalculator("Multiply create stack", "C1-"+fullname,"AXONS_MASK");
run("Z Project...", "projection=[Max Intensity]");
rename("AXONAL_RAB—"+fullname)
selectWindow("C1-"+fullname);
run("Close");
selectWindow("C2-"+fullname);
run("Close");
selectWindow("C3-"+fullname);
run("Close");
selectWindow("Result of C1-"+fullname);
run("Close");


//Create a composite and projection of the original image to select
selectWindow("AXONAL_MARKER");
run("Z Project...", "projection=[Max Intensity]");
run("Duplicate...", "title=[REFERENCE] duplicate");
selectWindow("MAX_AXONAL_MARKER");
run("Close");
selectWindow("AXONAL_MARKER");
run("Close");


//Measure
selectWindow("REFERENCE");
setTool("polyline");
waitForUser("Trace an axon segment nearby");
run("Line to Area");
selectWindow("AXONAL_RAB—"+fullname);
run("Restore Selection");
run("Measure");


saveAs("Results", "/Users/omlazo/Desktop/Rab_intensity.csv");

selectWindow("REFERENCE");
run("Close");
selectWindow("AXONAL_RAB—"+fullname);
run("Close");
selectWindow("AXONS_MASK");
run("Close");