#!/bin/sh

for outdir in Converted/HTAN-V1-Feb-2022/HTAN/HTAN-Vanderbilt/*
do
	echo "Making pyramids for ${outdir}/DCM_0"
	java -cp ./pixelmed.jar:./jai_imageio.jar \
	-Djava.awt.headless=true \
	-XX:-UseGCOverheadLimit \
	-Xmx8g \
	com.pixelmed.apps.TiledPyramid \
	"${outdir}/DCM_0" \
	"${outdir}"

	count=1
	for i in ${outdir}/1*
	do
		echo "Moving $i to ${outdir}/DCM_${count}"
		java -cp ./pixelmed.jar:./jai_imageio.jar \
			-Djava.awt.headless=true \
			-XX:-UseGCOverheadLimit \
			-Xmx16g \
			com.pixelmed.convert.AddTIFFOrOffsetTables \
			"$i" \
			"${outdir}/DCM_${count}" \
			ADDTIFF USEBIGTIFF
		rm "$i"
		count=`expr ${count} + 1`
	done

	ls -l "${outdir}"

	for i in ${outdir}/DCM*
	do
		dciodvfy -new -filename "$i" 2>&1 | egrep -v '(Retired Person Name form|Warning - Unrecognized defined term <THUMBNAIL>|Error - Value is zero for value 1 of attribute <Slice Thickness>|Error - Value is zero for value 1 of attribute <Imaged Volume Depth>)'
	done

	# Not -decimal (which is nice for rows, cols) because fails to display FL and FD values at all ([bugs.dicom3tools] (000554)) :(
	(cd "${outdir}"; dctable -describe -recurse -k TransferSyntaxUID -k FrameOfReferenceUID -k LossyImageCompression -k LossyImageCompressionMethod -k LossyImageCompressionRatio -k InstanceNumber -k ImageType -k FrameType -k PhotometricInterpretation -k NumberOfFrames -k Rows -k Columns -k ImagedVolumeWidth -k ImagedVolumeHeight -k ImagedVolumeDepth -k ImageOrientationSlide -k XOffsetInSlideCoordinateSystem -k YOffsetInSlideCoordinateSystem -k PixelSpacing -k SliceThickness -k ObjectiveLensPower -k PrimaryAnatomicStructureSequence -k PrimaryAnatomicStructureModifierSequence -k ClinicalTrialProtocolID -k OpticalPathIdentifier -k OpticalPathDescription DCM*)

	echo "dcentvfy ..."
	dcentvfy ${outdir}/DCM*

	(cd "${outdir}"; \
		java -cp ${HOME}/pixelmed.jar \
			-Djava.awt.headless=true \
			com.pixelmed.dicom.DicomDirectory \
			DICOMDIR DCM*; \
		#dciodvfy -new DICOMDIR 2>&1 | egrep -v '(Retired Person Name form|Attribute is not present in standard DICOM IOD|Dicom dataset contains attributes not present in standard DICOM IOD)'; \
		#dcdirdmp -v DICOMDIR \
	)
done


