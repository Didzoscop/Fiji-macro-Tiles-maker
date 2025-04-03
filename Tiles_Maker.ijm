// Made by HENRY Louis (Paris, France) ∣ 2025
// Contact : louis.henry@univ-tlse3.fr
// If you need help to use Tiles Maker, you can check the Immulab website
// Link : https://www.immulab.fr/cms/index.php/team/tools/lab-tools/tiles-maker

//-------------------------------------------//
// GLOBAL FUNCTIONS (search, closing, etc.)
//-------------------------------------------//

function closeWindowByTitle(titleToClose) {
    n = nImages();
    for (id = 1; id <= n; id++) {
        selectImage(id);
        if (getTitle() == titleToClose) {
            close();
            return 1;
        }
    }
    return 0;
}

function renameWindowIfFound(oldTitle, newTitle) {
    n = nImages();
    for (id = 1; id <= n; id++) {
        selectImage(id);
        if (getTitle() == oldTitle) {
            rename(newTitle);
            return 1;
        }
    }
    return 0;
}

function imageIsOpen(titleToCheck) {
    n = nImages();
    for (id = 1; id <= n; id++) {
        selectImage(id);
        if (getTitle() == titleToCheck) {
            return true;
        }
    }
    return false;
}

function extractBaseName(fileName) {
    index = indexOf(fileName, "_");
    if (index != -1) {
        return substring(fileName, 0, index);
    }
    return fileName;
}

//-------------------//
// TILES MAKER CORE
//-------------------//

// Configure image properties
Dialog.create("Image properties");
Dialog.addNumber("Pixel Width:", 0.645);
Dialog.addNumber("Pixel Height:", 0.645);
Dialog.addString("Unit:", "µm");
Dialog.addNumber("Voxel Depth:", 1.0);
Dialog.addNumber("Origin:", 0.0);
Dialog.show();

pixelWidth  = Dialog.getNumber();
pixelHeight = Dialog.getNumber();
unit        = Dialog.getString();
voxelDepth  = Dialog.getNumber();
origin      = Dialog.getNumber();

dir = getDirectory("Select a folder containing .czi files");
if (dir == "") exit("No folder selected. Macro stopped.");

// Check if "Result" folder already exists
resultDir = dir + "Result";
if (File.exists(resultDir)) {
    suffix = 1;
    while (File.exists(resultDir + suffix)) {
        suffix++;
    }
    resultDir = resultDir + suffix;
}

// Create a unique folder
File.makeDirectory(resultDir);
print("Result directory created: " + resultDir);

// Create the "Temp" folder inside "ResultX"
tempDir = resultDir + File.separator + "Temp";
File.makeDirectory(tempDir);

// Create the "Tiles" folder inside "ResultX"
TilesDir = resultDir + File.separator + "Tiles";
File.makeDirectory(TilesDir);

// Create the "Images" folder inside "ResultX"
ImgDir = resultDir + File.separator + "Images";
File.makeDirectory(ImgDir);


// Configure cropping settings
Dialog.create("Cropping option");
Dialog.addMessage("Do you want to crop the images?");
Dialog.addCheckbox("Yes", true);
Dialog.addCheckbox("Keep same selection for all images", false);
Dialog.show();

doCrop = Dialog.getCheckbox();  
sameCropForAll = Dialog.getCheckbox();  
xCrop = yCrop = wCrop = hCrop = -1;

channelNamesStored = false;
storedChannelNames = newArray();

listFiles = getFileList(dir);

// Declare global variables
var orderChosen = false;
var globalOrderedImages = newArray();

adjustBrightnessChosen = false;

