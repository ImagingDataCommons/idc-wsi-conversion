#!/bin/sh
#
# Usage: ./nlstsvstodcm.sh nlstfolder/participantid/filename.svs [outdir]

infile="$1"
outdir="$2"

metadatacsvdir="NLSTMetadataCSV"

TMPJSONFILE="/tmp/`basename $0`.$$"

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="NLSTspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="NLSTstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="NLSTstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="tabulateduids.csv"
TMPSLIDEUIDFILE="slideuid.csv"

#JHOVE="${HOME}/work/jhove/jhove"

PIXELMEDDIR="${HOME}/work/pixelmed/imgbook"
PATHTOADDITIONAL="${PIXELMEDDIR}/lib/additional"

# "pathology-NLST_1225files/117492/9718.svs"

filename=`basename "${infile}" '.svs'`
foldername=`dirname "${infile}"`

# case_id is what NLST metadata calls pid (participant id)
case_id=`basename "${foldername}"`

slide_id="${case_id}_${filename}"
echo "slide_id = ${slide_id}"

if [ -z "${outdir}" ]
then
	outdir="Converted/NLST/${slide_id}"
fi

csvfilename="nlst_780_prsn_idc_20210527.csv"

#echo "csvfilename = ${csvfilename}"
if [ -f "${csvfilename}" ]
then
	csvlineforslide=`egrep ",${case_id}," "${csvfilename}" | head -1`
fi

#race,cigsmok,gender,age,loclhil,locllow,loclup,locrhil,locrlow,locrmid,locunk,locrup,locoth,locmed,loclmsb,locrmsb,loccar,loclin,lesionsize,de_type,de_grade,de_stag,scr_res0,scr_res1,scr_res2,scr_iso0,scr_iso1,scr_iso2,cancyr,can_scr,canc_rpt_link,pid,dataset_version,scr_days0,scr_days1,scr_days2,candx_days,canc_free_days,de_stag_7thed
race=`echo "${csvlineforslide}" | awk -F, '{print $1}'`
cigsmok=`echo "${csvlineforslide}" | awk -F, '{print $2}'`
gender=`echo "${csvlineforslide}" | awk -F, '{print $3}'`
# is actually age at randomization, not biopsy, but use anyway :(
age=`echo "${csvlineforslide}" | awk -F, '{print $4}'`

specimen_id="${slide_id}"

fixation="FFPE"	# assume ... not in available metadata

echo "infile = ${infile}"
echo "filename = ${filename}"
echo "slide_id = ${slide_id}"
echo "specimen_id = ${specimen_id}"
echo "case_id = ${case_id}"
echo "fixation = ${fixation}"
echo "race = ${race}"
echo "cigsmok = ${cigsmok}"
echo "gender = ${gender}"
echo "age = ${age}"

slidefilenameforuid="${case_id}/${filename}"
echo "slidefilenameforuid = ${slidefilenameforuid}"

echo "TMPSLIDEUIDFILE = ${TMPSLIDEUIDFILE}"
rm -f "${TMPSLIDEUIDFILE}"
uidarg=""
if [ -f  "${UIDMAPPINGFILE}" ]
then
	egrep "(Filename|${slidefilenameforuid})" "${UIDMAPPINGFILE}" > "${TMPSLIDEUIDFILE}"
	uidarg="UIDFILE ${TMPSLIDEUIDFILE}"
fi
echo "uidarg = ${uidarg}"

# NLST pattern for radiology has different value for PatientName and Clinical Trial Subject ID than PatientID - do not have this so leave it blank
dicompatientid="${case_id}"
dicompatientname=""
dicomspecimenidentifier="${specimen_id}"

dicomstudyid="${case_id}"
dicomaccessionnumber="${case_id}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

dicomclinicaltrialsponsorname="National Cancer Institute"
dicomclinicalprotocolid="NCT00047385"
dicomclinicalprotocolname="NLST-LSS"
dicomctpprojectname="NLST"

dicomclinicaltrialsubjectid="${dicompatientid}"

anatomycodevalue="39607008"
anatomycsd="SCT"
anatomycodemeaning="Lung"

dicomspecimenuid=""
if [ ! -f "${FILEMAPPINGSPECIMENIDTOUID}" ]
then
	touch "${FILEMAPPINGSPECIMENIDTOUID}"
fi

