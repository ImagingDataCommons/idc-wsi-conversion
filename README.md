# Overview

The WSI conversion process generates [dual-personality DICOM-TIFF](http://www.jpathinformatics.org/article.asp?issn=2153-3539;year=2019;volume=10;issue=1;spage=12;epage=12;aulast=Clunie;type=0) files from source files that are SVS, generic TIFF or OME-TIFF.

The process is driven by a Bourne Shell script, executed on a single input file at a time, and generates multiple DICOM instances (files) in a single DICOM Series, one file for each pyramid resolution layer (and channel, if multi-channel rather than RGB). Each source file contains a single pyramid which is assigned the same DICOM Pyramid UID and Acquisition UID. If macro (overview) and label images are present, they are also etarcted and converted.

Multiple slides for the same subject are grouped into a single DICOM Study, and if there is readily-accessible date information in the TIFF header (or SVS ImageDescription TIFF tag), the first encountered date is used for the StudyDate for successive slides, or the current date is used. The state necsssary to achieve consistent StudyInstanceUID and StudyDate values is maintained across invocations of the conversion script by use of text files that map a study identifier to UID and date; in addition there is a text file that maps specimen ID to SpecimenUID. The use of these state files mean that the script cannot be reliably executed in parallel process since access to the files is not locked or synchronized. The necessary information is passed to the conversion program in the JSON metadata file described below.

The shell script gathers metadata from collection-specific sources, prepares a JSON metadata file describing the rendition of the metadata in DICOM attributes, and feeds the JSON metadata file as well as the input image file to [com.pixelmed.convert.TIFFToDicom](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/TIFFToDicom.html "com.pixelmed.convert.TIFFToDicom") from the [pixelmed toolkit](http://www.dclunie.com/pixelmed/software/index.html "pixelmed toolkit"), which performs the actual conversion.

The JSON metadata file is of the form described for [com.pixelmed.apps.SetCharacteristicsFromSummary](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/apps/SetCharacteristicsFromSummary.html "com.pixelmed.apps.SetCharacteristicsFromSummary").

# Examples

The following invocation of the TCGA-specific script gdcsvstodcm.sh will convert all the SVS files for the specified collection, storing them by default in a diretory "Converted" (which may be overridden on the command line), recording a log of the conversion into the specified log file. Note that the default logging level is "debug" so a considerable amount of information is written to the log file.

`nohup find TCGA-KIRP -follow -name '*.svs' -exec ./gdcsvstodcm.sh '{}' ';' >TCGA-KIRP_gdcsvstodcm.log 2>&1 &`

To make a list of the Study, Series and SOP Instance UIDs associated with the converted files, the following script (which uses dctable from dicom3tools) may be executed:

`./tabulateidentifiersforingestion.sh 2>&1 >identifiers.txt`

# Collection-specific Matters
## NLST
The case_id, what NLST metadata calls pid (participant id), is obtained from the folder name containing the source file, and is used as a prefix to the base file name to produce a slide_id.
E.g., "pathology-NLST_1225files/117492/9718.svs" produces a case_id of 117492, which is used as the DICOM PatientID and a slide_id of 117492_9718, which is used as the DICOM ContainerIdentifier

Limited subject-specific metadata is extracted from the file "nlst_780_prsn_idc_20210527.csv" (filename is hardwired in the "nlstsvstodcm.sh" script), and includes race, cigsmok, gender, age. The smoking status is recorded as an item of AcquisitionContextSequence.

The specimens are assumed to be FFPE and H&E, since no out-of-band information is available, and the SpecimenDescriptionSequence populated accordingly.

PrimaryAnatomicStructureSequence is set to lung.

# Software Dependencies

[pixelmed.jar](http://www.dclunie.com/pixelmed/software/index.html) - used to perform the actual conversion

[dicom3tools](http://www.dclunie.com/dicom3tools/workinprogress/index.html) - used by script for extracting summary of converted files and verifying their compliance

libtiff - used by script for extracting TIFF-specific tag information for decisions about how to perform conversion