// Crop images
for (f = 0; f < listFiles.length; f++) {
	if (!endsWith(listFiles[f], ".tif") && !endsWith(listFiles[f], ".czi") && !endsWith(listFiles[f], ".lif") && !endsWith(listFiles[f], ".nd2") && !endsWith(listFiles[f], ".ome.tiff") && !endsWith(listFiles[f], ".oif") && !endsWith(listFiles[f], ".dv") && !endsWith(listFiles[f], ".flex")) continue;
    
	    pathCzi  = dir + listFiles[f];
	    fileName = File.getName(pathCzi);
	    baseName = extractBaseName(fileName);
	
	    run("Bio-Formats Importer", "open=[" + pathCzi + "] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	    rename(baseName);
	    print("Processing file: " + baseName);
    
    if (doCrop) {
        if (sameCropForAll && xCrop != -1) {
            makeRectangle(xCrop, yCrop, wCrop, hCrop);
            run("Crop");
        } else {
            waitForUser("Draw the crop area for " + baseName + ", then click OK.");
            if (selectionType() != -1) {
                getSelectionBounds(xCrop, yCrop, wCrop, hCrop);
                makeRectangle(xCrop, yCrop, wCrop, hCrop);
                run("Crop");
            } else {
                print("No selection detected, skipping crop for " + baseName);
            }
        }
    }
    
    // Temporarily name channels as C1, C2, Cn...
    Stack.getDimensions(w, h, c, s, fr);
    run("Split Channels");
    closeWindowByTitle(baseName);
    
    finalChannelNames = newArray(c);
    for (ch = 1; ch <= c; ch++) {
        oldName = "C" + ch + "-" + baseName;
        newName = "C" + ch;
        renameWindowIfFound(oldName, newName);
        finalChannelNames[ch-1] = newName;
    }
    
    // Prompt to rename unique channels before creating the composite
    if (!channelNamesStored) {
        Dialog.create("Rename Channels");
        Dialog.addMessage("Enter new names for each channel:");
        storedChannelNames = newArray(lengthOf(finalChannelNames));
    
        for (i = 0; i < lengthOf(finalChannelNames); i++) {
            Dialog.addString("New name for " + finalChannelNames[i] + ":", finalChannelNames[i]);
        }
        Dialog.show();
    
        for (i = 0; i < lengthOf(finalChannelNames); i++) {
            storedChannelNames[i] = Dialog.getString();
        }
        channelNamesStored = true;
    }
    
    // Apply new names
    for (i = 0; i < lengthOf(finalChannelNames); i++) {
        selectImage(finalChannelNames[i]);
        rename(storedChannelNames[i]); 
    }
    
	// Brightness/Contrast adjustments
	if (!adjustBrightnessChosen) { 
	    Dialog.create("Adjust Brightness/Contrast");
	    Dialog.addMessage("Do you want to adjust Brightness/Contrast for each image?");
	    Dialog.addChoice("Select option:", newArray("No", "Yes"), "No");
	    Dialog.show();
	    adjustBrightness = Dialog.getChoice(); 
	    adjustBrightnessChosen = true; 
	}
	
	// Apply choices to all images
	if (adjustBrightness == "Yes") {
	    for (i = 0; i < lengthOf(finalChannelNames); i++) {
	        selectImage(storedChannelNames[i]); 
	        imageTitle = getTitle(); 
	        run("Brightness/Contrast..."); 
	        waitForUser("Adjust Brightness/Contrast", "Adjust brightness/contrast for '" + imageTitle + "'. Click OK to continue after adjusting."); // Attente de validation avec titre
	    }
	}

    
    // Composite assembly
    compositeName = "";
    for (i = 0; i < lengthOf(storedChannelNames); i++) {
        compositeName += "+" + storedChannelNames[i];
    }
    compositeName = compositeName.substring(1);
    
    mergeCommand = "";
    for (i = 0; i < lengthOf(storedChannelNames); i++) {
        mergeCommand += " c" + (i+1) + "=" + storedChannelNames[i];
    }
    mergeCommand += " create keep";
    run("Merge Channels...", mergeCommand);
    rename(compositeName);

    CompositeTitle = getTitle();
	run("RGB Color"); 
	close(CompositeTitle); 
	RGBCompositeTitle = getTitle();
	NewRGBTitle = replace(RGBCompositeTitle, " \\(RGB\\)", ""); 
	selectWindow(RGBCompositeTitle);
	rename(NewRGBTitle);
	selectWindow(CompositeTitle);
	    

	saveIndex = 1; 

	while (File.exists(resultDir + File.separator + saveIndex + "-" + baseName + "_someImage.png")) {
	    saveIndex++;
	}
	
	// Labeling and scale bar
	savedImages = newArray();
	imageTitles = newArray();
	
	for (i = 1; i <= nImages(); i++) {
	    selectImage(i);
	
	    winTitle = getTitle();
	    imgWidth = getWidth();
	    
	    // Determine suited scale bar width
	    if (imgWidth < 200) {
	        scaleBarWidth = 20;
	    } else if (imgWidth < 1000) {
	        scaleBarWidth = 50;
	    } else {
	        scaleBarWidth = 100;
	    }
	    
	    run("Scale Bar...", "width=" + scaleBarWidth + " height=50 bold overlay location=[Lower Right]");
	    run("Label...", "format=Text starting=1 interval=1 x=10 y=20 font=20 text=[" + winTitle + "] range=1-1 use");
	    
	    uniqueSavePath = ImgDir + File.separator + saveIndex + "-" + baseName + "_" + winTitle + ".png";
	    while (File.exists(uniqueSavePath)) {
	        saveIndex++;
	        uniqueSavePath = ImgDir + File.separator + saveIndex + "-" + baseName + "_" + winTitle + ".png";
	    }
	    
	    tempSavePath = tempDir + File.separator + winTitle + ".png";
	    saveAs("PNG", tempSavePath);

	    saveAs("PNG", uniqueSavePath);
	    
	    savedImages = Array.concat(savedImages, uniqueSavePath);
	    imageTitles = Array.concat(imageTitles, getTitle());
	    
	    run("RGB Color");
	}

	saveIndex++;
		
	// User's choice of order
	if (!orderChosen) {
	    while (nImages() > 0) {
	        selectImage(nImages());
	        close();
	    }
	
	    fileList = getFileList(tempDir);
	
	    if (lengthOf(fileList) == 0) {
	        exit("Error: No images found in Temp folder.");
	    }
	
	    savedTempImages = newArray();
	    for (i = 0; i < lengthOf(fileList); i++) {
	        filePath = tempDir + File.separator + fileList[i];
	        open(filePath);
	        savedTempImages = Array.concat(savedTempImages, filePath);
	    }
	
	    nbImages = nImages();
	    imageTitles = newArray();
	    for (i = 1; i <= nbImages; i++) {
	        selectImage(i);
	        imageTitles = Array.concat(imageTitles, getTitle());
	    }
	
	    Dialog.create("Select Image Order for Mosaic");
	    Dialog.addMessage("Select the order of the images (up to 20):");
	
	    maxImages = lengthOf(imageTitles);
	    if (maxImages > 20) maxImages = 20;
	
	    globalOrderedImages = newArray(maxImages);
	    for (i = 0; i < maxImages; i++) {
	        Dialog.addChoice("Image " + (i+1) + ":", imageTitles, imageTitles[i]);
	    }
	    Dialog.show();
	
	    for (i = 0; i < maxImages; i++) {
	        globalOrderedImages[i] = Dialog.getChoice();
	    }
	
	    orderChosen = true;
	}
	
	else {
	    while (nImages() > 0) {
	        selectImage(nImages());
	        close();
	    }

	    for (i = 0; i < lengthOf(globalOrderedImages); i++) {
	        filePath = tempDir + File.separator + globalOrderedImages[i];
	        
	        if (File.exists(filePath)) {
	            open(filePath);
	        } else {
	            exit("Error: File not found - " + filePath);
	        }
	    }
	}
    
    // Concatenation
    concatCommand = "title=TempConcat";
    for (i = 0; i < maxImages; i++) {
        concatCommand += " image" + (i+1) + "=" + globalOrderedImages[i];
    }
    
    for (i = 1; i <= nImages(); i++) {
    selectImage(i);

	}

    run("Concatenate...", concatCommand);
    
    // Tiles assembly
    cols = Math.ceil(Math.sqrt(maxImages));
    rows = Math.ceil(maxImages / cols);
    
    run("Make Montage...", "columns=" + cols + " rows=" + rows + " scale=1 border=6");
    
    tileIndex = 1;
    tileName = "" + tileIndex + "-" + baseName + "_Tiles";
    while (imageIsOpen(tileName) || File.exists(TilesDir + "/" + tileName + ".png")) {
        tileIndex++;
        tileName = "" + tileIndex + "-" + baseName + "_Tiles";
    }
    rename(tileName);
    
    saveAs("PNG", TilesDir + "/" + tileName + ".png");

    while (nImages() > 0) {
        selectImage(nImages());
        close();
    }

}
