#!/bin/sh
#
# Usage: ./cmbtodcm.sh folder/filename.svs [outdir]

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

#CSVFILENAMEFORMETADATA="draft-cmb-path-slides-idc-20231010.csv"
CSVFILENAMEFORMETADATA="cmb-path-slides-query-20240501_plus_MSB-04591-13-02.csv"
if [ ! -f "${CSVFILENAMEFORMETADATA}" ]
then
	echo 1>&2 "Error: no metadata CSV file called ${CSVFILENAMEFORMETADATA}"
	exit 1
fi

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="CMBspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="CMBstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="CMBstudyIDToDateTimeMap.csv"

#JHOVE="${HOME}/work/jhove/jhove"

if [ -f "${HOME}/work/pixelmed/imgbook/pixelmed.jar" ]
then
	PIXELMEDDIR="${HOME}/work/pixelmed/imgbook"
	PATHTOADDITIONAL="${PIXELMEDDIR}/lib/additional"
elif [ -f "${HOME}/pixelmed.jar" ]
then
	PIXELMEDDIR="${HOME}"
	PATHTOADDITIONAL="${HOME}"
fi

# will get collection from metadata and populate other clinical trial attributes later ...
dicomclinicaltrialcoordinatingcentername=""
dicomclinicaltrialsponsorname="National Cancer Institute (NCI)"
issuerofdicomclinicalprotocolid="NCI"
dicomclinicaltrialsiteid=""
# use IDC-specific Zenodo DOI, not TCIA collection-specific DOI
doiclinicalprotocolid="doi:10.5281/zenodo.11099112"

# "source-data-cmb/CMB-PCA/MSB-02472-03-01.svs"

# do not remove suffix '.svs' from filename since need to match what is in CSVFILENAMEFORIMAGING
filename=`basename "${infile}"`
foldername=`dirname "${infile}"`

slide_id=`echo ${filename} | sed -e 's/^\([A-Z0-9-]*\).*$/\1/'`
# slide_id = MSB-02472-03-01

if [ -z "${outdir}" ]
then
	outdir="Converted/${slide_id}"
fi

sample_id="${slide_id}"
specimen_id="${sample_id}"

echo "infile = ${infile}"
echo "filename = ${filename}"
echo "slide_id = ${slide_id}"
echo "sample_id = ${sample_id}"
echo "specimen_id = ${specimen_id}"

if [ -f "${CSVFILENAMEFORMETADATA}" ]
then
	# ,participant_id,gender,race,ethnicity,dbGaP_subject_id,primary_diagnosis,participant_ID,file_name,file_format,image_modality,imaging_equipment_manufacturer,imaging_equipment_model,organ_or_tissue,sample_id,sample_type,tumor_tissue_type,tissue_fixative,embedding_medium,staining_method,collection,material_type,collection_event
	# ,MSB-02472,M,BLACK OR AFRICAN AMERICAN,NOT HISPANIC OR LATINO,MSB-02472,Prostate Carcinoma,MSB-02472,189568.svs,SVS,SM,Aperio,AT2,Prostate,MSB-02472-03-01,NA,Metastatic,Formalin,Paraffin wax,Hematoxylin and Eosin Staining Method,CMB-PCA,Glass H&E Slide,Archival

	# participant_id,sample_id,gender,race,ethnicity,primary_diagnosis,file_name,file_format,image_modality,imaging_equipment_manufacturer,imaging_equipment_model,organ_or_tissue,sample_type,tumor_tissue_type,tissue_fixative,embedding_medium,staining_method,collection,material_type,collection_event
	# MSB-00089,MSB-00089-01-02,Female,BLACK OR AFRICAN AMERICAN,NOT HISPANIC OR LATINO,Plasma Cell Myeloma,MSB-00089-01-02.svs,SVS,SM,Aperio,AT2,Bone Marrow,Iliac Crest,PRIMARY,Formalin,Paraffin wax,Hematoxylin and Eosin Staining Method,CMB-MML,Glass H&E Slide,ARCHIVAL

	# note that despite the "file_name" column, which has entries like "189568.svs", the image files we have from TCIA via Aspera are of the form "MSB-02472-03-01.svs", which matches the "sample_id" column, so the following grep works ...
	csvlineformetadata=`grep ",${sample_id}," "${CSVFILENAMEFORMETADATA}" | head -1 | sed 's/\r$//'`
	echo "csvlineformetadata = ${csvlineformetadata}"
fi

