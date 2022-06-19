The WSI conversion process generates [dual-personality DICOM-TIFF](http://www.jpathinformatics.org/article.asp?issn=2153-3539;year=2019;volume=10;issue=1;spage=12;epage=12;aulast=Clunie;type=0) files from source files that are SVS, generic TIFF or OME-TIFF.

The process is driven by a Bourne Shell script, executed on a single input file at a time, and generates multiple DICOM files, one for each pyramid resolution layer (and channel, if multi-channel rather than RGB).

The shell script gathers metadata from collection-specific sources, prepares a JSON metadata file describing the rendition of the metadata in DICOM attributes, and feeds the JSON metadata file as well as the input image file to [com.pixelmed.convert.TIFFToDicom](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/convert/TIFFToDicom.html "com.pixelmed.convert.TIFFToDicom") from the [pixelmed toolkit](http://www.dclunie.com/pixelmed/software/index.html "pixelmed toolkit"), which performs the actual conversion.

The JSON metadata file is of the form described for [com.pixelmed.apps.SetCharacteristicsFromSummary](http://www.dclunie.com/pixelmed/software/javadoc/com/pixelmed/apps/SetCharacteristicsFromSummary.html "com.pixelmed.apps.SetCharacteristicsFromSummary").