if [ ! -z "${dicomspecimenidentifier}" ]
then
	# dicomspecimenidentifier may be prefix for other identifiers, so assure bounded by delimiters, and use first if duplicates else fails later
	dicomspecimenuid=`egrep "^${dicomspecimenidentifier}," "${FILEMAPPINGSPECIMENIDTOUID}" | awk -F, '{print $2}' | head -1`
	if [ -z "${dicomspecimenuid}" ]
	then
		dicomspecimenuid=`java -cp ${PIXELMEDDIR}/pixelmed.jar -Djava.awt.headless=true com.pixelmed.utils.UUIDBasedOID 2>&1`
		echo "${dicomspecimenidentifier},${dicomspecimenuid}" >>"${FILEMAPPINGSPECIMENIDTOUID}"
		echo "Created Specimen UID ${dicomspecimenuid} for Specimen ID ${dicomspecimenidentifier}"
	else
		echo "Reusing Specimen UID ${dicomspecimenuid} for Specimen ID ${dicomspecimenidentifier}"
	fi
fi
# dicomspecimenuid may still be unassigned if there is no dicomspecimenidentifier - let Java code fill in new one

dicomstudyuid=""
if [ ! -f "${FILEMAPPINGSTUDYIDTOUID}" ]
then
	touch "${FILEMAPPINGSTUDYIDTOUID}"
fi

if [ ! -z "${dicomstudyid}" ]
then
	# dicomstudyid may be prefix for other identifiers, so assure bounded by delimiters, and use first if duplicates else fails later
	dicomstudyuid=`egrep "^${dicomstudyid}," "${FILEMAPPINGSTUDYIDTOUID}" | awk -F, '{print $2}' | head -1`
	if [ -z "${dicomstudyuid}" ]
	then
		dicomstudyuid=`java -cp ${PIXELMEDDIR}/pixelmed.jar -Djava.awt.headless=true com.pixelmed.utils.UUIDBasedOID 2>&1`
		echo "${dicomstudyid},${dicomstudyuid}" >>"${FILEMAPPINGSTUDYIDTOUID}"
		echo "Created Study UID ${dicomstudyuid} for Study ID ${dicomstudyid}"
	else
		echo "Reusing Study UID ${dicomstudyuid} for Study ID ${dicomstudyid}"
	fi
fi
# dicomstudyuid may still be unassigned if there is no dicomstudyid - let Java code fill in new one

svsdatetime=`tiffinfo "${infile}" | grep Date | grep Time | head -1 | sed -e 's/^.*Date = \([0-9][0-9]\)[/]\([0-9][0-9]\)[/]\([0-9][0-9]\).*Time = \([0-9][0-9]\)[:]\([0-9][0-9]\)[:]\([0-9][0-9]\).*$/20\3\1\2\4\5\6/'`
echo "svsdatetime = ${svsdatetime}"

# ideally we would pick the earliest study date time, but that would require multiple passes, so just record the 1st encountered and make all the same to satisfy information model (dcentvfy)
dicomstudydatetime=""
if [ ! -f "${FILEMAPPINGSTUDYIDTODATETIME}" ]
then
	touch "${FILEMAPPINGSTUDYIDTODATETIME}"
fi

if [ ! -z "${dicomstudyid}" ]
then
	# should only be zero or one, but head -1 just in case
	dicomstudydatetime=`grep "${dicomstudyid}" "${FILEMAPPINGSTUDYIDTODATETIME}" | head -1 | awk -F, '{print $2}'`
	if [ -z "${dicomstudydatetime}" ]
	then
		dicomstudydatetime="${svsdatetime}"
		echo "${dicomstudyid},${dicomstudydatetime}" >>"${FILEMAPPINGSTUDYIDTODATETIME}"
		echo "Created Study Date Time ${dicomstudydatetime} for Study ID ${dicomstudyid}"
	else
		echo "Reusing Study Date Time ${dicomstudydatetime} for Study ID ${dicomstudyid}"
	fi
fi
# dicomstudydatetime may still be unassigned if there is no dicomstudyid, or if not found in SVS header - let Java code fill in one based on SVS files ImageDescription
dicomstudydate=""
dicomstudytime=""
if [ ! -z "${dicomstudydatetime}" ]
then
	dicomstudydate=`echo "${dicomstudydatetime}" | sed -e 's/^\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\).*$/\1/'`
	dicomstudytime=`echo "${dicomstudydatetime}" | sed -e 's/^.*\([0-9][0-9][0-9][0-9][0-9][0-9]\)$/\1/'`