if [ -z "${csvlineformetadata}" ]
then
	echo 1>&2 "Warning: cannot find metadata CSV file entry for slide_id ${slide_id}"
	#slide_id = MSB-07656-07-04
	#patient_id = MSB-07656
	patient_id=`echo "${slide_id}" | sed -e 's/^\(MSB-[0-9]*\)-[0-9-]*$/\1/'`
	#infile = idc-source-data-cmb/CMB-AML/MSB-07656-07-04.svs
	#collection = CMB-AML
	collection=`echo "${infile}" | sed -e 's/^.*\(CMB-[A-Z]*\).*$/\1/'`
else
	collection=`echo "${csvlineformetadata}" | awk -F, '{print $18}'`
	patient_id=`echo "${csvlineformetadata}" | awk -F, '{print $1}'`
	gender=`echo "${csvlineformetadata}" | awk -F, '{print $3}'`
	race=`echo "${csvlineformetadata}" | awk -F, '{print $4}'`
	#ethnicity=`echo "${csvlineformetadata}" | awk -F, '{print $5}'`
	organ_or_tissue=`echo "${csvlineformetadata}" | awk -F, '{print $12}'`
	primary_diagnosis=`echo "${csvlineformetadata}" | awk -F, '{print $6}'`
	tumor_tissue_type=`echo "${csvlineformetadata}" | awk -F, '{print $14}'`
	tissue_fixative=`echo "${csvlineformetadata}" | awk -F, '{print $15}'`
	embedding_medium=`echo "${csvlineformetadata}" | awk -F, '{print $16}'`
	staining_method=`echo "${csvlineformetadata}" | awk -F, '{print $17}'`
	#collection_event is sometimes quoted, specifically, '"Post Treatment, No Progression"' ...
	csvlineformetadata_cleaned=`echo "${csvlineformetadata}" | sed -e 's/"Post Treatment, No Progression"/Post Treatment No Progression/'`
	collection_event=`echo "${csvlineformetadata_cleaned}" | awk -F, '{print $20}'`
fi

echo "collection = ${collection}"
echo "patient_id = ${patient_id}"

dicomclinicaltrialsubjectid="${patient_id}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

if [ ! -z "${collection_event}" -a "${collection_event}" != "NA" ]
then
	dicomclinicaltrialtimepointid=`echo "${collection_event}" | tr 'A-Z' 'a-z'`
fi
echo "dicomclinicaltrialtimepointid = ${dicomclinicaltrialtimepointid}"

echo "gender = ${gender}"
echo "race = ${race}"
#echo "ethnicity = ${ethnicity}"
echo "organ_or_tissue = ${organ_or_tissue}"
echo "primary_diagnosis = ${primary_diagnosis}"
echo "tumor_tissue_type = ${tumor_tissue_type}"
echo "tissue_fixative = ${tissue_fixative}"
echo "embedding_medium = ${embedding_medium}"
echo "staining_method = ${staining_method}"

# from https://www.cancerimagingarchive.net/research/cmb/
# decision is not to use TCIA collection-specific DOI, but IDC-specific Zenodo doi (vide supra)
dicomclinicalprotocolid="${collection}"
if [ "${collection}" = "CMB-AML" ]
then
	#doiclinicalprotocolid="doi:10.7937/PCTE-6M66"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Acute Myeloid Leukemia (${collection})"
elif [ "${collection}" = "CMB-CRC" ]
then
	#doiclinicalprotocolid="doi:10.7937/DJG7-GZ87"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Colorectal Cancer (${collection})"
elif [ "${collection}" = "CMB-GEC" ]
then
	#doiclinicalprotocolid="doi:10.7937/E7KH-R486"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Gastroesophageal Cancer (${collection})"
elif [ "${collection}" = "CMB-LCA" ]
then
	#doiclinicalprotocolid="doi:10.7937/3CX3-S132"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Lung Cancer (${collection})"
elif [ "${collection}" = "CMB-MEL" ]
then
	#doiclinicalprotocolid="doi:10.7937/GWSP-WH72"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Melanoma (${collection})"
elif [ "${collection}" = "CMB-MML" ]
then
	#doiclinicalprotocolid="doi:10.7937/SZKB-SW39"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Multiple Myeloma (${collection})"
elif [ "${collection}" = "CMB-PCA" ]
then
	#doiclinicalprotocolid="doi:10.7937/25T7-6Y12"
	dicomclinicalprotocolname="Cancer Moonshot Biobank - Prostate Cancer (${collection})"
else
	echo 1>&2 "Warning: unrecognized collection \"${collection}\""
fi

echo "outdir = ${outdir}"

dicompatientid="${patient_id}"
dicompatientname="${dicompatientid}"

dicomspecimenidentifier="${specimen_id}"

