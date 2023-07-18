#!/bin/sh
#
# Usage: ./icdcsvstodcm.sh "source-data-icdc/PKG - ICDC-Glioma/ICDC-Glioma/GLIOMA01-i_nnnn.svs" [outdir]

infile="$1"
outdir="$2"

SLIDE_CSVFILENAME="ICDC_GLIOMA01_Histopath_Images_2023-5-1_Transposed.csv"
CASE_CSVFILENAME="ICDC_Cases_download 2023-05-14 08-45-49.csv"

TMPJSONFILE="/tmp/`basename $0`.$$"

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="icdcspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="icdcstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="icdcstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="tabulateduids.csv"
TMPSLIDEUIDFILE="slideuid.csv"

#JHOVE="${HOME}/work/jhove/jhove"

if [ -d "${HOME}/work/pixelmed/imgbook" ]
then
	PIXELMEDDIR="${HOME}/work/pixelmed/imgbook"
else
	PIXELMEDDIR="${HOME}"
fi

if [ -d "${PIXELMEDDIR}/lib/additional" ]
then
	PATHTOADDITIONAL="${PIXELMEDDIR}/lib/additional"
else
	PATHTOADDITIONAL="${HOME}"
fi

# "source-data-icdc/PKG - ICDC-Glioma/ICDC-Glioma/GLIOMA01-i_1166.svs"

filename=`basename "${infile}" '.svs'`
foldername=`dirname "${infile}"`

#echo "SLIDE_CSVFILENAME = ${SLIDE_CSVFILENAME}"
if [ -f "${SLIDE_CSVFILENAME}" ]
then
	#csvlineforslide=`egrep "^${case_id}," "${SLIDE_CSVFILENAME}" | head -1`
	csvlineforslide=`egrep ",${filename}[.]svs," "${SLIDE_CSVFILENAME}" | head -1`
fi

#Case ID,File name,File format,File size,Md5sum,License,Image modality,Organ or tissue,Fixation and embedding method,Staining method,Image equipment manufacturer,Software package,De-identification method type,De-identification method description
#GLIOMA01-i_03A6,GLIOMA01-i_03A6.svs,svs,3356503081,08a092275b9a801a2a848e8a3cce6b8a,CC-BY 4.0,Slide Microscopy,Brain - Canine,Formalin-Fixed Paraffin-Embedded (Code C143028),Hematoxylin and Eosin Staining Method (Code C23011),Leica Biosystems,Leica Aperio ScanScope CS,Manual,TCIA pathology de-identification SOP

if [ -z "${csvlineforslide}" ]
then
	echo 1>&2 "Warning: cannot find metadata CSV file entry for filename ${filename}.svs - attempting to derive identifiers from filename"
	case_id="${filename}"
else
	echo "csvlineforslide = ${csvlineforslide}"
	case_id=`echo "${csvlineforslide}" | awk -F, '{print $1}' | sed -e 's/ $//g'`
	organortissue=`echo "${csvlineforslide}" | awk -F, '{print $8}'`
	fixationandembedding=`echo "${csvlineforslide}" | awk -F, '{print $9}'`
	stainingmethod=`echo "${csvlineforslide}" | awk -F, '{print $10}'`
fi

# have no specific specimen_id or slide_id supplied in metadata or file name
slide_id="${filename}"
specimen_id="${slide_id}"

if [ -z "${outdir}" ]
then
	outdir="Converted/icdc/${slide_id}"
fi

fixation=""
if [ "${fixationandembedding}" = "Formalin-Fixed Paraffin-Embedded (Code C143028)" ]
then
	fixation="FFPE"
fi

staining=""
if [ "${stainingmethod}" = "Hematoxylin and Eosin Staining Method (Code C23011)" ]
then
	staining="HE"
fi

#echo "CASE_CSVFILENAME = ${CASE_CSVFILENAME}"
if [ -f "${CASE_CSVFILENAME}" ]
then
	# fields are always surrounded by quotes
	csvlineforcase=`egrep "^\"${case_id}\"," "${CASE_CSVFILENAME}" | head -1`