fi

dicomstudydescription="Histopathology"

echo "dicompatientname = ${dicompatientname}"
echo "dicompatientid = ${dicompatientid}"
echo "dicomstudyid = ${dicomstudyid}"
echo "dicomstudyuid = ${dicomstudyuid}"
echo "dicomstudydatetime = ${dicomstudydatetime}"
echo "dicomstudydate = ${dicomstudydate}"
echo "dicomstudytime = ${dicomstudytime}"
echo "dicomstudydescription = ${dicomstudydescription}"
echo "dicomaccessionnumber = ${dicomaccessionnumber}"
echo "dicomspecimenidentifier = ${dicomspecimenidentifier}"
echo "dicomspecimenuid = ${dicomspecimenuid}"
echo "dicomcontaineridentifier = ${dicomcontaineridentifier}"

echo "dicomclinicaltrialsponsorname = ${dicomclinicaltrialsponsorname}"
echo "dicomclinicalprotocolid = ${dicomclinicalprotocolid}"
echo "dicomclinicalprotocolname = ${dicomclinicalprotocolname}"
echo "dicomctpprojectname = ${dicomctpprojectname}"
echo "dicomclinicaltrialsiteid = ${dicomclinicaltrialsiteid}"
echo "dicomclinicaltrialsitename = ${dicomclinicaltrialsitename}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

echo "anatomycodevalue = ${anatomycodevalue}"
echo "anatomycsd = ${anatomycsd}"
echo "anatomycodemeaning = ${anatomycodemeaning}"

dicomsex=""
if [ "${gender}" = "1" ]
then
	dicomsex="M"
elif [ "${gender}" = "2" ]
then
	dicomsex="F"
fi
echo "dicomsex = ${dicomsex}"

dicomage=""
if [ ! -z "${age}" ]
then
	if [ ${age} -ge 100 ]
	then
		dicomage="${age}Y"
	elif [ ${age} -ge 10 ]
	then
		dicomage="0${age}Y"
	fi
fi
echo "dicomage = ${dicomage}"

dicomethnicgroup=""
if [ "${race}" = "1" ]
then
	dicomethnicgroup="White"
elif [ "${race}" = "2" ]
then
	dicomethnicgroup="Black or African"
elif [ "${race}" = "3" ]
then
	dicomethnicgroup="Asian"
elif [ "${race}" = "4" ]
then
	dicomethnicgroup="American Indian"
elif [ "${race}" = "5" ]
then
	dicomethnicgroup="Native Hawaiian"
elif [ "${race}" = "6" ]
then
	dicomethnicgroup="More than one"
fi
echo "dicomethnicgroup = ${dicomethnicgroup}"

smokingstatuscodevalue=""
if [ "${cigsmok}" = "0" ]
then
	smokingstatuscodevalue="8517006"
	smokingstatuscsd="SCT"
	smokingstatuscodemeaning="Former Smoker"
elif [ "${cigsmok}" = "1" ]
then
	smokingstatuscodevalue="77176002"
	smokingstatuscsd="SCT"
	smokingstatuscodemeaning="Current Smoker"
fi
echo "smokingstatuscodemeaning = ${smokingstatuscodemeaning}"

dicomspecimenshortdescription="FFPE HE"
echo "dicomspecimenshortdescription = ${dicomspecimenshortdescription}"

dicomspecimendetaileddescription=""
echo "dicomspecimendetaileddescription = ${dicomspecimendetaileddescription}"

dicomseriesdescription="${dicomspecimenshortdescription}"
echo "dicomseriesdescription = ${dicomseriesdescription}"

echo  >"${TMPJSONFILE}" "{"
echo >>"${TMPJSONFILE}" "	\"options\" : {"
echo >>"${TMPJSONFILE}" "		\"AppendToContributingEquipmentSequence\" : false"
echo >>"${TMPJSONFILE}" "	},"
echo >>"${TMPJSONFILE}" "	\"top\" : {"
echo >>"${TMPJSONFILE}" "		\"PatientName\" : \"${dicompatientname}\","
echo >>"${TMPJSONFILE}" "		\"PatientID\" : \"${dicompatientid}\","
if [ ! -z "${dicomsex}" ]
then
	echo >>"${TMPJSONFILE}" "	\"PatientSex\" : \"${dicomsex}\","
