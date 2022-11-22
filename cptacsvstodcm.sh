#!/bin/sh
#
# Usage: ./cptacsvstodcm.sh projectdirname/filename.svs [outdir]

infile="$1"
outdir="$2"

#metadatacsvdir="../MetadataCSV"
metadatacsvdir="CPTACMetadataCSV"

TMPJSONFILE="/tmp/`basename $0`.$$"

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="CPTACspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="CPTACstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="CPTACstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="cptac_tabulateduids.csv"
TMPSLIDEUIDFILE="slideuid.csv"

#JHOVE="${HOME}/work/jhove/jhove"

PIXELMEDDIR="${HOME}/work/pixelmed/imgbook"
PATHTOADDITIONAL="${PIXELMEDDIR}/lib/additional"

filename=`basename "${infile}" '.svs'`

slidefilenameforuid="${filename}"
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

# "CPTAC-LUAD/C3N-00547-27.svs"
# "CPTAC-OV/01OV007-9b90eb78-2f50-4aeb-b010-d642f9.svs"

cptacproject=`dirname "${infile}" | sed -e 's/^CPTAC-//'`
echo "cptacproject = ${cptacproject}"

if [ -z "${outdir}" ]
then
	outdir="Converted/CPTAC-${cptacproject}/${filename}"
fi

if [ -z "${cptacproject}" ]
then
	echo 1>&2 "Error: cannot create metadata CSV file name"
	exit 1
else
	if [ "${cptacproject}" = "GBMa" ]
	then
		csvfilename="${metadatacsvdir}/GBM.csv"
	else
		csvfilename="${metadatacsvdir}/${cptacproject}.csv"
	fi
	if [ ! -f "${csvfilename}" ]
	then
		echo 1>&2 "Warning: no metadata CSV file called ${csvfilename}"
		#exit 1
	fi
fi

if [ "${cptacproject}" = "BRCA" -o "${cptacproject}" = "COAD" -o "${cptacproject}" = "OV" ]
then
	# CPTAC-OV - "01OV007-9b90eb78-2f50-4aeb-b010-d642f9"
	# "01BR001-0684a407-f446-486d-9160-b483cb"
	# "05BR029-afd16022-38d1-4e61-8519-80e355_2"
	# "02OV034-[70]-f62cf2_D1_D1"

	slide_id=`echo "${filename}" | sed -e 's/^[^-]*-\(.*\)$/\1/'`
	echo "CPTAC-2 slide_id = ${slide_id}"
else
	# CPTAC-LUAD - "C3N-00547-27"
	slide_id="${filename}"
	echo "CPTAC-3 slide_id = ${slide_id}"
fi

#echo "csvfilename = ${csvfilename}"
if [ -f "${csvfilename}" ]
then
	csvlineforslide=`egrep "^${slide_id}," "${csvfilename}" | head -1`
fi

if [ -z "${csvlineforslide}" ]
then
	echo 1>&2 "Warning: cannot find metadata CSV file entry for slide_id ${slide_id} - attempting to derive from filename or slide_id"
	if [ "${cptacproject}" = "BRCA" -o "${cptacproject}" = "COAD" -o "${cptacproject}" = "OV" ]
	then
		# CPTAC-OV - "01OV007-9b90eb78-2f50-4aeb-b010-d642f9"
		case_id=`echo "${filename}" | sed -e 's/^\([^-]*\)-.*$/\1/'`
		if [ "${case_id}" = "${filename}" ]
		then
			# didn't substitute
			echo 1>&2 "Error: cannot find metadata CSV file entry for filename ${filename} and cannot derive from filename"
			exit 1
		else
			# create dummy specimen ID suffix, since don't want to leave it blank - use slide_id already extracted (or entire filename if failed)
			specimen_id="${slide_id}"
			tumor_code="${cptacproject}"
		fi
	else
		# CPTAC-LUAD - "C3N-00547-27"
		case_id=`echo "${slide_id}" | sed -e 's/^\(C3[A-Z]-[0-9][0-9][0-9][0-9][0-9]\)-[0-9][0-9]$/\1/'`
		if [ "${case_id}" = "${slide_id}" ]
		then
			# didn't substitute
			echo 1>&2 "Error: cannot find metadata CSV file entry for slide_id ${slide_id} and cannot derive from slide_id"
			exit 1
		else
			# create dummy specimen ID suffix, since don't want to leave it blank - use slide_id
			specimen_id="${slide_id}"
			tumor_code="${cptacproject}"
		fi
	fi
	echo 1>&2 "derived case_id is ${case_id}"