dicomstudyid="${patient_id}"
dicomaccessionnumber="${patient_id}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

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

# Aperio "...ScanScope ID = SS1302|Filename = 11952||Date = 04/07/14|Time = 12:30:08|Time Zone = GMT-04:00|..."
# Aperio "...AppMag = 40|Date = 07/24/2023|Exposure Scale = 0.000001|Exposure Time = 8|Filtered = 3|Focus Offset = 0.500000|Gamma = 2.2|Left = 19.347723007202|MPP = 0.263447|Rack = 10|ScanScope ID = SS12035|Slide = 27|StripeWidth = 4096|Time = 15:22:42|Time Zone = GMT-0400|Top = 44.411762237549..."
# Hamamatsu "...|Date=12/12/2013|Time=03:21:44 PM|Copyright=Hamamatsu Photonics KK|"
# ignore timezone
# ignore Hamamatsu since would need us to add 12 to PM times
# try 4 digit year "|Date = 07/24/2023|"
svsdatetime=`tiffinfo "${infile}" | grep -v Hamamatsu | grep ScanScope | grep Date | grep Time | head -1 | egrep 'Date = [0-9][0-9][/][0-9][0-9][/]20[0-9][0-9][|]' | sed -e 's/^.*Date = \([0-9][0-9]\)[/]\([0-9][0-9]\)[/]\([0-9][0-9][0-9][0-9]\).*Time = \([0-9][0-9]\)[:]\([0-9][0-9]\)[:]\([0-9][0-9]\).*$/\3\1\2\4\5\6/'`
if [ -z "${svsdatetime}" ]
then
	# try 2 digit year "|Date = 04/07/14|"
	svsdatetime=`tiffinfo "${infile}" | grep -v Hamamatsu | grep ScanScope | grep Date | grep Time | head -1 | egrep 'Date = [0-9][0-9][/][0-9][0-9][/][0-9][0-9][|]' | sed -e 's/^.*Date = \([0-9][0-9]\)[/]\([0-9][0-9]\)[/]\([0-9][0-9]\).*Time = \([0-9][0-9]\)[:]\([0-9][0-9]\)[:]\([0-9][0-9]\).*$/20\3\1\2\4\5\6/'`
fi
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
		if [ -z "${svsdatetime}" ]
		then
			# use current datetime, just as TIFFToDicom would, so that this is set now and reused for all future series for the same StudyID
			dicomstudydatetime=`date '+%Y%m%d%H%M%S'`
			echo "No SVS datetime, so using current datetime ${dicomstudydatetime}"
		else
			dicomstudydatetime="${svsdatetime}"
		fi
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

dicomsex=""
lcgender=`echo "${gender}" | tr 'A-Z' 'a-z'`
if [ "${lcgender}"  = "male" -o "${lcgender}" = "m" ]
then
	dicomsex="M"
elif [ "${lcgender}" = "female" -o "${lcgender}" = "f" ]
then
	dicomsex="F"
else
	echo 1>&2 "Warning: ignoring unrecognized gender ${gender}"
fi
echo "dicomsex = ${dicomsex}"

dicomage=""
echo "dicomage = ${dicomage}"

dicomethnicgroup=""
# SH, so limited to 16 characters
if [ "${race}" = "AMERICAN INDIAN OR ALASKA NATIVE" ]
then
	dicomethnicgroup="American Indian"
elif [ "${race}" = "ASIAN" ]
then
	dicomethnicgroup="Asian"
elif [ "${race}" = "BLACK OR AFRICAN AMERICAN" ]
then
	dicomethnicgroup="Black"
elif [ "${race}" = "BLACK OR AFRICAN AMERICAN+AMERICAN INDIAN OR ALASKA NATIVE" ]
then
	dicomethnicgroup="Black+AmerIndian"
elif [ "${race}" = "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER" ]
then
	dicomethnicgroup="Pacific Islander"
elif [ "${race}" = "WHITE" ]
then
	dicomethnicgroup="White"
elif [ "${race}" = "WHITE+AMERICAN INDIAN OR ALASKA NATIVE" ]
then
	dicomethnicgroup="White+AmerIndian"