fi
if [ ! -z "${dicomage}" ]
then
	echo >>"${TMPJSONFILE}" "	\"PatientAge\" : \"${dicomage}\","
fi
if [ ! -z "${dicomsize}" ]
then
	echo >>"${TMPJSONFILE}" "	\"PatientSize\" : \"${dicomsize}\","
fi
if [ ! -z "${dicomweight}" ]
then
	echo >>"${TMPJSONFILE}" "	\"PatientWeight\" : \"${dicomweight}\","
fi
if [ ! -z "${dicomethnicgroup}" ]
then
	echo >>"${TMPJSONFILE}" "	\"EthnicGroup\" : \"${dicomethnicgroup}\","
fi
echo >>"${TMPJSONFILE}" "		\"StudyID\" : \"${dicomstudyid}\","
echo >>"${TMPJSONFILE}" "		\"StudyInstanceUID\" : \"${dicomstudyuid}\","
if [ ! -z "${dicomstudydate}" ]
then
	echo >>"${TMPJSONFILE}" "		\"StudyDate\" : \"${dicomstudydate}\","
fi
if [ ! -z "${dicomstudytime}" ]
then
	echo >>"${TMPJSONFILE}" "		\"StudyTime\" : \"${dicomstudytime}\","
fi
echo >>"${TMPJSONFILE}" "		\"StudyDescription\" : \"${dicomstudydescription}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSponsorName\" : \"${dicomclinicaltrialsponsorname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolID\" : \"${dicomclinicalprotocolid}\","
echo >>"${TMPJSONFILE}" "		\"00130010\" : \"CTP\","
echo >>"${TMPJSONFILE}" "		\"00131010\" : \"${dicomctpprojectname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolName\" : \"${dicomclinicalprotocolname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteID\" : \"${dicomclinicaltrialsiteid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteName\" : \"${dicomclinicaltrialsitename}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSubjectID\" : \"${dicomclinicaltrialsubjectid}\","
echo >>"${TMPJSONFILE}" "		\"AcquisitionContextSequence\" : ["
if [ ! -z "${smokingstatuscodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	      {"
	echo >>"${TMPJSONFILE}" "		    \"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "			\"ConceptNameCodeSequence\" : { \"cv\" : \"365981007\", \"csd\" : \"SCT\", \"cm\" : \"Tobacco Smoking Behavior\" },"
	echo >>"${TMPJSONFILE}" "			\"ConceptCodeSequence\" :     { \"cv\" : \"${smokingstatuscodevalue}\", \"csd\" : \"${smokingstatuscsd}\", \"cm\" : \"${smokingstatuscodemeaning}\" }"
	echo >>"${TMPJSONFILE}" "	      }"
fi
echo >>"${TMPJSONFILE}" "		],"
echo >>"${TMPJSONFILE}" "		\"SeriesNumber\" : \"1\","
echo >>"${TMPJSONFILE}" "		\"SeriesDescription\" : \"${dicomseriesdescription}\","
echo >>"${TMPJSONFILE}" "		\"AccessionNumber\" : \"${dicomaccessionnumber}\","
echo >>"${TMPJSONFILE}" "		\"ContainerIdentifier\" : \"${dicomcontaineridentifier}\","
echo >>"${TMPJSONFILE}" "		\"IssuerOfTheContainerIdentifierSequence\" : [],"
echo >>"${TMPJSONFILE}" "		\"ContainerTypeCodeSequence\" : { \"cv\" : \"433466003\", \"csd\" : \"SCT\", \"cm\" : \"Microscope slide\" },"
echo >>"${TMPJSONFILE}" "		\"SpecimenDescriptionSequence\" : ["
echo >>"${TMPJSONFILE}" "	      {"
echo >>"${TMPJSONFILE}" "		    \"SpecimenIdentifier\" : \"${dicomspecimenidentifier}\","
echo >>"${TMPJSONFILE}" "		    \"IssuerOfTheSpecimenIdentifierSequence\" : [],"
echo >>"${TMPJSONFILE}" "		    \"SpecimenUID\" : \"${dicomspecimenuid}\","
if [ ! -z "${dicomspecimenshortdescription}" ]
then
	echo >>"${TMPJSONFILE}" "		\"SpecimenShortDescription\" : \"${dicomspecimenshortdescription}\","
fi
if [ ! -z "${dicomspecimendetaileddescription}" ]
then
	echo >>"${TMPJSONFILE}" "		\"SpecimenDetailedDescription\" : \"${dicomspecimendetaileddescription}\","
fi
echo >>"${TMPJSONFILE}" "		    \"SpecimenPreparationSequence\" : ["
if [ "${fixation}" = "FFPE" ]
then
	echo >>"${TMPJSONFILE}" "		     {"
	echo >>"${TMPJSONFILE}" "		      \"SpecimenPreparationStepContentItemSequence\" : ["
	echo >>"${TMPJSONFILE}" "			     {"
	echo >>"${TMPJSONFILE}" "			   		\"ValueType\" : \"TEXT\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"121041\", \"csd\" : \"DCM\", \"cm\" : \"Specimen Identifier\" },"
	echo >>"${TMPJSONFILE}" "			   		\"TextValue\" : \"${dicomspecimenidentifier}\""
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111701\", \"csd\" : \"DCM\", \"cm\" : \"Processing type\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"9265001\", \"csd\" : \"SCT\", \"cm\" : \"Specimen processing\" }"
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"430864009\", \"csd\" : \"SCT\", \"cm\" : \"Tissue Fixative\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"431510009\", \"csd\" : \"SCT\", \"cm\" : \"Formalin\" }"
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      },"
	echo >>"${TMPJSONFILE}" "		      {"
	echo >>"${TMPJSONFILE}" "			    \"SpecimenPreparationStepContentItemSequence\" : ["
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"TEXT\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"121041\", \"csd\" : \"DCM\", \"cm\" : \"Specimen Identifier\" },"
	echo >>"${TMPJSONFILE}" "		    		\"TextValue\" : \"${dicomspecimenidentifier}\""
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111701\", \"csd\" : \"DCM\", \"cm\" : \"Processing type\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"9265001\", \"csd\" : \"SCT\", \"cm\" : \"Specimen processing\" }"
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"430863003\", \"csd\" : \"SCT\", \"cm\" : \"Embedding medium\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"311731000\", \"csd\" : \"SCT\", \"cm\" : \"Paraffin wax\" }"
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      },"
fi
echo >>"${TMPJSONFILE}" "		      {"
echo >>"${TMPJSONFILE}" "			    \"SpecimenPreparationStepContentItemSequence\" : ["
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"TEXT\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"121041\", \"csd\" : \"DCM\", \"cm\" : \"Specimen Identifier\" },"
echo >>"${TMPJSONFILE}" "		    		\"TextValue\" : \"${dicomspecimenidentifier}\""
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111701\", \"csd\" : \"DCM\", \"cm\" : \"Processing type\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"127790008\", \"csd\" : \"SCT\", \"cm\" : \"Staining\" }"
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"12710003\", \"csd\" : \"SCT\", \"cm\" : \"hematoxylin stain\" }"
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"36879007\", \"csd\" : \"SCT\", \"cm\" : \"water soluble eosin stain\" }"
echo >>"${TMPJSONFILE}" "			      }"
echo >>"${TMPJSONFILE}" "			    ]"
echo >>"${TMPJSONFILE}" "		      }"
if [ ! -z "${anatomycodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	    ],"
	echo >>"${TMPJSONFILE}" "	    \"PrimaryAnatomicStructureSequence\" : { \"cv\" : \"${anatomycodevalue}\", \"csd\" : \"${anatomycsd}\", \"cm\" : \"${anatomycodemeaning}\" }"
else
	echo >>"${TMPJSONFILE}" "	    ]"
fi
echo >>"${TMPJSONFILE}" "	      }"
echo >>"${TMPJSONFILE}" "		],"
echo >>"${TMPJSONFILE}" "		\"OpticalPathSequence\" : ["
echo >>"${TMPJSONFILE}" "	      {"
echo >>"${TMPJSONFILE}" "		    \"OpticalPathIdentifier\" : \"1\","
echo >>"${TMPJSONFILE}" "		    \"IlluminationColorCodeSequence\" : { \"cv\" : \"414298005\", \"csd\" : \"SCT\", \"cm\" : \"Full Spectrum\" },"
echo >>"${TMPJSONFILE}" "		    \"IlluminationTypeCodeSequence\" :  { \"cv\" : \"111744\",  \"csd\" : \"DCM\", \"cm\" : \"Brightfield illumination\" }"
echo >>"${TMPJSONFILE}" "	      }"
echo >>"${TMPJSONFILE}" "		]"
echo >>"${TMPJSONFILE}" "	}"
echo >>"${TMPJSONFILE}" "}"

cat "${TMPJSONFILE}"

tiffinfo "${infile}"

rm -rf "${outdir}"
mkdir -p "${outdir}"
date
java -cp ${PIXELMEDDIR}/pixelmed.jar:${PATHTOADDITIONAL}/javax.json-1.0.4.jar:${PATHTOADDITIONAL}/opencsv-2.4.jar:${PATHTOADDITIONAL}/jai_imageio.jar \
	-Djava.awt.headless=true \
	-XX:-UseGCOverheadLimit \
	-Xmx8g \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.TIFFToDicom=debug \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.AddTIFFOrOffsetTables=info \
	com.pixelmed.convert.TIFFToDicom \
	"${TMPJSONFILE}" \
	"${infile}" \
	"${outdir}/DCM" \
	SM 1.2.840.10008.5.1.4.1.1.77.1.6 \
	ADDTIFF MERGESTRIPS DONOTADDDCMSUFFIX INCLUDEFILENAME \
	${uidarg}
date
rm "${TMPJSONFILE}"
rm -f "${TMPSLIDEUIDFILE}"
ls -l "${outdir}"

for i in ${outdir}/*
do
	dciodvfy -new -filename "$i" 2>&1 | egrep -v '(Retired Person Name form|Warning - Unrecognized defined term <THUMBNAIL>|Error - Value is zero for value 1 of attribute <Slice Thickness>|Error - Value is zero for value 1 of attribute <Imaged Volume Depth>)'
done

#for i in ${outdir}/*
#do
#	dcfile -filename "$i"
#done

# Not -decimal (which is nice for rows, cols) because fails to display FL and FD values at all ([bugs.dicom3tools] (000554)) :(
(cd "${outdir}"; dctable -describe -recurse -k TransferSyntaxUID -k FrameOfReferenceUID -k LossyImageCompression -k LossyImageCompressionMethod -k LossyImageCompressionRatio -k InstanceNumber -k ImageType -k FrameType -k PhotometricInterpretation -k NumberOfFrames -k Rows -k Columns -k ImagedVolumeWidth -k ImagedVolumeHeight -k ImagedVolumeDepth -k ImageOrientationSlide -k XOffsetInSlideCoordinateSystem -k YOffsetInSlideCoordinateSystem -k PixelSpacing -k ObjectiveLensPower -k PrimaryAnatomicStructureSequence -k PrimaryAnatomicStructureModifierSequence -k ClinicalTrialProtocolID DCM*)

#for i in ${outdir}/*
#do
#	echo "$i"
#	tiffinfo "$i"
#done

# TIFF validation by JHOVE - throws java.io.IOException: Unable to create temporary file
#for i in ${outdir}/*
#do
#	echo "$i"
#	"${JHOVE}" "$i"
#done

#baselayerfile=`find "${outdir}" -name '*.dcm' | sort | head -1`
#echo "Making pyramids from ${baselayerfile} ..."
#date
#java -cp ${PIXELMEDDIR}/pixelmed.jar:${PATHTOADDITIONAL}/jai_imageio.jar \
#	-Djava.awt.headless=true \
#	-XX:-UseGCOverheadLimit \
#	-Xmx8g \
#	com.pixelmed.apps.TiledPyramid \
#	"${baselayerfile}" \
#	"${outdir}"
#date

echo "dcentvfy ..."
dcentvfy ${outdir}/*

#will not add pyramid files (yet) if created since name not DCM*
(cd "${outdir}"; \
	java -cp ${PIXELMEDDIR}/pixelmed.jar -Djava.awt.headless=true com.pixelmed.dicom.DicomDirectory DICOMDIR DCM*; \
	#dciodvfy -new DICOMDIR 2>&1 | egrep -v '(Retired Person Name form|Warning - Attribute is not present in standard DICOM IOD|Warning - Dicom dataset contains attributes not present in standard DICOM IOD)'; \
	#dcdirdmp -v DICOMDIR \
)