fi

#Case ID,Study Code,Study Type,Breed,Diagnosis,Stage Of Disease,Age,Sex,Neutered Status,Weight (kg),Response to Treatment,Cohort,Canine ID,Matching Cases,Disease Site,Date of Diagnosis,Histology/Cytopathology,Histological Grade,Detailed Pathology Evaluation Available,Treatment Data Available,Follow Up Data Available,Concurrent Disease(s),Concurrent Disease Specifics,Arm
#"GLIOMA01-i_03A6","GLIOMA01","Genomics","Boxer","Glioma","Unknown","11","Female","Yes", ,"Not Determined", , ,"","Brain","", , ,"Yes","No","Yes", , ,

if [ -z "${csvlineforcase}" ]
then
	echo 1>&2 "Warning: cannot find case CSV file entry for case_id ${case_id}"
else
	echo "csvlineforcase = ${csvlineforcase}"
	# fields are always surrounded by quotes
	breed=`echo "${csvlineforcase}" | awk -F, '{print $4}' | sed -r 's/"//g'`
	age=`echo "${csvlineforcase}" | awk -F, '{print $7}' | sed -r 's/"//g'`
	sex=`echo "${csvlineforcase}" | awk -F, '{print $8}' | sed -r 's/"//g'`
	neuteredstatus=`echo "${csvlineforcase}" | awk -F, '{print $9}' | sed -r 's/"//g'`
fi

echo "infile = ${infile}"
echo "filename = ${filename}"
echo "slide_id = ${slide_id}"
echo "specimen_id = ${specimen_id}"
echo "case_id = ${case_id}"

echo "organortissue = ${organortissue}"
echo "fixationandembedding = ${fixationandembedding}"
echo "stainingmethod = ${stainingmethod}"

echo "fixation = ${fixation}"
echo "staining = ${staining}"

echo "breed = ${breed}"
echo "age = ${age}"
echo "sex = ${sex}"
echo "neuteredstatus = ${neuteredstatus}"

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

dicompatientid="${case_id}"
dicompatientname="${case_id}"
dicomspecimenidentifier="${specimen_id}"

dicomstudyid="${case_id}"
dicomaccessionnumber="${case_id}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

dicomclinicaltrialsponsorname="National Cancer Institute"
dicomclinicalprotocolid="ICDC-Glioma"
dicomclinicalprotocolname="Canine glioma characterization project for ICDC (ICDC-Glioma)"
dicomctpprojectname="ICDC-Glioma"

dicomclinicaltrialsubjectid="${dicompatientid}"

anatomycodevalue=""
anatomycsd="SCT"
anatomycodemeaning=""

# should make this a table lookup from a separate text file :(
if [ "${organortissue}" = "Brain - Canine" ]
then
	anatomycodevalue="12738006"
	anatomycsd="SCT"
	anatomycodemeaning="Brain"
fi

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

# NOT USED YET :(
dicomsex=""
if [ "${sex}" = "Male" ]
then
	dicomsex="M"
elif [ "${sex}" = "Female" ]
then
	dicomsex="F"
fi
echo "dicomsex = ${dicomsex}"

dicomage=""
if [ ! -z "${age}" ]
then
	# age is in years and may be fractional, so convert to months prn to preserve precision ...
	echo "age = ${age}"
	# division by unity because bc scale recognition is finicky (https://stackoverflow.com/questions/13963265/bc-is-ignoring-scale-option)
	ageinmonths=`echo "scale=0; (${age} * 12)/1" | bc -l`
	echo "ageinmonths = ${ageinmonths}"
	ageinyearsint=`echo "scale=0; ${ageinmonths} / 12" | bc -l`
	echo "ageinyearsint = ${ageinyearsint}"

	if [ "${ageinyearsint}" = "${age}" -o ${ageinmonths} -ge 999 ]
	then
		# in years sufficient, or won't fit in months (over 83.25 years) so use years as integer ...
		if [ ${ageinyearsint} -ge 100 ]
		then
			dicomage="${ageinyearsint}Y"
		elif [ ${ageinyearsint} -ge 10 ]
		then
			dicomage="0${ageinyearsint}Y"
		else
			dicomage="00${ageinyearsint}Y"
		fi
	elif [ ${ageinmonths} -ge 100 ]
	then
		dicomage="${ageinmonths}M"
	elif [ ${ageinmonths} -ge 10 ]
	then
		dicomage="0${ageinmonths}M"
	else
		dicomage="00${ageinmonths}M"
	fi