else
	#slide_id,specimen_id,tumor_code,case_id,gender,age,height_in_cm,weight_in_kg,race,ethnicity,tumor_site,tissue_type
	specimen_id=`echo "${csvlineforslide}" | awk -F, '{print $2}'`
	tumor_code=`echo "${csvlineforslide}" | awk -F, '{print $3}'`
	case_id=`echo "${csvlineforslide}" | awk -F, '{print $4}'`
	gender=`echo "${csvlineforslide}" | awk -F, '{print $5}'`
	age=`echo "${csvlineforslide}" | awk -F, '{print $6}'`
	height_in_cm=`echo "${csvlineforslide}" | awk -F, '{print $7}'`
	weight_in_kg=`echo "${csvlineforslide}" | awk -F, '{print $8}'`
	race=`echo "${csvlineforslide}" | awk -F, '{print $9}'`
	ethnicity=`echo "${csvlineforslide}" | awk -F, '{print $10}'`
	tumor_site=`echo "${csvlineforslide}" | awk -F, '{print $11}'`
	tissue_type=`echo "${csvlineforslide}" | awk -F, '{print $12}'`
fi

fixation="UNKNOWN"	# vs. FFPE or FROZEN ... not in available metadata yet

echo "infile = ${infile}"
echo "filename = ${filename}"
echo "cptacproject = ${cptacproject}"
echo "slide_id = ${slide_id}"
echo "specimen_id = ${specimen_id}"
echo "tumor_code = ${tumor_code}"
echo "tumor_site = ${tumor_site}"
echo "tissue_type = ${tissue_type}"
echo "case_id = ${case_id}"
echo "fixation = ${fixation}"

if [ ! "${cptacproject}" = "${tumor_code}" ]
then
	if [ "${cptacproject}" = "GBMa" -a "${tumor_code}" = "GBM" ]
	then
		echo 1>&2 "Warning: assuming cptacproject ${cptacproject} matches tumor_code ${tumor_code}"
	elif [ "${cptacproject}" = "BRCA" -a "${tumor_code}" = "BR" ]
	then
		echo 1>&2 "Warning: assuming cptacproject ${cptacproject} matches tumor_code ${tumor_code}"
	elif [ "${cptacproject}" = "COAD" -a "${tumor_code}" = "CO" ]
	then
		echo 1>&2 "Warning: assuming cptacproject ${cptacproject} matches tumor_code ${tumor_code}"
	else
		echo 1>&2 "Warning: cptacproject ${cptacproject} does not match tumor_code ${tumor_code}"
		# not a reason to give up converting!
		#exit 1
	fi
fi

# TCIA pattern for radiology is same string for PatientName and PatientID
dicompatientid="${case_id}"
dicompatientname="${dicompatientid}"
dicomspecimenidentifier="${specimen_id}"

# make sure these are no longer than 16 chars ...
#if [ `/bin/echo -n "${specimen_id}" | wc -c` -le 16 ]
#then
#	dicomstudyid="${specimen_id}"
#	dicomaccessionnumber="${specimen_id}"
#fi
# else leave them empty

dicomstudyid="${case_id}"
dicomaccessionnumber="${case_id}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

dicomclinicaltrialsponsorname="CPTAC"
dicomclinicalprotocolid="CPTAC-${cptacproject}"

tissuetypecodevalue=""
tissuetypecsd="SCT"
tissuetypecodemeaning=""

if [ "${tissue_type}" = "normal" -o "${tissue_type}" = "normal_tissue" ]
then
	tissuetypecodevalue="17621005"
	tissuetypecodemeaning="Normal"
elif [ "${tissue_type}" = "tumor" -o "${tissue_type}" = "tumor_tissue" ]
then
	tissuetypecodevalue="86049000"
	tissuetypecodemeaning="Neoplasm, Primary"
fi

anatomycodevalue=""
anatomycsd="SCT"
anatomycodemeaning=""

# should make this a table lookup from a separate text file :(
# should probably use tumor_code or tumor_site from metadata instead of project :(
if [ "${cptacproject}" = "AML" ]
then
	dicomclinicalprotocolname="CPTAC Acute Myeloid Leukemia"
	anatomycodevalue="14016003"
	anatomycodemeaning="Bone marrow"
elif [ "${cptacproject}" = "BRCA" ]
then
	dicomclinicalprotocolname="CPTAC Breast Invasive Carcinoma"
	anatomycodevalue="76752008"
	anatomycodemeaning="Breast"
elif [ "${cptacproject}" = "CCRCC" ]
then
	dicomclinicalprotocolname="CPTAC Clear Cell Carcinoma"
	anatomycodevalue="64033007"
	anatomycodemeaning="Kidney"
