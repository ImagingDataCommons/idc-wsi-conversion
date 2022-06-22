# Overview

The WSI conversion process generates [dual-personality DICOM-TIFF](http://www.jpathinformatics.org/article.asp?issn=2153-3539;year=2019;volume=10;issue=1;spage=12;epage=12;aulast=Clunie;type=0) files by lossless conversion from source files that are SVS, generic TIFF or OME-TIFF.

The process is lossless in that the JPEG or JPEG 2000 compressed tiles are not decompressed and re-compressed, or re-tiled, and all supplied layers are copied. Rather, the supplied compressed bitstream is re-used as is, apart from the re-injection of the factored-out TIFF JPEG tables that control decompression, and the insertion of APPE marker segments to signal RGB rather than YCbCr color space where necessary, and the addition of empty JPEG tiles when illegal zero-length tiles are present in the source (a recognized Leica/Aperio defect).

The process is driven by a Bourne Shell script, executed on a single input file at a time, and generates multiple DICOM instances (files) in a single DICOM Series, one file for each pyramid resolution layer (and channel, if multi-channel rather than RGB). Each source file is expected to contain a single pyramid that is assigned the same DICOM Pyramid UID and Acquisition UID in the converted Series. If macro (overview) and label images are present, they are also extracted and converted.

Multiple slides for the same subject are grouped into a single DICOM Study, and if there is readily-accessible date information in the TIFF header (or SVS ImageDescription TIFF tag), the first encountered date is used for the StudyDate for successive slides, or the current date is used. The state necessary to achieve consistent StudyInstanceUID and StudyDate values is maintained across invocations of the conversion script by use of text files that map a study identifier to UID and date; in addition there is a text file that maps specimen ID to SpecimenUID. The use of these state files mean that the script cannot be reliably executed in parallel process since access to the files is not locked or synchronized. The necessary information is passed to the conversion program in the JSON metadata file described below. Since a single Study is used for all images for the same subject, a single Accession is also recorded in AccessionNumber.

The shell script gathers metadata from collection-specific sources, prepares a JSON metadata file describing the rendition of the metadata in DICOM attributes, and feeds the JSON metadata file as well as the input image file to a Java program, [com.pixelmed.convert.TIFFToDicom](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/TIFFToDicom.html "com.pixelmed.convert.TIFFToDicom") from the [pixelmed toolkit](http://www.dclunie.com/pixelmed/software/index.html "pixelmed toolkit"), which performs the actual conversion. TIFFToDicom currently supports SVS and OME-TIFF to the extent that it can extract multiple IFD and SubIFD entries in those files that contain layers of the pyramid, color images or multiple grayscale channels (immunofluorescence (IF)) and macro or label images, and whatever metadata is present in the TIFF tags or proprietary SVS information or OME-XML metadata embedded in ImageDescription. TIFFToDicom evolves over time and between collection releases, as new features are encountered that must be supported.

One DICOM file is produced per channel and pyramid layer - e.g., an SVS file with 4 layers will produce 4 output files, plus an OVERVIEW (macro) image, if present, in the same DICOM Series. The single frame apex of the pyramid will be treated as a  THUMBNAIL image type and is decompressed. If an LZW compressed LABEL image is present, it will also be decompressed and converted. See also the [DICOM description of ImageType for WSI](http://dicom.nema.org/medical/dicom/current/output/chtml/part03/sect_C.8.12.4.html#sect_C.8.12.4.1.1). A 10 channel OME-TIFF IF file with 6 layers of pyramid per channel (in SubIFDs) will produce 60 output files (in the same DICOM Series).

Even though the converted DICOM files are dual-personality TIFF, and can be read by non-DICOM-aware TIFF tools, each converted DICOM file contains only one layer, and hence will not work with tools that expect all the layers to be combined in one file (i.e., lower resolution layers of the pyramid are not synthesized for each file, nor are lower resolution layers copied from the SVS or TIFF input file).

The JSON metadata file is of the form described for [com.pixelmed.apps.SetCharacteristicsFromSummary](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/apps/SetCharacteristicsFromSummary.html "com.pixelmed.apps.SetCharacteristicsFromSummary").

For most collections, the DICOM StudyDescription is populated with a fixed value ("Histopathology") and the SeriesDescription with a copy of the SpecimenShortDescription, since these attributes are commonly used in generic DICOM browsers and databases.

For most collections the SVS TIFF ImageDescription tag value for the first IFD is copied into the DICOM ImageComments attribute of all the converted DICOM images (not just the base layer image), since it may contain useful information that has not been extracted into specific DICOM attributes.

Information specific to the collection is included in the DICOM Clinical Trials attributes, including ClinicalTrialSponsorName, ClinicalTrialProtocolID, ClinicalTrialProtocolName, ClinicalTrialSiteID, ClinicalTrialSiteName and ClinicalTrialSubjectID. In addition, the TCIA (CTP) private data element (0013,xx10,"CTP") is filled with the same value as ClinicalTrialProtocolID, for consistency with the radiology images for the same collections obtained from TCIA.

The DICOM ContainerIdentifier attribute is filled with the identifier of the slide, and the SpecimenDescriptionSequence is populated with what information is known about the specimen that is on the slide, or parent specimens from which it is derived, as well as items of SpecimenPreparationSequence when such information is available (including fixation, embedding and staining) and are recorded as per [DICOM TID 8001 Specimen Preparation](http://dicom.nema.org/medical/dicom/current/output/chtml/part16/chapter_C.html#sect_TID_8001), extended as is necessary per draft [DICOM CP 2082](http://www.dclunie.com/dicom-status/status.html#CP2082).

# Examples

The following invocation of the TCGA-specific script gdcsvstodcm.sh will convert all the SVS files for the specified collection, storing them by default in a directory "Converted" (which may be overridden on the command line), recording a log of the conversion into the specified log file. Note that the default logging level is "debug" so a considerable amount of information is written to the log file.

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

No out of band metadata was used, since the supplied SVS file name contain embedded within them the so-called ["barcode information"](http://docs.gdc.cancer.gov/Encyclopedia/pages/TCGA_Barcode/), which describe in detail the source site, participant, sample, vial, portion, analyte and slide identifier. The slide identifier includes information about whether the specimen is frozen or FFPE. The hierarchical specimen identifiers are described in successive items of the SpecimenPreparationSequence, fed to com.pixelmed.convert.TIFFToDicom via the JSON metadata. For example (as described by the "dccidump" utility):

		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01"
			CODE: (434711009,SCT,"Specimen container")  = (434711009,SCT,"Specimen container")
			CODE: (371439000,SCT,"Specimen type")  = (119376003,SCT,"Tissue specimen")
			CODE: (111701,DCM,"Processing type")  = (17636008,SCT,"Specimen Collection")
			CODE: (17636008,SCT,"Specimen Collection")  = (118292001,SCT,"Removal")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01Z"
			CODE: (434711009,SCT,"Specimen container")  = (434746001,SCT,"Specimen vial")
			CODE: (371439000,SCT,"Specimen type")  = (119376003,SCT,"Tissue specimen")
			CODE: (111701,DCM,"Processing type")  = (433465004,SCT,"Specimen Sampling")
			CODE: (111704,DCM,"Sampling Method")  = (433465004,SCT,"Sampling of tissue specimen")
			TEXT: (111705,DCM,"Parent Specimen Identifier")  = "TCGA-YZ-A985-01"
			CODE: (111707,DCM,"Parent specimen type")  = (119376003,SCT,"Tissue specimen")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01Z-00"
			CODE: (111701,DCM,"Processing type")  = (433465004,SCT,"Specimen Sampling")
			CODE: (434711009,SCT,"Specimen container")  = (434464009,SCT,"Tissue cassette")
			CODE: (371439000,SCT,"Specimen type")  = (430861001,SCT,"Gross specimen")
			CODE: (111704,DCM,"Sampling Method")  = (433465004,SCT,"Sampling of tissue specimen")
			TEXT: (111705,DCM,"Parent Specimen Identifier")  = "TCGA-YZ-A985-01Z"
			CODE: (111707,DCM,"Parent specimen type")  = (119376003,SCT,"Tissue specimen")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01Z-00-DX1"
			CODE: (434711009,SCT,"Specimen container")  = (433466003,SCT,"Microscope slide")
			CODE: (371439000,SCT,"Specimen type")  = (1179252003,SCT,"Slide")
			CODE: (111701,DCM,"Processing type")  = (433465004,SCT,"Specimen Sampling")
			CODE: (111704,DCM,"Sampling Method")  = (434472006,SCT,"Block sectioning")
			TEXT: (111705,DCM,"Parent Specimen Identifier")  = "TCGA-YZ-A985-01Z-00"
			CODE: (111707,DCM,"Parent specimen type")  = (430861001,SCT,"Gross specimen")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01Z-00"
			CODE: (111701,DCM,"Processing type")  = (9265001,SCT,"Specimen processing")
			CODE: (430864009,SCT,"Tissue Fixative")  = (431510009,SCT,"Formalin")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01Z-00"
			CODE: (111701,DCM,"Processing type")  = (9265001,SCT,"Specimen processing")
			CODE: (430863003,SCT,"Embedding medium")  = (311731000,SCT,"Paraffin wax")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "TCGA-YZ-A985-01Z-00-DX1"
			CODE: (111701,DCM,"Processing type")  = (127790008,SCT,"Staining")
			CODE: (424361007,SCT,"Using substance")  = (12710003,SCT,"hematoxylin stain")
			CODE: (424361007,SCT,"Using substance")  = (36879007,SCT,"water soluble eosin stain")

The project name is NOT in the file name, so is obtained from the folder name in which the source files are contained. This project name is encoded not only in the ClinicalTrialProtocolName as well as the TCIA (CTP) private data element (0013,xx10,"CTP"), but is also used to determine the anatomy for PrimaryAnatomicStructureSequence, since each TCGA collection is anatomically-specific.

The tissue type is also defined in the barcode-based filename, so whether or not it was normal tissue adjacent to the tumor, or tumor tissue, is added as a modifier (PrimaryAnatomicStructureModifierSequence) to the PrimaryAnatomicStructureSequence.

## CPTAC
The CPTAC images were obtained from TCIA in a single Aspera Faspex package that was supplied on request, using the [command line utility supplied by IBM](http://ak-delivery04-mul.dhe.ibm.com/sar/CMA/OSA/08q6g/0/ibm-aspera-cli-3.9.6.1467.159c5b1-linux-64-release.sh).

For CPTAC SVS images, the ["cptacsvstodcm.sh"](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/cptacsvstodcm.sh) script performs the conversion.

CPTAC collections are of two generations CPTAC-2 and CPTAC-3, which have slightly different naming and metadata conventions that need to be addressed during conversion.

The metadata was obtained in JSON form from the [ESAC portal](https://clinicalapi-cptac.esacinc.com/api/pancancer/), which is supposedly no longer in service, but since these collections are no longer being updated, alternative sources have not been considered, and an [archived copy is provided here](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/MetadataFromTCIAJSONAPIDownload.zip). E.g., for the CPTAC-3 collections:

[https://clinicalapi-cptac.esacinc.com/api/pancancer/clinical_data/tumor_code/GBM](https://clinicalapi-cptac.esacinc.com/api/pancancer/clinical_data/tumor_code/GBM)

and the CPTAC-2 collections, for which the two letter BR, CO, OV or was used (for BRCA, COAD or OV):

[https://clinicalapi-cptac.esacinc.com/api/pancancer/clinical_data/tumor_code/BR](https://clinicalapi-cptac.esacinc.com/api/pancancer/clinical_data/tumor_code/BR)

In theory, CPTAC metadata is available from the PDC portal, but this has not proven helpful so far. The metadata used (if available) includes the specimen_id, case_id (DICOM Patient ID), gender, age, height, weight, race, and tissue_type (normal or tumor). Unfortunately, whether the tissue was frozen or FFPE is not available in the ESAC metadata. Also, the metadata is not available for a relatively high proportion of the images, in which case the slide_id and case_id were derived from the source file name and a dummy specimen_id was created from the slide_id. The tumor_site is not used to determine the anatomy, which is derived instead from the collection, but it is recorded in the specimen description. The ESAC portal JSON metadata was first converted to CSV form for use by the "cptacsvstodcm.sh" script using ["CPTACJSONAPIClinicalData.java"](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main//CPTACJSONAPIClinicalData.java).




## HTAN
The HTAN pathology images were shared by the HTAN DCC, exported to a Google Bucket from the source Sage Synpase platform. Each "atlas" (one per submitting site) contains images of various types including reference brightfield conventionally stained images, variously supplied as SVS or OME-TIFF, and multichannel images where each grayscale channel represents some fluorescent antibody or similar. 

A single metadata spreadsheet in CSV form supplied by HTAN DCC listed the file names, the parent specimen ID (from which the subject participant ID could be extracted) as well as other metadata that was used during the conversion, such as the assay type (e.g., 'H&E'), and information about the pixel size (x,y and z), if present, which is not always available from the TIFF or SVS file headers).

The non-SVS TIFF images had been decompressed from the original form (whether lossy compressed or not) and were losslessly compressed using LZW. The converted images were generally left uncompressed, unless the pixel data of each single layer per channel was too large to be encoded within a limit that the Google Healthcare API enforced (2GB, which is less than the uncompressed DICOM file pixel data size limit of approximately 4GB), in which case reversible (lossless) JPEG 2000 was used, since that is the only lossless compression scheme supported by commonly used TIFF tools (even though it is a proprietary Aperio TIFF extension).

The non-SVS TIFF images were usually but not always tiled pyramids. When not tiled, the conversion process re-tiled them (using libtiff tiffcp) before conversion (e.g., Vanderbilt H&E images) unless the image was already quite small (e.g., WUSTL IMC).

In addition to the primary metadata spreadsheet, additional information about each subject ("demographics") and "biospecimen" was obtained from the [public HTAN portal](http://humantumoratlas.org/explore?tab=atlas) and used to obtain gender, race and vital status (alive or dead), biopsy site, acquisition method, timepoint, and tissue type information to populate the DICOM header. Coded content such as vital status is encoded in AcquisitionContextSequence, e.g.:

	CODE: (11323-3,LN,"Health status")  = (438949009,SCT,"Alive")

For multichannel images, additional channel-specific metadata was provided by the HTAN DCC in the form of a CSV spreadsheet linking image file names to channel metadata CSV files. The content of the channel metadata CSV files is submitting site specific, and in some cases provided no additional information beyond a short text "channel name" and in others provided detailed information about antibodies (including RRID codes), fluorophores and wavelengths. The PixelMed conversion tool was extended with a [class](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/Immunostaining.html) to process this information and encode it in coded or text form in items of the SpecimenPreparationSequence and the OpticalPathSequence. The CHANNELFILE [command line argument](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/TIFFToDicom.html#main-java.lang.String:A-) is used to pass this information to the conversion class. When no out-of-band channel information was available, the conversion tool defaults to using whatever channel name is present in the OME-XML description in the OME-TIFF ImageDescription tag. An example of the channel information for one channel follows:

		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "HTA7_972_2"
			CODE: (111701,DCM,"Processing type")  = (17636008,SCT,"Specimen Collection")
			CODE: (17636008,SCT,"Specimen Collection")  = (65801008,SCT,"Resection")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "HTA7_972_1000"
			CODE: (434711009,SCT,"Specimen container")  = (433466003,SCT,"Microscope slide")
			CODE: (371439000,SCT,"Specimen type")  = (1179252003,SCT,"Slide")
			CODE: (111701,DCM,"Processing type")  = (433465004,SCT,"Specimen Sampling")
			CODE: (111704,DCM,"Sampling Method")  = (434472006,SCT,"Block sectioning")
			TEXT: (111705,DCM,"Parent Specimen Identifier")  = "HTA7_972_2"
			CODE: (111707,DCM,"Parent specimen type")  = (430861001,SCT,"Gross specimen")
		Specimen Preparation Step Content Item Sequence
			TEXT: (121041,DCM,"Specimen Identifier")  = "HTA7_972_1000"
			CODE: (111701,DCM,"Processing type")  = (127790008,SCT,"Staining")
			TEXT: (C44170,NCIt,"Channel")  = "14"
			TEXT: (C25472,NCIt,"Cycle")  = "4"
			CODE: (246094008,SCT,"Component investigated")  = (19677004,SCT,"CD45")
			TEXT: (246094008,SCT,"Component investigated")  = "CD45"
			CODE: (C2480,NCIt,"Tracer")  = (C0598447,UMLS,"Fluorophore")
			CODE: (C0598447,UMLS,"Using Fluorophore")  = (34101007,SCT,"Phycoerythrin")
			TEXT: (C0598447,UMLS,"Using Fluorophore")  = "PE"
			CODE: (424361007,SCT,"Using substance")  = (AB_2562057,RRID,"PE anti-human CD45")
			CODE: (703857004,SCT,"Staining Technique")  = (406858009,SCT,"Fluorescent staining")
			TEXT: (C37925,NCIt,"Clone")  = "HI30"
			TEXT: (C0947322,UMLS,"Manufacturer Name")  = "BioLegend"
			TEXT: (111529,DCM,"Brand Name")  = "304039"
			TEXT: (C4281604,UMLS,"Dilution")  = "1:100"

The corresponding [Optical Path information](https://dicom.nema.org/medical/dicom/current/output/chtml/part03/sect_C.8.12.5.html) for the channel is stored in the OpticalPathSequence, e.g.:

    (0x0048,0x0105) SQ Optical Path Sequence 	 VR=<SQ>   VL=<0xffffffff>  
    > (0x0022,0x0001) US Light Path Filter Pass-Through Wavelength 	 VR=<US>   VL=<0x0002>  [0x024e] 
    > (0x0022,0x0016) SQ Illumination Type Code Sequence 	 VR=<SQ>   VL=<0xffffffff>  
        >> (0x0008,0x0100) SH Code Value 	 VR=<SH>   VL=<0x0006>  <111743> 
        >> (0x0008,0x0102) SH Coding Scheme Designator 	 VR=<SH>   VL=<0x0004>  <DCM > 
        >> (0x0008,0x0104) LO Code Meaning 	 VR=<LO>   VL=<0x001c>  <Epifluorescence illumination> 
    > (0x0022,0x0055) FL Illumination Wave Length 	 VR=<FL>   VL=<0x0004>  {555} 
    > (0x0048,0x0106) SH Optical Path Identifier 	 VR=<SH>   VL=<0x0002>  <14> 
    > (0x0048,0x0107) ST Optical Path Description 	 VR=<ST>   VL=<0x0004>  <CD45> 
    > (0x0048,0x0108) SQ Illumination Color Code Sequence 	 VR=<SQ>   VL=<0xffffffff>  
        >> (0x0008,0x0100) SH Code Value 	 VR=<SH>   VL=<0x000a>  <134223000 > 
        >> (0x0008,0x0102) SH Coding Scheme Designator 	 VR=<SH>   VL=<0x0004>  <SCT > 
        >> (0x0008,0x0104) LO Code Meaning 	 VR=<LO>   VL=<0x0006>  <Narrow> 
    > (0x0048,0x0112) DS Objective Lens Power 	 VR=<DS>   VL=<0x0002>  <20> 
    > (0x0048,0x0113) DS Objective Lens Numerical Aperture 	 VR=<DS>   VL=<0x0004>  <075 > 

Note the common value for the OpticalPathIdentifier in the OpticalPathSequence, and the (C44170,NCIt,"Channel") value in the SpecimenPreparationStepContentItem Sequence, as described in [DICOM CP 2082](http://www.dclunie.com/dicom-status/status.html#CP2082), relating what was done to the specimen with how the image of the slide was acquired.

For this collection, the DICOM ImageComments attribute is not populated with the SVS TIFF or OME-TIFF-XML ImageDescription tag, since its value may not be consistent with the single extracted channel files.

# Reconversion

Several collections (NLST, TCGA, CPTAC) have been reconverted, primarily to address the need to add empty JPEG tiles when illegal zero-length tiles are present in the source (a recognized Leica/Aperio defect); this was manifesting as omitted rather than blank tiles causing zooming and panning to be out of sync. During the course of the reconversion, several other changes were incorporated:
- StudyDescription and SeriesDescription were populated
- AcquisitionUID and PyramidUID are generated
- private data elements recording the source file name (0009,xx01,"PixelMed Publishing") and IFD (0009,xx02,"PixelMed Publishing") were included
- set PositionReferenceIndicator to UNKNOWN not SLIDE_CORNER when no macro (overview) since ImageDescription Left and Top need macro info to interpret
- manufacturer information may be more specific
- date and time information may be more specific
- when not included previously, ClinicalTrialSubjectID has been added
- label images, if present, have been extracted

# Software Dependencies

[pixelmed.jar](http://www.dclunie.com/pixelmed/software/index.html) - used to perform the actual conversion.

[dicom3tools](http://www.dclunie.com/dicom3tools/workinprogress/index.html) - used by script for extracting summary of converted files and verifying their compliance (compiling requires apt-get install g++ make xutils-dev).

[libtiff](http://www.libtiff.org/) - used by script for extracting TIFF-specific tag information for decisions about how to perform conversion and tiling of untiled images (`apt-get install libtiff-tools`).

[bc](http://www.gnu.org/software/bc/) - used for calculations in the scripts (`apt-get install bc`).

[JAI JIIO codecs](http://download.java.net/media/jai-imageio/builds/release/1.1/INSTALL-jai_imageio.html) - JAI JIIO codecs for image compression and decompression - [jai_imageio.jar from jai_imageio-1_1](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/jai_imageio.jar) was used

[javax.json](http://www.java2s.com/ref/jar/download-javaxjson104jar-file.html) - used for reading JSON files from Java - [javax.json-1.0.4.jar](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/javax.json-1.0.4.jar) was used

[opencsv](http://opencsv.sourceforge.net/) - used for reading CSV files from Java - [opencsv-2.4.jar](http://github.com/ImagingDataCommons/idc-wsi-conversion/blob/main/opencsv-2.4.jar) was used

Java - pixelmed.jar has not been tested on versions beyond Java 8, so openjdk version "1.8.0_322" was used, especially when the JAI JIIO codecs were needed for JPEG 2000 compression, but later versions, including "default-jdk", may work.