fi
echo "dicomage = ${dicomage}"

patientspeciescodevalue="448771007"
patientspeciescsd="SCT"
patientspeciescodemeaning="Canis lupus familiaris"

echo "patientspeciescodevalue = ${patientspeciescodevalue}"
echo "patientspeciescsd = ${patientspeciescsd}"
echo "patientspeciescodemeaning = ${patientspeciescodemeaning}"

dicompatientbreeddescription=""
patientbreedcodevalue=""
patientbreedcsd=""
patientbreedcodemeaning=""

dicompatientbreeddescription="${breed}"
if [ "${breed}" = "Mixed Breed" ]
then
	patientbreedcodevalue="132619000"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Mixed breed dog"
elif [ "${breed}" = "American Staffordshire Terrier" ]
then
	patientbreedcodevalue="83216009"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Staffordshire bull terrier"
elif [ "${breed}" = "Beagle" ]
then
	patientbreedcodevalue="132475005"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Beagle, standard"
elif [ "${breed}" = "Border Collie" ]
then
	patientbreedcodevalue="132561000"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Border collie"
elif [ "${breed}" = "Boston Terrier" ]
then
	patientbreedcodevalue="79295007"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Boston terrier"
elif [ "${breed}" = "Boxer" ]
then
	patientbreedcodevalue="42250008"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Boxer"
elif [ "${breed}" = "Bulldog" ]
then
	patientbreedcodevalue="38184008"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Bulldog"
elif [ "${breed}" = "Chihuahua" ]
then
	patientbreedcodevalue="9761009"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Chihuahua"
elif [ "${breed}" = "Cocker Spaniel" ]
then
	patientbreedcodevalue="22697009"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="American cocker spaniel"
elif [ "${breed}" = "Dalmatian" ]
then
	patientbreedcodevalue="5916008"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Dalmatian"
elif [ "${breed}" = "Doberman Pinscher" ]
then
	patientbreedcodevalue="47075006"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Doberman pinscher"
elif [ "${breed}" = "French Bulldog" ]
then
	patientbreedcodevalue="59643008"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="French bulldog"
elif [ "${breed}" = "Golden Retriever" ]
then
	patientbreedcodevalue="58108001"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Golden retriever"
elif [ "${breed}" = "Labrador Retriever" ]
then
	patientbreedcodevalue="62137007"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Labrador retriever"
elif [ "${breed}" = "Mastiff" ]
then
	patientbreedcodevalue="48524002"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Mastiff"
elif [ "${breed}" = "Poodle" ]
then
	patientbreedcodevalue="15171008"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Poodle"
elif [ "${breed}" = "Samoyed" ]
then
	patientbreedcodevalue="69474004"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Samoyed"
elif [ "${breed}" = "Shih Tzu" ]
then
	patientbreedcodevalue="31077009"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Shih Tzu"
elif [ "${breed}" = "Staffordshire Bull Terrier" ]
then
	patientbreedcodevalue="83216009"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Staffordshire bull terrier"
elif [ "${breed}" = "Yorkshire Terrier" ]
then
	patientbreedcodevalue="13284009"
	patientbreedcsd="SCT"
	patientbreedcodemeaning="Yorkshire terrier"
elif [ "${breed}" = "Parson Russell Terrier" ]
then
	echo 1>&2 "Warning: no known code for ${breed}"
else
	echo 1>&2 "Warning: unrecognized breed ${breed}"