elif [ "${race}" != "UNKNOWN" -a "${race}" != "NOT REPORTED" -a ! -z "${race}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized race ${race}"
fi
echo "dicomethnicgroup = ${dicomethnicgroup}"

anatomycodevalue=""
anatomycsd=""
anatomycodemeaning=""
lateralitycodevalue=""
lateralitycsd=""
lateralitycodemeaning=""
anatomymodifiercodevalue=""
anatomymodifiercsd=""
anatomymodifiercodemeaning=""

echo "extracted organ_or_tissue = ${organ_or_tissue}"
if [ ! -z "${organ_or_tissue}" ]
then
	organ_or_tissue=`echo "${organ_or_tissue}" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z]/ /g' | sed -e 's/[ ][ ]*/ /g'`
	echo "normalized organ_or_tissue = ${organ_or_tissue}"
	if [ "${organ_or_tissue}" = "bone" ]
	then
		anatomycodevalue="272673000"
		anatomycsd="SCT"
		anatomycodemeaning="Bone"
	elif [ "${organ_or_tissue}" = "bone marrow" ]
	then
		anatomycodevalue="14016003"
		anatomycsd="SCT"
		anatomycodemeaning="Bone marrow"
	elif [ "${organ_or_tissue}" = "colon" ]
	then
		anatomycodevalue="71854001"
		anatomycsd="SCT"
		anatomycodemeaning="Colon"
	elif [ "${organ_or_tissue}" = "esophagus" ]
	then
		anatomycodevalue="32849002"
		anatomycsd="SCT"
		anatomycodemeaning="Esophagus"
	elif [ "${organ_or_tissue}" = "intestines" ]
	then
		anatomycodevalue="113276009"
		anatomycsd="SCT"
		anatomycodemeaning="Intestine"
	elif [ "${organ_or_tissue}" = "liver" ]
	then
		anatomycodevalue="10200004"
		anatomycsd="SCT"
		anatomycodemeaning="Liver"
	elif [ "${organ_or_tissue}" = "lung" ]
	then
		anatomycodevalue="39607008"
		anatomycsd="SCT"
		anatomycodemeaning="Lung"
	elif [ "${organ_or_tissue}" = "prostate" ]
	then
		anatomycodevalue="41216001"
		anatomycsd="SCT"
		anatomycodemeaning="Prostate"
	elif [ "${organ_or_tissue}" = "rectum" ]
	then
		anatomycodevalue="34402009"
		anatomycsd="SCT"
		anatomycodemeaning="Rectum"
	elif [ "${organ_or_tissue}" = "skin" ]
	then
		anatomycodevalue="39937001"
		anatomycsd="SCT"
		anatomycodemeaning="Skin"
	elif [ "${organ_or_tissue}" = "stomach" ]
	then
		anatomycodevalue="69695003"
		anatomycsd="SCT"
		anatomycodemeaning="Stomach"
	elif [ "${organ_or_tissue}" = "whole blood" ]
	then
		# is substance not structure
		anatomycodevalue="420135007"
		anatomycsd="SCT"
		anatomycodemeaning="Whole Blood"
	else
		echo 1>&2 "Warning: unrecognized body site \"${organ_or_tissue}\" for sample_id ${sample_id}"
	fi
fi

echo "anatomycodemeaning = ${anatomycodemeaning}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

if [ ! -z "${tumor_tissue_type}" ]
then
	if [ "${tumor_tissue_type}" = "Adjacent Non-Tumor" ]
	then
		tissuetypecodevalue="17621005"
		tissuetypecsd="SCT"
		tissuetypecodemeaning="Normal"
		tissuetypeshortdescription="N"
	elif [ "${tumor_tissue_type}" = "Primary" ]
	then
		tissuetypecodevalue="372087000"
		tissuetypecsd="SCT"
		tissuetypecodemeaning="Primary malignant neoplasm"
		tissuetypeshortdescription="P"
	elif [ "${tumor_tissue_type}" = "Metastatic" ]
	then
		tissuetypecodevalue="14799000"
		tissuetypecsd="SCT"
		tissuetypecodemeaning="Metastatic neoplasm"
		tissuetypeshortdescription="M"
	elif [ "${tumor_tissue_type}" != "NA" -a ]
	then
		echo 1>&2 "Warning: ignoring unrecognized tumor_tissue_type ${tumor_tissue_type}"
	fi
fi

echo "tissuetypecodemeaning = ${tissuetypecodemeaning}"

dicomdiagnosisdescription=""
dicomdiagnosiscodevalue=""
dicomdiagnosiscsd=""
dicomdiagnosiscodemeaning=""
if [ ! -z "${primary_diagnosis}" ]
then
	diagnosislc=`echo "${primary_diagnosis}" | tr 'A-Z' 'a-z'`
	if [ ! -z "${diagnosislc}" ]
	then
		dicomdiagnosisdescription="${primary_diagnosis}"
		# use SCT disorder rather than morphologic abnormality codes when both; none of these are in DICOM subset (yet) :(
		if [ "${diagnosislc}" = "acute myeloid leukemia not otherwise specified" ]
		then
			dicomdiagnosiscodevalue="91861009"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Acute myeloid leukemia"
		elif [ "${diagnosislc}" = "adenocarcinoma of the gastroesophageal junction" ]
		then
			dicomdiagnosiscodevalue="721628002"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Primary adenocarcinoma of esophagogastric junction"
		elif [ "${diagnosislc}" = "colorectal carcinoma" ]
		then
			dicomdiagnosiscodevalue="1286877004"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Colorectal cancer"
		elif [ "${diagnosislc}" = "melanoma" ]
		then
			dicomdiagnosiscodevalue="372244006"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Malignant melanoma"
		elif [ "${diagnosislc}" = "non-small cell lung carcinoma" ]
		then
			dicomdiagnosiscodevalue="254637007"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Non-small cell lung cancer"
		elif [ "${diagnosislc}" = "plasma cell myeloma" ]
		then
			dicomdiagnosiscodevalue="1162576007"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Plasma cell myeloma"
		elif [ "${diagnosislc}" = "prostate carcinoma" ]
		then
			dicomdiagnosiscodevalue="254900004"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Carcinoma of prostate"
		elif [ "${diagnosislc}" = "small cell lung carcinoma" ]
		then
			dicomdiagnosiscodevalue="254632001"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Small cell carcinoma of lung"
		else
			echo 1>&2 "Warning: ignoring unrecognized diagnosis ${diagnosislc}"
		fi
	fi
fi

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

echo "anatomycodevalue = ${anatomycodevalue}"
echo "anatomycsd = ${anatomycsd}"
echo "anatomycodemeaning = ${anatomycodemeaning}"

echo "lateralitycodevalue = ${lateralitycodevalue}"
echo "lateralitycsd = ${lateralitycsd}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"

echo "anatomymodifiercodevalue = ${anatomymodifiercodevalue}"
echo "anatomymodifiercsd = ${anatomymodifiercsd}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

echo "tissuetypecodevalue = ${tissuetypecodevalue}"
echo "tissuetypecsd = ${tissuetypecsd}"
echo "tissuetypecodemeaning = ${tissuetypecodemeaning}"
echo "tissuetypeshortdescription = ${tissuetypeshortdescription}"

tissue_fixative_forshortdescription="${tissue_fixative}"
if [ "${tissue_fixative}" = "Formalin" ]
then
	tissue_fixative_forshortdescription="FF"
fi

embedding_medium_forshortdescription="${embedding_medium}"
if [ "${embedding_medium}" = "Paraffin wax" ]
then
	embedding_medium_forshortdescription="PE"
fi

staining_method_forshortdescription="${staining_method}"
if [ "${staining_method}" = "Hematoxylin and Eosin Staining Method" ]
then
	staining_method_forshortdescription="HE"
elif [ "${staining_method}" = "Wright-Giemsa Staining Method" ]
then
	staining_method_forshortdescription="WG"
fi

dicomspecimenshortdescription="${tissue_fixative_forshortdescription} ${embedding_medium_forshortdescription} ${staining_method_forshortdescription} ${tissuetypeshortdescription}"
echo "dicomspecimenshortdescription = ${dicomspecimenshortdescription}"

dicomspecimendetaileddescription="${tissue_fixative} ${embedding_medium} ${staining_method} ${tumor_tissue_type}"
echo "dicomspecimendetaileddescription = ${dicomspecimendetaileddescription}"

dicomseriesdescription="${dicomspecimenshortdescription}"
echo "dicomseriesdescription = ${dicomseriesdescription}"

echo "dicomdiagnosisdescription = ${dicomdiagnosisdescription}"
echo "dicomdiagnosiscodevalue = ${dicomdiagnosiscodevalue}"
echo "dicomdiagnosiscsd = ${dicomdiagnosiscsd}"
echo "dicomdiagnosiscodemeaning = ${dicomdiagnosiscodemeaning}"

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
if [ ! -z "${dicomdiagnosisdescription}" ]
then
	echo >>"${TMPJSONFILE}" "		\"AdmittingDiagnosesDescription\" : \"${dicomdiagnosisdescription}\","
fi
if [ ! -z "${dicomdiagnosiscodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "		\"AdmittingDiagnosesCodeSequence\" : { \"cv\" : \"${dicomdiagnosiscodevalue}\", \"csd\" : \"${dicomdiagnosiscsd}\", \"cm\" : \"${dicomdiagnosiscodemeaning}\" },"
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
if [ ! -z "${dicomethnicgroup}" ]
then
	echo >>"${TMPJSONFILE}" "		\"EthnicGroup\" : \"${dicomethnicgroup}\","
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
if [ ! -z "${issuerofdicomclinicalprotocolid}" ]
then
	echo >>"${TMPJSONFILE}" "		\"IssuerOfClinicalTrialProtocolID\" : \"${issuerofdicomclinicalprotocolid}\","
fi
if [ ! -z "${doiclinicalprotocolid}" ]
then
	echo >>"${TMPJSONFILE}" "		\"OtherClinicalTrialProtocolIDsSequence\" : ["
	echo >>"${TMPJSONFILE}" "			{"
	echo >>"${TMPJSONFILE}" "				\"ClinicalTrialProtocolID\" : \"${doiclinicalprotocolid}\","
	echo >>"${TMPJSONFILE}" "				\"IssuerOfClinicalTrialProtocolID\" : \"DOI\""
	echo >>"${TMPJSONFILE}" "			}"
	echo >>"${TMPJSONFILE}" "		],"
fi
echo >>"${TMPJSONFILE}" "		\"00130010\" : \"CTP\","
echo >>"${TMPJSONFILE}" "		\"00131010\" : \"${dicomclinicalprotocolid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolName\" : \"${dicomclinicalprotocolname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteID\" : \"${dicomclinicaltrialsiteid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteName\" : \"${dicomclinicaltrialsitename}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSubjectID\" : \"${dicomclinicaltrialsubjectid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialCoordinatingCenterName\" : \"${dicomclinicaltrialcoordinatingcentername}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialTimePointID\" : \"${dicomclinicaltrialtimepointid}\","

if [ ! -z "${dicominstitutionname}" ]
then
	echo >>"${TMPJSONFILE}" "		\"InstitutionName\" : \"${dicominstitutionname}\","
fi
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
if [ "${tissue_fixative}" = "Formalin" -o "${tissue_fixative}" = "EDTA" ]
then
	populated_tissue_fixative="true"
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
	if [ "${tissue_fixative}" = "Formalin" ]
	then
		echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"431510009\", \"csd\" : \"SCT\", \"cm\" : \"Formalin\" }"
	elif [ "${tissue_fixative}" = "EDTA" ]
	then
		echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"69519002\", \"csd\" : \"SCT\", \"cm\" : \"EDTA\" }"
	fi
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
elif [ ! -z "${tissue_fixative}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized tissue_fixative ${tissue_fixative}"
fi
if [ "${embedding_medium}" = "Paraffin wax" ]
then
	populated_embedding_medium="true"
	if [ ! -z "${populated_tissue_fixative}" ]
	then
		echo >>"${TMPJSONFILE}" "		      ,"
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
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"9265001\", \"csd\" : \"SCT\", \"cm\" : \"Specimen processing\" }"
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"430863003\", \"csd\" : \"SCT\", \"cm\" : \"Embedding medium\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"311731000\", \"csd\" : \"SCT\", \"cm\" : \"Paraffin wax\" }"
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
elif [ ! -z "${embedding_medium}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized embedding_medium ${embedding_medium}"
fi
if [ "${staining_method}" = "Hematoxylin and Eosin Staining Method" -o "${staining_method}" = "Wright-Giemsa Staining Method" ]
then
	populated_staining_method="true"
	if [ ! -z "${populated_tissue_fixative}" -o ! -z "${populated_embedding_medium}" ]
	then
		echo >>"${TMPJSONFILE}" "		      ,"
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
	echo >>"${TMPJSONFILE}" "			      }"
	if [ "${staining_method}" = "Hematoxylin and Eosin Staining Method" ]
	then
		echo >>"${TMPJSONFILE}" "			      ,"
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
	elif [ "${staining_method}" = "Wright-Giemsa Staining Method" ]
	then
		echo >>"${TMPJSONFILE}" "			      ,"
		echo >>"${TMPJSONFILE}" "			      {"
		echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
		echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
		echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"373682001\", \"csd\" : \"SCT\", \"cm\" : \"wright stain\" }"
		echo >>"${TMPJSONFILE}" "			      },"
		echo >>"${TMPJSONFILE}" "			      {"
		echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
		echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
		echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"373646006\", \"csd\" : \"SCT\", \"cm\" : \"giemsa stain\" }"
		echo >>"${TMPJSONFILE}" "			      }"
	fi
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
elif [ ! -z "${staining_method}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized staining_method ${staining_method}"
fi
if [ ! -z "${anatomycodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	    ],"
	if [ -z "${lateralitycodevalue}" -a -z "${anatomymodifiercodevalue}" -a -z "${tissuetypecodevalue}" ]
	then
		echo >>"${TMPJSONFILE}" "	    \"PrimaryAnatomicStructureSequence\" : { \"cv\" : \"${anatomycodevalue}\", \"csd\" : \"${anatomycsd}\", \"cm\" : \"${anatomycodemeaning}\" }"
	else
		echo >>"${TMPJSONFILE}" "	    \"PrimaryAnatomicStructureSequence\" : ["
		echo >>"${TMPJSONFILE}" "	      {"
		echo >>"${TMPJSONFILE}" "	   		\"CodeValue\" : \"${anatomycodevalue}\","
		echo >>"${TMPJSONFILE}" "	   		\"CodingSchemeDesignator\" : \"${anatomycsd}\","
		echo >>"${TMPJSONFILE}" "	   		\"CodeMeaning\" : \"${anatomycodemeaning}\","
		echo >>"${TMPJSONFILE}" "	   		\"PrimaryAnatomicStructureModifierSequence\" : ["
		if [ ! -z "${lateralitycodevalue}" ]
		then
			echo >>"${TMPJSONFILE}" "	      {"
			echo >>"${TMPJSONFILE}" "	   		\"CodeValue\" : \"${lateralitycodevalue}\","
			echo >>"${TMPJSONFILE}" "	   		\"CodingSchemeDesignator\" : \"${lateralitycsd}\","
			echo >>"${TMPJSONFILE}" "	   		\"CodeMeaning\" : \"${lateralitycodemeaning}\""
			echo >>"${TMPJSONFILE}" "	      }"
		fi
		if [ ! -z "${anatomymodifiercodevalue}" ]
		then
			if [ ! -z "${lateralitycodevalue}" ]
			then
				echo >>"${TMPJSONFILE}" "	      ,"
			fi
			echo >>"${TMPJSONFILE}" "	      {"
			echo >>"${TMPJSONFILE}" "	   		\"CodeValue\" : \"${anatomymodifiercodevalue}\","
			echo >>"${TMPJSONFILE}" "	   		\"CodingSchemeDesignator\" : \"${anatomymodifiercsd}\","
			echo >>"${TMPJSONFILE}" "	   		\"CodeMeaning\" : \"${anatomymodifiercodemeaning}\""
			echo >>"${TMPJSONFILE}" "	      }"
		fi
		if [ ! -z "${tissuetypecodevalue}" ]
		then
			if [ ! -z "${lateralitycodevalue}" -o ! -z "${anatomymodifiercodevalue}" ]
			then
				echo >>"${TMPJSONFILE}" "	      ,"
			fi
			echo >>"${TMPJSONFILE}" "	      {"
			echo >>"${TMPJSONFILE}" "	   		\"CodeValue\" : \"${tissuetypecodevalue}\","
			echo >>"${TMPJSONFILE}" "	   		\"CodingSchemeDesignator\" : \"${tissuetypecsd}\","
			echo >>"${TMPJSONFILE}" "	   		\"CodeMeaning\" : \"${tissuetypecodemeaning}\""
			echo >>"${TMPJSONFILE}" "	      }"
		fi
		echo >>"${TMPJSONFILE}" "	   		]"
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

# transfersyntaxargs derivation copied from htantodcm.sh (as of 2022/06/20) (which is why the unused 16-bit if grayscale stuff is present) ...
firstifdcompression=`tiffinfo "${infile}" | grep 'Compression Scheme' | sed -e 's/  Compression Scheme: //' | head -1`
echo "firstifdcompression=${firstifdcompression}"

if [ "${firstifdcompression}" = "None" -o "${firstifdcompression}" = "LZW" ]
then
	# do J2k reversible if 8-bit whether RGB or grayscale, 16-bit if grayscale, but only if too large for GHC to cope (bytes in Pixeldata > 2GB)
	firstifdbitspersample=`tiffinfo "${infile}" | grep 'Bits/Sample' | sed -e 's/  Bits.Sample: //' | head -1`
	echo "firstifdbitspersample=${firstifdbitspersample}"
	firstifdsamplesperpixel=`tiffinfo "${infile}" | grep 'Samples/Pixel' | sed -e 's/  Samples.Pixel: //' | head -1`
	echo "firstifdsamplesperpixel=${firstifdsamplesperpixel}"
	#firstifdphotometric=`tiffinfo "${infile}" | grep 'Photometric Interpretation' | sed -e 's/  Photometric Interpretation: //' | head -1`
	#echo "firstifdphotometric=${firstifdphotometric}"

	#Image Width: 29879 Image Length: 22448
	firstifdimagewidth=`tiffinfo "${infile}" | grep 'Image Width:' | sed -e 's/^.*Image Width: \([0-9][0-9]*\).*$/\1/' | head -1`
	echo "firstifdimagewidth=${firstifdimagewidth}"
	firstifdimagelength=`tiffinfo "${infile}" | grep 'Image Length:' | sed -e 's/^.*Image Length: \([0-9][0-9]*\).*$/\1/' | head -1`
	echo "firstifdimagelength=${firstifdimagelength}"

	#pixeldatasizeinbytesrel2gb=`echo "scale=0; ${firstifdbitspersample} / 8 * ${firstifdsamplesperpixel} * ${firstifdimagewidth} * ${firstifdimagelength} / 2147483648" | bc -l`
	# Google limit is 2GiB not 2GB
	pixeldatasizeinbytesrel2gb=`echo "scale=0; ${firstifdbitspersample} / 8 * ${firstifdsamplesperpixel} * ${firstifdimagewidth} * ${firstifdimagelength} / 2000000000" | bc -l`
	echo "pixeldatasizeinbytesrel2gb=${pixeldatasizeinbytesrel2gb}"

	if [ ${pixeldatasizeinbytesrel2gb} -gt 0 ]
	then
		echo "Uncompressed or LZW compressed and when decompressed is greater than or equal to 2GB"
		if [ "${firstifdbitspersample}" = "8" ]
		then
			echo "Uncompressed or LZW compressed 8 bit so requesting J2K Reversible compression"
			transfersyntaxargs="1.2.840.10008.1.2.4.90"
			# cannot guarantee compressed bitstream will fit in BOT so use EOT
			offsettableargs="ADDEXTENDEDOFFSETTABLE DONOTADDBASICOFFSETTABLE"
		elif [ "${firstifdsamplesperpixel}" = "1" -a "${firstifdbitspersample}" = "16" ]
		then
			echo "Uncompressed or LZW compressed single channel 16 bit so requesting J2K Reversible compression"
			transfersyntaxargs="1.2.840.10008.1.2.4.90"
			# cannot guarantee compressed bitstream will fit in BOT so use EOT
			offsettableargs="ADDEXTENDEDOFFSETTABLE DONOTADDBASICOFFSETTABLE"
		fi
	else
		echo "Uncompressed or LZW compressed and when decompressed is less than 2GB"
		# do not set offsettableargs
	fi
else
	# can assume compressed
	totalfilesizeinbytes=`ls -l "${infile}" | awk '{print $5}'`
	echo "totalfilesizeinbytes=${totalfilesizeinbytes}"
	totalfilesizeinbytesrel4gb=`echo "scale=0; ${totalfilesizeinbytes} / 4294967296" | bc -l`
	echo "totalfilesizeinbytesrel4gb=${totalfilesizeinbytesrel4gb}"
	if [ ${totalfilesizeinbytesrel4gb} -gt 0 ]
	then
		echo "Likely greater than 4GB so use EOT"
		offsettableargs="ADDEXTENDEDOFFSETTABLE DONOTADDBASICOFFSETTABLE"
	else
		echo "Less than 4GB so use BOT"
		offsettableargs="ADDBASICOFFSETTABLE DONOTADDEXTENDEDOFFSETTABLE"
	fi
fi
echo "transfersyntaxargs=${transfersyntaxargs}"
echo "offsettableargs=${offsettableargs}"

#rm "${TMPJSONFILE}"; exit 1

rm -rf "${outdir}"
mkdir -p "${outdir}"
date
# ${PATHTOADDITIONAL}/jai_imageio.jar:${PATHTOADDITIONAL}/jai_imageio-1_1/lib/clibwrapper_jiio.jar not needed if installed in JRE
java -cp ${PIXELMEDDIR}/pixelmed.jar:${PATHTOADDITIONAL}/javax.json-1.0.4.jar:${PATHTOADDITIONAL}/opencsv-2.4.jar \
	-Djava.awt.headless=true \
	-XX:-UseGCOverheadLimit \
	-Xmx8g \
	${JAVATMPDIRARG} \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.TIFFToDicom=debug \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.AddTIFFOrOffsetTables=info \
	com.pixelmed.convert.TIFFToDicom \
	"${TMPJSONFILE}" \
	"${infile}" \
	"${outdir}/DCM" \
	SM 1.2.840.10008.5.1.4.1.1.77.1.6 \
	${transfersyntaxargs} \
	${offsettableargs} \
	ADDTIFF MERGESTRIPS DONOTADDDCMSUFFIX INCLUDEFILENAME
# do NOT use ADDPYRAMID since upsets BioFormats :(
date
rm "${TMPJSONFILE}"
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