elif [ "${cptacproject}" = "CM" ]
then
	dicomclinicalprotocolname="CPTAC Cutaneous Melanoma"
	anatomycodevalue="39937001"
	anatomycodemeaning="Skin"
elif [ "${cptacproject}" = "COAD" ]
then
	dicomclinicalprotocolname="CPTAC Colon Adenocarcinoma"
	anatomycodevalue="71854001"
	anatomycodemeaning="Colon"
elif [ "${cptacproject}" = "GBM" -o "${cptacproject}" = "GBMa" ]
then
	dicomclinicalprotocolname="CPTAC Glioblastoma multiforme"
	anatomycodevalue="12738006"
	anatomycodemeaning="Brain"
elif [ "${cptacproject}" = "HNSCC" ]
then
	dicomclinicalprotocolname="CPTAC Head and Neck Squamous Cell Carcinoma"
	anatomycodevalue="774007"
	anatomycodemeaning="Head and Neck"
elif [ "${cptacproject}" = "LSCC" ]
then
	dicomclinicalprotocolname="CPTAC Lung Squamous Cell Carcinoma"
	anatomycodevalue="39607008"
	anatomycodemeaning="Lung"
elif [ "${cptacproject}" = "LUAD" ]
then
	dicomclinicalprotocolname="CPTAC Lung adenocarcinoma"
	anatomycodevalue="39607008"
	anatomycodemeaning="Lung"
elif [ "${cptacproject}" = "OV" ]
then
	dicomclinicalprotocolname="CPTAC Ovarian Serous Cystadenocarcinoma"
	anatomycodevalue="15497006"
	anatomycodemeaning="Ovary"
elif [ "${cptacproject}" = "PDA" ]
then
	dicomclinicalprotocolname="CPTAC Pancreatic Ductal Adenocarcinoma"
	anatomycodevalue="15776009"
	anatomycodemeaning="Pancreas"
elif [ "${cptacproject}" = "SAR" ]
then
	dicomclinicalprotocolname="CPTAC Sarcoma"
elif [ "${cptacproject}" = "UCEC" ]
then
	dicomclinicalprotocolname="CPTAC Corpus Endometrial Carcinoma"
	anatomycodevalue="35039007"
	anatomycodemeaning="Uterus"

else
	dicomclinicalprotocolname="${cptacproject}"
fi

dicomclinicaltrialsubjectid="${dicompatientid}"

dicomspecimenuid=""
if [ ! -f "${FILEMAPPINGSPECIMENIDTOUID}" ]
then
	touch "${FILEMAPPINGSPECIMENIDTOUID}"
fi

if [ ! -z "${dicomspecimenidentifier}" ]
then
	# dicomspecimenidentifier may be prefix for other identifiers, so assure bounded by delimiters, and use first if duplicates else failes later
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

# probably don't need these precautions, since all seem to be ScanScope, but just in case ... do it the same way as for TCGA ...
# Aperio "...ScanScope ID = SS1302|Filename = 11952||Date = 04/07/14|Time = 12:30:08|Time Zone = GMT-04:00|..."
# Hamamatsu "...|Date=12/12/2013|Time=03:21:44 PM|Copyright=Hamamatsu Photonics KK|"
# ignore timezone
# ignore Hamamatsu since would need us to add 12 to PM times
svsdatetime=`tiffinfo "${infile}" | grep -v Hamamatsu | grep ScanScope | grep Date | grep Time | head -1 | sed -e 's/^.*Date = \([0-9][0-9]\)[/]\([0-9][0-9]\)[/]\([0-9][0-9]\).*Time = \([0-9][0-9]\)[:]\([0-9][0-9]\)[:]\([0-9][0-9]\).*$/20\3\1\2\4\5\6/'`
if [ -z "${svsdatetime}" ]
then
	# SCN "...|Date = 2014-07-23T16:33:58.37Z|..."
	# ignore fraction, ignore that it is Zulu time
	svsdatetime=`tiffinfo "${infile}" | grep -v Hamamatsu | grep SCN | grep Date | head -1 | sed -e 's/^.*Date = \([0-9][0-9][0-9][0-9]\)-\([0-9][0-9]\)-\([0-9][0-9]\)T\([0-9][0-9]\)[:]\([0-9][0-9]\)[:]\([0-9][0-9]\).*$/\1\2\3\4\5\6/'`
	if [ -z "${svsdatetime}" ]
	then
		echo "Cannot extract an svsdatetime"
	else
		echo "SCN-style svsdatetime"
	fi
else
	echo "Aperio-style svsdatetime"
