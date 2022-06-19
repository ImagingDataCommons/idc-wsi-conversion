# Overview

The WSI conversion process generates [dual-personality DICOM-TIFF](http://www.jpathinformatics.org/article.asp?issn=2153-3539;year=2019;volume=10;issue=1;spage=12;epage=12;aulast=Clunie;type=0) files by lossless conversion from source files that are SVS, generic TIFF or OME-TIFF.

The process is lossless in that the JPEG or JPEG 2000 compressed tiles are not decompressed and re-compressed, or re-tiled, and all supplied layers are copied. Rather, the supplied compressed bitstream is re-used as is, apart from the re-injection of the factored-out TIFF JPEG tables that control decompression, and the insertion of APPE marker segments to signal RGB rather than YCbCr color space where necessary, and the addition of empty JPEG tiles when illegal zero-length tiles are present in the source (a recognized Leica/Aperio defect).

The process is driven by a Bourne Shell script, executed on a single input file at a time, and generates multiple DICOM instances (files) in a single DICOM Series, one file for each pyramid resolution layer (and channel, if multi-channel rather than RGB). Each source file is expected to contain a single pyramid that is assigned the same DICOM Pyramid UID and Acquisition UID in the converted Series. If macro (overview) and label images are present, they are also etarcted and converted.

Multiple slides for the same subject are grouped into a single DICOM Study, and if there is readily-accessible date information in the TIFF header (or SVS ImageDescription TIFF tag), the first encountered date is used for the StudyDate for successive slides, or the current date is used. The state necsssary to achieve consistent StudyInstanceUID and StudyDate values is maintained across invocations of the conversion script by use of text files that map a study identifier to UID and date; in addition there is a text file that maps specimen ID to SpecimenUID. The use of these state files mean that the script cannot be reliably executed in parallel process since access to the files is not locked or synchronized. The necessary information is passed to the conversion program in the JSON metadata file described below.

Even though the converted DICOM files are dual-personality TIFF, and can be read by non-DICOM-aware TIFF tools, each converted DICOM file contains only one layer, and hence will not work with tools that expect all the layers to be combined in one file (i.e., lower resolution layers of the pyramid are not synthesized for each file, nor are lower resolution layers copied from the SVS or TIFF input file).

The shell script gathers metadata from collection-specific sources, prepares a JSON metadata file describing the rendition of the metadata in DICOM attributes, and feeds the JSON metadata file as well as the input image file to [com.pixelmed.convert.TIFFToDicom](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/TIFFToDicom.html "com.pixelmed.convert.TIFFToDicom") from the [pixelmed toolkit](http://www.dclunie.com/pixelmed/software/index.html "pixelmed toolkit"), which performs the actual conversion.

The JSON metadata file is of the form described for [com.pixelmed.apps.SetCharacteristicsFromSummary](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/apps/SetCharacteristicsFromSummary.html "com.pixelmed.apps.SetCharacteristicsFromSummary").

# Examples

The following invocation of the TCGA-specific script gdcsvstodcm.sh will convert all the SVS files for the specified collection, storing them by default in a diretory "Converted" (which may be overridden on the command line), recording a log of the conversion into the specified log file. Note that the default logging level is "debug" so a considerable amount of information is written to the log file.

`nohup find TCGA-KIRP -follow -name '*.svs' -exec ./gdcsvstodcm.sh '{}' ';' >TCGA-KIRP_gdcsvstodcm.log 2>&1 &`

To make a list of the Study, Series and SOP Instance UIDs associated with the converted files, the following script (which uses dctable from dicom3tools) may be executed:

`./tabulateidentifiersforingestion.sh 2>&1 >identifiers.txt`

# Collection-specific Matters
## NLST
The NLST images were obtained from TCIA in a single Aspera Faspex package that was supplied on request, using the [command line utility supplied by IBM](http://ak-delivery04-mul.dhe.ibm.com/sar/CMA/OSA/08q6g/0/ibm-aspera-cli-3.9.6.1467.159c5b1-linux-64-release.sh).

For NLST SVS images, the ["nlstsvstodcm.sh"](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/nlstsvstodcm.sh) script performs the conversion.

The case_id, what NLST metadata calls pid (participant id), is obtained from the folder name containing the source file, and is used as a prefix to the base file name to produce a slide_id.
E.g., "pathology-NLST_1225files/117492/9718.svs" produces a case_id of 117492, which is used as the DICOM PatientID and a slide_id of 117492_9718, which is used as the DICOM ContainerIdentifier

Limited subject-specific metadata is extracted from the file "nlst_780_prsn_idc_20210527.csv" (filename is hardwired in the "nlstsvstodcm.sh" script), and includes race, cigsmok, gender, age. The smoking status is recorded as an item of AcquisitionContextSequence.

The specimens are assumed to be FFPE and H&E, since no out-of-band information is available, and the SpecimenDescriptionSequence populated accordingly.

PrimaryAnatomicStructureSequence is set to lung.

## TCGA
The TCGA pathology images were obtained from GDC using their ["gdcclient"](http://github.com/NCI-GDC/gdc-client) tool as described [here](https://gdc.cancer.gov/access-data/gdc-data-transfer-tool). The image files were downloaded by feeding gdcclient with manifests retrieved manually, one TCGA project at a time, from the [GDC portal](http://portal.gdc.cancer.gov/legacy-archive/search/f), and using the Files tab selecting "Tissue Slide Image" as the "Data Type".

For TCGA SVS images, the ["gdcsvstodcm.sh"](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/gdcsvstodcm.sh) script performs the conversion.

No out of band metadata was used, since the supplied SVS file name contain embedded within them the so-called ["barcode information"](http://docs.gdc.cancer.gov/Encyclopedia/pages/TCGA_Barcode/), which describe in detail the source site, participant, sample, vial, portion, analyte and slide identifier. The slide identifier includes information about whether the specimen is frozen or FFPE. The hierarchical specimen identifiers are described in successive items of the SpecimenPreparationSequence, fed to com.pixelmed.convert.TIFFToDicom via the JSON metadata.

The project name is NOT in the file name, so is obtained from the folder name in which the source files are contained. This project name is encoded not only in the ClinicalTrialProtocolName as well as the TCIA private data element (0013,xx10,"CTP"), but is also used to determine the anatomy for PrimaryAnatomicStructureSequence, since each TCGA collection is anatomically-specific.

The tissue type is also defined in the barcode-based filename, so whether or not it was normal tissue adjacent to the tumor, or tumor tissue, is added as a modifier (PrimaryAnatomicStructureModifierSequence) to the PrimaryAnatomicStructureSequence.

##HTAN
The HTAN pathology images were shared by the HTAN DCC, exported to a Google Bucket from the the source Sage Synpase platform, hence the selection was performed by the DCC not IDC. Each "atlas" (one per submitting site) contains images of various types including reference brightfield conventionally stained images, variously supplied as SVS or OME-TIFF, and multichannel images where each grayscale channel represents some flourescent antibody or similar. 

A single metadata spreadsheet in CSV form supplied by HTAN DCC listed the file names, the parent specimen ID (from which the subject participant ID could be extracted) as well as other metadata that was used during the conversion, such as the assay type (e.g., 'H&E'), and information about the pixel size (x,y and z), if present, which is not always available from the TIFF or SVS file headers).

The non-SVS TIFF images had been decompressed from the original form (whether lossy compressed or not) and were losslessly compressed using LZW. The converted images were generally left uncompressed, unless the pixel data of each single layer per channel was too large to be encoded within a limit that the Google Healthcare API enforced (2GB, which is less than the uncompressed DICOM file pixel data size limit of appoximately 4GB), in which case reversible (lossless) JPEG 2000 was used, since that is the only lossless compression scheme supported by commonly used TIFF tools (even though it is a proprietary Aperio TIFF extension).

The non-SVS TIFF images were usually but not always tiled pyramids. When not tiled, the conversion process re-tiled them (using libtiff tiffcp) before conversion (e.g., Vanderbilt H&E images) unless the image was already quite small (e.g., WUSTL IMC).

In addition to the primary metadata spreadsheet, additional information about each subject was obtained from the public HTAN portal and used to obtain gender, race and vital status (alive or dead) information to populate the DICOM header.

# Software Dependencies

[pixelmed.jar](http://www.dclunie.com/pixelmed/software/index.html) - used to perform the actual conversion

[dicom3tools](http://www.dclunie.com/dicom3tools/workinprogress/index.html) - used by script for extracting summary of converted files and verifying their compliance

libtiff - used by script for extracting TIFF-specific tag information for decisions about how to perform conversion
