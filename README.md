# Overview

The WSI conversion process generates [dual-personality DICOM-TIFF](http://www.jpathinformatics.org/article.asp?issn=2153-3539;year=2019;volume=10;issue=1;spage=12;epage=12;aulast=Clunie;type=0) files from source files that are SVS, generic TIFF or OME-TIFF.

The process is driven by a Bourne Shell script, executed on a single input file at a time, and generates multiple DICOM files, one for each pyramid resolution layer (and channel, if multi-channel rather than RGB).

The shell script gathers metadata from collection-specific sources, prepares a JSON metadata file describing the rendition of the metadata in DICOM attributes, and feeds the JSON metadata file as well as the input image file to [com.pixelmed.convert.TIFFToDicom](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/TIFFToDicom.html "com.pixelmed.convert.TIFFToDicom") from the [pixelmed toolkit](http://www.dclunie.com/pixelmed/software/index.html "pixelmed toolkit"), which performs the actual conversion.

The JSON metadata file is of the form described for [com.pixelmed.apps.SetCharacteristicsFromSummary](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/apps/SetCharacteristicsFromSummary.html "com.pixelmed.apps.SetCharacteristicsFromSummary").

# Examples

The following invocation of the TCGA-specific script gdcsvstodcm.sh will convert all the SVS files for the specified collection, storing them by default in a diretory "Converted" (which may be overridden on the command line), recording a log of the conversion into the specified log file. Note that the default logging level is "debug" so a considerable amount of information is written to the log file.

`nohup find TCGA-KIRP -follow -name '*.svs' -exec ./gdcsvstodcm.sh '{}' ';' >TCGA-KIRP_gdcsvstodcm.log 2>&1 &`

# Software Dependencies

[pixelmed.jar](http://www.dclunie.com/pixelmed/software/index.html) - used to perform the actual conversion

[dicom3tools](http://www.dclunie.com/dicom3tools/workinprogress/index.html) - used by script for extracting summary of converted files and verifying their compliance

libtiff - used by script for extracting TIFF-specific tag information for decisions about how to perform conversion