fi
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
echo "dicomclinicaltrialsiteid = ${dicomclinicaltrialsiteid}"
echo "dicomclinicaltrialsitename = ${dicomclinicaltrialsitename}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

echo "anatomycodevalue = ${anatomycodevalue}"
echo "anatomycsd = ${anatomycsd}"
echo "anatomycodemeaning = ${anatomycodemeaning}"

echo "tissuetypecodevalue = ${tissuetypecodevalue}"
echo "tissuetypecsd = ${tissuetypecsd}"
echo "tissuetypecodemeaning = ${tissuetypecodemeaning}"

dicomsex=""
if [ "${gender}" = "Male" ]
then
	dicomsex="M"
elif [ "${gender}" = "Female" ]
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

dicomsize=""
if [ ! -z "${height_in_cm}" ]
then
	dicomsize=`echo "scale = 2; ${height_in_cm} / 100" | bc`
fi
echo "dicomsize = ${dicomsize}"

dicomweight="${weight_in_kg}"
echo "dicomweight = ${dicomweight}"

dicomethnicgroup=""
# SH, so limited to 16 characters
if [ "${race}" = "American Indian or Alaska Native" ]
then
	dicomethnicgroup="American Indian"
elif [ "${race}" = "Asian" ]
then
	dicomethnicgroup="Asian"
elif [ "${race}" = "Black or African American" ]
then
	dicomethnicgroup="Black"
elif [ "${race}" = "Native Hawaiian or Other Pacific Islander" ]
then
	dicomethnicgroup="Pacific Islander"
elif [ "${race}" = "White" ]
then
	dicomethnicgroup="White"
else
	# ignore "Not Reported"
	# ignore "Unknown"
	echo 1>&2 "Warning: ignoring unrecognized or unwanted race ${race}"
fi
echo "dicomethnicgroup = ${dicomethnicgroup}"

dicomspecimenshortdescription="HE ${tissue_type} ${tcatissueslideidtype}${tcatissueslideidnumber}"

dicomspecimendetaileddescription=""
if [ ! -z "${tumor_site}" -a ! "${tumor_site}" = "Other" -a ! "${tumor_site}" = "Not Reported" -a ! "${tumor_site}" = "Unknown" ]
then
	dicomspecimendetaileddescription="tumor_site: ${tumor_site}"
fi
if [ ! -z "${tissue_type}" ]
then
	if [ ! -z "${dicomspecimendetaileddescription}" ]
	then
		dicomspecimendetaileddescription="${dicomspecimendetaileddescription}, "
	fi
	dicomspecimendetaileddescription="${dicomspecimendetaileddescription}tissue_type: ${tissue_type}"
fi
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
echo >>"${TMPJSONFILE}" "		\"00131010\" : \"${dicomclinicalprotocolid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolName\" : \"${dicomclinicalprotocolname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteID\" : \"${dicomclinicaltrialsiteid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteName\" : \"${dicomclinicaltrialsitename}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSubjectID\" : \"${dicomclinicaltrialsubjectid}\","
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
if [ -z "${tissuetypecodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	    \"PrimaryAnatomicStructureSequence\" : { \"cv\" : \"${anatomycodevalue}\", \"csd\" : \"${anatomycsd}\", \"cm\" : \"${anatomycodemeaning}\" }"
else
	echo >>"${TMPJSONFILE}" "	    \"PrimaryAnatomicStructureSequence\" : ["
	echo >>"${TMPJSONFILE}" "	      {"
	echo >>"${TMPJSONFILE}" "	   		\"CodeValue\" : \"${anatomycodevalue}\","
	echo >>"${TMPJSONFILE}" "	   		\"CodingSchemeDesignator\" : \"${anatomycsd}\","
	echo >>"${TMPJSONFILE}" "	   		\"CodeMeaning\" : \"${anatomycodemeaning}\","
	echo >>"${TMPJSONFILE}" "	   		\"PrimaryAnatomicStructureModifierSequence\" : { \"cv\" : \"${tissuetypecodevalue}\", \"csd\" : \"${tissuetypecsd}\", \"cm\" : \"${tissuetypecodemeaning}\" }"
	echo >>"${TMPJSONFILE}" "	      }"
	echo >>"${TMPJSONFILE}" "	    ]"
fi
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
ls -l "${outdir}"

for i in ${outdir}/*
do
	dciodvfy -new -filename "$i" 2>&1 | egrep -v '(Retired Person Name form|SliceThickness.0018,0050..1.> - Value is zero|ImagedVolumeDepth.0048,0003..1.> - Value is zero)'
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