fi

echo "dicompatientbreeddescription = ${dicompatientbreeddescription}"
echo "patientbreedcodevalue = ${patientbreedcodevalue}"
echo "patientbreedcsd = ${patientbreedcsd}"
echo "patientbreedcodemeaning = ${patientbreedcodemeaning}"

dicompatientspeciesdescription="Canis lupus familiaris"
echo "dicompatientspeciesdescription = ${dicompatientspeciesdescription}"

dicomresponsibleperson=""
dicomresponsibleorganization=""

echo "dicomresponsibleperson = ${dicomresponsibleperson}"
echo "dicomresponsibleorganization = ${dicomresponsibleorganization}"

dicompatientsexneutered=""
if [ "${neuteredstatus}" = "Yes" ]
then
	dicompatientsexneutered="ALTERED"
elif [ "${neuteredstatus}" = "No" ]
then
	dicompatientsexneutered="UNALTERED"
fi
echo "dicompatientsexneutered = ${dicompatientsexneutered}"

dicomspecimenshortdescription="${fixation} ${staining}"
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
	echo >>"${TMPJSONFILE}" "		\"PatientSex\" : \"${dicomsex}\","
fi
if [ ! -z "${dicomage}" ]
then
	echo >>"${TMPJSONFILE}" "		\"PatientAge\" : \"${dicomage}\","
fi
if [ ! -z "${dicomsize}" ]
then
	echo >>"${TMPJSONFILE}" "		\"PatientSize\" : \"${dicomsize}\","
fi
if [ ! -z "${dicomweight}" ]
then
	echo >>"${TMPJSONFILE}" "		\"PatientWeight\" : \"${dicomweight}\","
fi
if [ ! -z "${dicompatientspeciesdescription}" ]
then
	echo >>"${TMPJSONFILE}" "		\"PatientSpeciesDescription\" : \"${dicompatientspeciesdescription}\","
fi
if [ ! -z "${patientspeciescodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "		\"PatientSpeciesCodeSequence\" : { \"cv\" : \"${patientspeciescodevalue}\", \"csd\" : \"${patientspeciescsd}\", \"cm\" : \"${patientspeciescodemeaning}\" },"
	echo >>"${TMPJSONFILE}" "		\"PatientBreedDescription\" : \"${dicompatientbreeddescription}\","
	if [ ! -z "${patientbreedcodevalue}" ]
	then
		echo >>"${TMPJSONFILE}" "		\"PatientBreedCodeSequence\" : { \"cv\" : \"${patientbreedcodevalue}\", \"csd\" : \"${patientbreedcsd}\", \"cm\" : \"${patientbreedcodemeaning}\" },"
	else
		echo >>"${TMPJSONFILE}" "		\"PatientBreedCodeSequence\" : null,"
	fi
	echo >>"${TMPJSONFILE}" "		\"BreedRegistrationSequence\" : null,"
	echo >>"${TMPJSONFILE}" "		\"ResponsiblePerson\" : \"${dicomresponsibleperson}\","
	echo >>"${TMPJSONFILE}" "		\"ResponsibleOrganization\" : \"${dicomresponsibleorganization}\","
	echo >>"${TMPJSONFILE}" "		\"PatientSexNeutered\" : \"${dicompatientsexneutered}\","
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
	echo >>"${TMPJSONFILE}" "		      }"
fi
if [ "${fixation}" = "FFPE" -a "${staining}" = "HE" ]
then
	echo >>"${TMPJSONFILE}" "	    ,"
fi
if [ "${staining}" = "HE" ]
then
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
fi
echo >>"${TMPJSONFILE}" "	    ]"
if [ ! -z "${anatomycodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	    ,"
	echo >>"${TMPJSONFILE}" "	    \"PrimaryAnatomicStructureSequence\" : { \"cv\" : \"${anatomycodevalue}\", \"csd\" : \"${anatomycsd}\", \"cm\" : \"${anatomycodemeaning}\" }"
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

echo "outdir = ${outdir}"
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
