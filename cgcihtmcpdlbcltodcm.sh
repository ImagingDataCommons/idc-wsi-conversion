#!/bin/sh
#
# Usage: ./cgcihtmcpdlbcltodcm.sh filename.svs [outdir]

# #### DEPENDS ON csvtool installed (pip3 install.csvtool) and in path (e.g., "~/Library/Python/3.9/bin")

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

# make sure have performed dos2unix ICD-O-3.2_final_update09102020.csv so that CR is not included in extracted text
ICDOFILE="ICD-O-3.2_final_update09102020.csv"

METADATABASE="project-cgci-htmcp-dlbcl.2026-02-15"

#ls -l "biospecimen.${METADATABASE}"

TSVFILENAMEFORSAMPLE="biospecimen.${METADATABASE}/sample.tsv"
if [ ! -f "${TSVFILENAMEFORSAMPLE}" ]
then
	echo 1>&2 "Error: no sample metadata CSV file called ${TSVFILENAMEFORSAMPLE}"
	exit 1
fi

TSVFILENAMEFORPORTION="biospecimen.${METADATABASE}/portion.tsv"
if [ ! -f "${TSVFILENAMEFORPORTION}" ]
then
	echo 1>&2 "Error: no portion metadata CSV file called ${TSVFILENAMEFORPORTION}"
	exit 1
fi

TSVFILENAMEFORSLIDE="biospecimen.${METADATABASE}/slide.tsv"
if [ ! -f "${TSVFILENAMEFORSLIDE}" ]
then
	echo 1>&2 "Error: no slide metadata CSV file called ${TSVFILENAMEFORSLIDE}"
	exit 1
fi

#ls -l "clinical.${METADATABASE}"

TSVFILENAMEFORCLINICAL="clinical.${METADATABASE}/clinical.tsv"
if [ ! -f "${TSVFILENAMEFORCLINICAL}" ]
then
	echo 1>&2 "Error: no clinical metadata CSV file called ${TSVFILENAMEFORCLINICAL}"
	exit 1
fi

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="HTMCPDLBCLspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="HTMCPDLBCLstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="HTMCPDLBCLstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="idc-conversion-outputs-htcmp-old_tabulateduids_no_FoR.csv"
TMPSLIDEUIDFILE="slideuid.csv"

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

dicomclinicaltrialcoordinatingcentername="NCI Genomic Data Commons (GDC)"
dicomclinicaltrialsponsorname="Cancer Genome Characterization Initiative (CGCI)"
dicomclinicalprotocolid="phs000529"
issuerofdicomclinicalprotocolid="dbGaP"
# project.project_id
dicomclinicalprotocolid="CGCI-HTMCP-DLBCL"
# "CGCI HIV+ Tumor Molecular Characterization - Diffuse Large B-Cell Lymphoma" is too long
dicomclinicalprotocolname="CGCI HIV+ Tumor MC - Diffuse Large B-Cell Lymphoma"
doiclinicalprotocolid="10.5281/zenodo.17381412"
dicomclinicaltrialsiteid=""

# "cgci_htmcp_dlbcl_pathology_data/HTMCP-01-01-00451-01-HE.CA064103-F322-42CC-AD7A-987DAF276BFB.svs"

# do not remove suffix '.svs' from filename
filename=`basename "${infile}"`
echo "filename = ${filename}"

# want slides.submitter_id not slides.slide_id (the latter being only a UUID rather than what is in filename)
# slides.slide_id CA064103-F322-42CC-AD7A-987DAF276BFB
# slides.submitter_id HTMCP-01-01-00451-01-HE
# may have lower case in stain name
slide_id=`echo "${filename}" | sed -e 's/^\([A-Za-z0-9-]*\)[.].*$/\1/'`
# slide_id = HTMCP-01-01-00451-01-HE

echo "slide_id = ${slide_id}"

if [ -z "${outdir}" ]
then
	outdir="Converted/${slide_id}"
fi
echo "outdir = ${outdir}"

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

if [ -f "${TSVFILENAMEFORSLIDE}" ]
then
	# HTMCP-01-01-00451-01-HE
	# using \t as delimited works here on MacOS but not Linux so use actually tab character in editor ...
	tsvlineforslide=`grep "	${slide_id}	" "${TSVFILENAMEFORSLIDE}" | head -1`
	echo "tsvlineforslide = ${tsvlineforslide}"
fi

# getcolumnfromtsvheader key tsvfilename
# returns value in ${column}
getcolumnfromtsvheader()
{
	key="$1"
	#echo "key = ${key}"
	shift
	tsvfilename="$1"
	#echo "tsvfilename = ${tsvfilename}"
	
	# take care to delimit key when searching, since some may be partial component of longer key names ...
	column=`head -1 "${tsvfilename}" | tr '\t' '\n' | nl | egrep "\s${key}\$" | csvtool -d '	' -c 1`
	#echo "column = ${column}"
}

if [ -z "${tsvlineforslide}" ]
then
	echo 1>&2 "Warning: cannot find metadata CSV file entry for filename ${filename}"
else
	# no idea why '\t' and '\\t' don't work as csvtool argument for delimiter, but they don't ...
	getcolumnfromtsvheader "cases.submitter_id" "${TSVFILENAMEFORSLIDE}"
	patient_id=`echo "${tsvlineforslide}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "patient_id = ${patient_id}"
	
	getcolumnfromtsvheader "samples.submitter_id" "${TSVFILENAMEFORSLIDE}"
	sample_id=`echo "${tsvlineforslide}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "sample_id = ${sample_id}"
	
	# portions.submitter_id is not populated but portions.portion_id (the UUID) is
	#getcolumnfromtsvheader "portions.submitter_id" "${TSVFILENAMEFORSLIDE}"
	getcolumnfromtsvheader "portions.portion_id" "${TSVFILENAMEFORSLIDE}"
	portion_id=`echo "${tsvlineforslide}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "portion_id = ${portion_id}"
	
	# could get derived values for slide too, like "slides.percent_lymphocyte_infiltration" :(
fi

dicomclinicaltrialsubjectid="${patient_id}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

if [ -f "${TSVFILENAMEFORCLINICAL}" ]
then
	# each participant may have multiple rows (e.g., for each treatment type)

	tsvlineforclinical=`grep "	${patient_id}	" "${TSVFILENAMEFORCLINICAL}" | head -1`
	echo "tsvlineforclinical = ${tsvlineforclinical}"
fi

if [ -z "${tsvlineforclinical}" ]
then
	echo 1>&2 "Warning: cannot find participant metadata CSV file entry for patient_id ${patient_id} from which to extract patient characteristics"
else
	getcolumnfromtsvheader "demographic.age_at_index" "${TSVFILENAMEFORCLINICAL}"
	age=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "age = ${age}"

	getcolumnfromtsvheader "demographic.race" "${TSVFILENAMEFORCLINICAL}"
	race=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "race = ${race}"

	getcolumnfromtsvheader "demographic.ethnicity" "${TSVFILENAMEFORCLINICAL}"
	ethnicity=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "ethnicity = ${ethnicity}"

	getcolumnfromtsvheader "demographic.gender" "${TSVFILENAMEFORCLINICAL}"
	gender=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "gender = ${gender}"

	getcolumnfromtsvheader "cases.primary_site" "${TSVFILENAMEFORCLINICAL}"
	primary_site=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "primary_site = ${primary_site}"

	getcolumnfromtsvheader "diagnoses.primary_diagnosis" "${TSVFILENAMEFORCLINICAL}"
	diagnosis=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "diagnosis = ${diagnosis}"

	# diagnoses.morphology actually seems to always be an ICD-O-3 code
	getcolumnfromtsvheader "diagnoses.morphology" "${TSVFILENAMEFORCLINICAL}"
	diagnosis_morphology=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "diagnosis_morphology = ${diagnosis_morphology}"

	getcolumnfromtsvheader "diagnoses.tissue_or_organ_of_origin" "${TSVFILENAMEFORCLINICAL}"
	origin_site=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "origin_site = ${origin_site}"

	getcolumnfromtsvheader "diagnoses.sites_of_involvement" "${TSVFILENAMEFORCLINICAL}"
	involvement_site=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "involvement_site = ${involvement_site}"

	getcolumnfromtsvheader "diagnoses.site_of_resection_or_biopsy" "${TSVFILENAMEFORCLINICAL}"
	anatomic_site=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "anatomic_site = ${anatomic_site}"

	getcolumnfromtsvheader "diagnoses.laterality" "${TSVFILENAMEFORCLINICAL}"
	laterality=`echo "${tsvlineforclinical}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "laterality = ${laterality}"
	
fi

diagnosisdescription=""
dicomdiagnosisdescription=""
additionalpatienthistory=""
diagnosiscodevalue=""
diagnosiscsd=""
diagnosiscodemeaning=""

# all the primary_diagnosis string values observed seem to match ICDO-O-3 preferred terms
if [ ! -z "${diagnosis}" ]
then
	if [ "${diagnosis}" != "Not Reported" ]
	then
		# quoted quote \0x22 does not work
		diagnosiscodevalue=`grep -i ",\"${diagnosis}\"," "${ICDOFILE}" | grep ',Preferred,' | head -1 | awk -F, '{print $1}'`
		echo "checking Preferred quoted diagnosiscodevalue = ${diagnosiscodevalue} in ICD file for ${diagnosis}"
		if [ -z "${diagnosiscodevalue}" ]
		then
			diagnosiscodevalue=`grep -i ",${diagnosis}," "${ICDOFILE}" | grep ',Preferred,' | head -1 | awk -F, '{print $1}'`
			echo "checking Preferred unquoted diagnosiscodevalue = ${diagnosiscodevalue} in ICD file for ${diagnosis}"
			if [ -z "${diagnosiscodevalue}" ]
			then
				diagnosiscodevalue=`grep -i ",\"${diagnosis}\"," "${ICDOFILE}" | grep ',Synonym,' | head -1 | awk -F, '{print $1}'`
				echo "checking Synonym quoted diagnosiscodevalue = ${diagnosiscodevalue} in ICD file for ${diagnosis}"
				if [ -z "${diagnosiscodevalue}" ]
				then
					diagnosiscodevalue=`grep -i ",${diagnosis}," "${ICDOFILE}" | grep ',Synonym,' | head -1 | awk -F, '{print $1}'`
					echo "checking Synonym unquoted diagnosiscodevalue = ${diagnosiscodevalue} in ICD file for ${diagnosis}"
				fi
			fi
		fi
		# do not attempt to match Preferred or Synonym ${diagnosis} value without leading delimiter, else get incorrect matches
	fi
	
	if [ ! -z "${diagnosiscodevalue}" ]
	then
		echo "found diagnosiscodevalue = ${diagnosiscodevalue} in ICD file for ${diagnosis}"
		diagnosiscsd="ICDO3"
		
		# may be multiple Preferred entries for same code, so use head -1
		# make sure to match code at beginning of line, not in meaning (as in 'except ...')
		diagnosiscodemeaning=`egrep "^${diagnosiscodevalue},Preferred" "${ICDOFILE}" | head -1 | csvtool -c 3 | tr -d '"'`
		echo "found diagnosiscodemeaning = ${diagnosiscodemeaning}"
		
		if [ ! -z "${diagnosis_morphology}" ]
		then
			if [ "${diagnosis_morphology}" != "${diagnosiscodevalue}" ]
			then
				echo 1>&2 "Warning: ${diagnosiscodevalue} derived from primary_diagnosis string values does not match diagnosis_morphology ${diagnosis_morphology}"
			fi
		fi
	fi
fi

if [ -z "${diagnosiscodevalue}" ]
then
	if [ ! -z "${diagnosis_morphology}" -a "${diagnosis_morphology}" != "Not Reported" ]
	then
		echo "No diagnosis code derived from primary_diagnosis string value, so using diagnosis_morphology ${diagnosis_morphology}"
		diagnosiscodevalue="${diagnosis_morphology}"
		diagnosiscsd="ICDO3"
		diagnosiscodemeaning=`egrep "^${diagnosis_morphology},Preferred" "${ICDOFILE}" | head -1 | csvtool -c 3 | tr -d '"'`
		echo "found diagnosiscodemeaning = ${diagnosiscodemeaning}"
	fi
fi

if [ ! -z "${diagnosiscodevalue}" -a -z "${diagnosiscodemeaning}" ]
then
	echo 1>&2 "Warning: empty diagnosiscodemeaning for ${diagnosiscodevalue} for slide_id ${slide_id} (diagnosis = ${diagnosis})"
fi

# not checking diagnosiscodemeaning for length wrt. VR LO since known to be <= 64 :(

if [ -z "${diagnosisdescription}" ]
then
	diagnosisdescription="${diagnosiscodemeaning}"
fi

echo "diagnosiscodevalue = ${diagnosiscodevalue}"
echo "diagnosiscsd = ${diagnosiscsd}"
echo "diagnosiscodemeaning = ${diagnosiscodemeaning}"
echo "diagnosisdescription = ${diagnosisdescription}"

dicomdiagnosisdescription="${diagnosisdescription}"

# not checking diagnosisdescription for length wrt. VR LO since known to be <= 64 :(
# not using additionalpatienthistory since diagnosisdescription known to fit in VR LO :(

anatomycodevalue=""
anatomycsd=""
anatomycodemeaning=""
lateralitycodevalue=""
lateralitycsd=""
lateralitycodemeaning=""
anatomymodifiercodevalue=""
anatomymodifiercsd=""
anatomymodifiercodemeaning=""

# not really sure if we should exclude "Unknown primary site" in fall back logic, but for HCM-CSHL-0654-C26 leads to lymph node
if [ -z "${anatomic_site}" -o "${anatomic_site}" = "Not Reported" -o "${anatomic_site}" = "Unknown" -o "${anatomic_site}" = "Unknown primary site" ]
then
	echo "Using origin_site ${origin_site} for anatomic_site that is empty or Not Reported or Unknown or Unknown primary site"
	anatomic_site="${origin_site}"
fi

if [ -z "${anatomic_site}" -o "${anatomic_site}" = "Not Reported" -o "${anatomic_site}" = "Unknown" -o "${anatomic_site}" = "Unknown primary site" ]
then
	echo "Using primary_site ${primary_site} for anatomic_site that is empty or Not Reported or Unknown or Unknown primary site"
	anatomic_site="${primary_site}"
fi

# use involvement last because it is usually empty and often multiple :(
if [ -z "${anatomic_site}" -o "${anatomic_site}" = "Not Reported" -o "${anatomic_site}" = "Unknown" -o "${anatomic_site}" = "Unknown primary site" ]
then
	echo "Using involvement_site ${involvement_site} for aanatomic_site that is empty or Not Reported or Unknown or Unknown primary site"
	anatomic_site="${involvement_site}"
fi

if [ ! -z "${anatomic_site}" ]
then
	if   [ "${anatomic_site}" = "Bone, NOS" ]
	then
		anatomycodevalue="272673000"
		anatomycsd="SCT"
		anatomycodemeaning="Bone"
	elif [ "${anatomic_site}" = "Brain, NOS" ]
	then
		anatomycodevalue="12738006"
		anatomycsd="SCT"
		anatomycodemeaning="Brain"
	elif [ "${anatomic_site}" = "Kidney, NOS" ]
	then
		anatomycodevalue="64033007"
		anatomycsd="SCT"
		anatomycodemeaning="Kidney"
	elif [ "${anatomic_site}" = "Liver" ]
	then
		anatomycodevalue="10200004"
		anatomycsd="SCT"
		anatomycodemeaning="Liver"
	elif [ "${anatomic_site}" = "Lymph node, NOS" ]
	then
		anatomycodevalue="59441001"
		anatomycsd="SCT"
		anatomycodemeaning="Lymph node"
	elif [ "${anatomic_site}" = "Oropharynx, NOS" ]
	then
		anatomycodevalue="31389004"
		anatomycsd="SCT"
		anatomycodemeaning="Oropharynx"
	elif [ "${anatomic_site}" = "Pleura, NOS" ]
	then
		anatomycodevalue="3120008"
		anatomycsd="SCT"
		anatomycodemeaning="Pleura"
	elif [ "${anatomic_site}" = "Uterus, NOS" ]
	then
		anatomycodevalue="35039007"
		anatomycsd="SCT"
		anatomycodemeaning="Uterus"
	elif [ "${anatomic_site}" = "Hematopoietic system, NOS" ]
	then
		anatomycodevalue="57171008"
		anatomycsd="SCT"
		anatomycodemeaning="Hematopoietic system"
	elif [ "${anatomic_site}" = "Hematopoietic and reticuloendothelial systems" ]
	then
		anatomycodevalue="110711007"
		anatomycsd="SCT"
		anatomycodemeaning="Hematopoietic and reticuloendothelial systems"
	elif [ "${anatomic_site}" = "Skin, NOS" ]
	then
		anatomycodevalue="39937001"
		anatomycsd="SCT"
		anatomycodemeaning="Skin"
	elif [ "${anatomic_site}" = "Other ill-defined sites" ]
	then
		echo 1>&2 "Warning: anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
		# fall through to generic unknown/unrecognized handling
	elif [ "${anatomic_site}" = "Not Reported" ]
	then
		echo 1>&2 "Warning: anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
		# fall through to generic unknown/unrecognized handling
	elif [ "${anatomic_site}" = "Unknown" ]
	then
		echo 1>&2 "Warning: anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
		# fall through to generic unknown/unrecognized handling
	else
		echo 1>&2 "Warning: unrecognized anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
		# fall through to generic unknown/unrecognized handling
	fi
fi
	
if [ -z "${anatomycodevalue}" ]
then
	# do not like using unspecified, but want to include the tissue type as a modifer, so need parent :(
	anatomycodevalue="10003008"
	anatomycsd="SCT"
	anatomycodemeaning="Unspecified"
fi

if [ "${laterality}" = "Left" ]
then
	lateralitycodevalue="7771000"
	lateralitycsd="SCT"
	lateralitycodemeaning="Left"
elif [ "${laterality}" = "Right" ]
then
	lateralitycodevalue="24028007"
	lateralitycsd="SCT"
	lateralitycodemeaning="Right"
#else don't bother checking for "Unknown" or "'--"
fi

echo "anatomycodemeaning = ${anatomycodemeaning}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

if [ -f "${TSVFILENAMEFORSAMPLE}" ]
then
	tsvlineforsample=`grep "	${sample_id}	" "${TSVFILENAMEFORSAMPLE}" | head -1`
	echo "tsvlineforsample = ${tsvlineforsample}"
fi

if [ ! -z "${tsvlineforsample}" ]
then
	getcolumnfromtsvheader "samples.is_ffpe" "${TSVFILENAMEFORSAMPLE}"
	is_ffpe=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "is_ffpe = ${is_ffpe}"
	
	# samples.oct_embedded is always FALSE
	getcolumnfromtsvheader "samples.oct_embedded" "${TSVFILENAMEFORSAMPLE}"
	oct_embedded=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "oct_embedded = ${oct_embedded}"
	
	# samples.preservation_method values are "Snap Frozen" or "FFPE"
	getcolumnfromtsvheader "samples.preservation_method" "${TSVFILENAMEFORSAMPLE}"
	preservation_method=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "preservation_method = ${preservation_method}"
	
	getcolumnfromtsvheader "samples.sample_type" "${TSVFILENAMEFORSAMPLE}"
	sample_type=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "sample_type = ${sample_type}"
	
	getcolumnfromtsvheader "samples.specimen_type" "${TSVFILENAMEFORSAMPLE}"
	specimen_type=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "specimen_type = ${specimen_type}"
	
	# samples.tissue_type values are "Normal" or "Tumor"
	getcolumnfromtsvheader "samples.tissue_type" "${TSVFILENAMEFORSAMPLE}"
	tissue_type=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "tissue_type = ${tissue_type}"
fi

fixation=""
if [ "${preservation_method}" = "FFPE" ]
then
	fixation="FFPE"
elif [ "${preservation_method}" = "Frozen" ]
then
	# not "OCT" sinces amples.oct_embedded is always FALSE, and don't know what freezing method was used :(
	fixation="FZ"
fi

if [ -z "${fixation}" ]
then
	if [ "${is_ffpe}" = "TRUE" -o "${is_ffpe}" = "true" ]
	then
		fixation="FFPE"
	elif [ "${is_ffpe}" = "FALSE" -o "${is_ffpe}" = "false" ]
	then
		fixation="FZ"
	fi
fi

if [ -z "${fixation}" ]
then
	if [ -f "${TSVFILENAMEFORPORTION}" ]
	then
		tsvlineforportion=`grep "	${portion_id}	" "${TSVFILENAMEFORPORTION}" | head -1`
		echo "tsvlineforportion = ${tsvlineforportion}"

		if [ ! -z "${tsvlineforportion}" ]
		then
			getcolumnfromtsvheader "portions.is_ffpe" "${TSVFILENAMEFORPORTION}"
			is_ffpe=`echo "${tsvlineforportion}" | csvtool -d '	' -c ${column} | tr -d '"'`
			echo "is_ffpe from portion = ${is_ffpe}"
			if [ "${is_ffpe}" = "TRUE" -o "${is_ffpe}" = "true" ]
			then
				fixation="FFPE"
			fi
		fi
	fi
fi

echo "fixation = ${fixation}"

# not in metadata, seems to be in slide_id from filenames (e.g., "HTMCP-02-31-01244-01-HE")
staining=`echo ${slide_id} | sed -e 's/^HTMCP-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][[0-9][0-9]-[0-9][0-9][-_]\([A-Za-z][A-Za-z0-9-]*\)$/\1/'`

echo "staining = ${staining}"

stain1codevalue=""
stain1csd=""
stain1codemeaning=""
stain2codevalue=""
stain2csd=""
stain2codemeaning=""
stainshortdescription="${staining}"

if   [ "${staining}" = "BCL2" ]
then
	stain1codevalue="33054-8"
	stain1csd="LN"
	stain1codemeaning="BCL2 Ag Immune stain"
elif [ "${staining}" = "BCL6" ]
then
	stain1codevalue="47009-6"
	stain1csd="LN"
	stain1codemeaning="BCL6 Ag Immune stain"
elif [ "${staining}" = "CD10" ]
then
	stain1codevalue="40551-4"
	stain1csd="LN"
	stain1codemeaning="CD10 Ag Immune stain"
elif [ "${staining}" = "CD138" ]
then
	stain1codevalue="50309-4"
	stain1csd="LN"
	stain1codemeaning="CD138 Ag Immune stain"
elif [ "${staining}" = "CD20" ]
then
	stain1codevalue="10438-0"
	stain1csd="LN"
	stain1codemeaning="CD20 Ag Immune stain"
elif [ "${staining}" = "CD3" ]
then
	stain1codevalue="10439-8"
	stain1csd="LN"
	stain1codemeaning="CD3 Ag Immune stain"
elif [ "${staining}" = "CD79a" ]
then
	stain1codevalue="47018-7"
	stain1csd="LN"
	stain1codemeaning="CD79a Ag Immune stain"
elif [ "${staining}" = "EBER" ]
then
	stain1codevalue="68466-2"
	stain1csd="LN"
	stain1codemeaning="Epstein-Barr virus-encoded RNA (EBER) probe"
elif [ "${staining}" = "HE" -o "${staining}" = "S1-HE" -o "${staining}" = "S2-HE" ]
then
	stain1codevalue="12710003"
	stain1csd="SCT"
	stain1codemeaning="hematoxylin stain"
	stain2codevalue="36879007"
	stain2csd="SCT"
	stain2codemeaning="water soluble eosin stain"
elif [ "${staining}" = "INT" ]
then
	stain1codevalue="C013574"
	stain1csd="MSH"
	stain1codemeaning="Iodonitrotetrazolium"
elif [ "${staining}" = "Ki67" ]
then
	stain1codevalue="29593-1"
	stain1csd="LN"
	stain1codemeaning="Ki-67 nuclear Ag Immune stain"
elif [ "${staining}" = "MUM1" ]
then
	stain1codevalue="315003"
	stain1csd="99PMP"
	stain1codemeaning="IRF4/MUM1 Ag Immune stain"
elif [ "${staining}" = "TP53" ]
then
	stain1codevalue="14229-9"
	stain1csd="LN"
	stain1codemeaning="P53 protein Ag Immune stain"
else
	echo 1>&2 "Warning: unrecognized staining \"${staining}\" for slide_id ${slide_id}"
fi

tissuetypecodevalue=""
tissuetypecsd=""
tissuetypecodemeaning=""
tissuetypeshortdescription=""

if [ "${tissue_type}" = "Normal" ]
then
	tissuetypecodevalue="17621005"
	tissuetypecsd="SCT"
	tissuetypecodemeaning="Normal"
	tissuetypeshortdescription="N"
elif [ "${tissue_type}" = "Tumor" ]
then
	# don't know if it is primary or secondary
	tissuetypecodevalue="108369006"
	tissuetypecsd="SCT"
	tissuetypecodemeaning="Tumor"
	tissuetypeshortdescription="T"
fi

dicomspecimenshortdescription="${fixation} ${stainshortdescription} ${tissuetypeshortdescription}"
echo "dicomspecimenshortdescription = ${dicomspecimenshortdescription}"

dicomseriesdescription="${dicomspecimenshortdescription}"
echo "dicomseriesdescription = ${dicomseriesdescription}"

dicompatientid="${patient_id}"
dicompatientname="${dicompatientid}"

# patient_id may be too long for SH VR of StudyID and AccessionNumber, e.g., "HCM-BROD-0048-C71" is 17 chars
dicomstudyid=`echo "${patient_id}" | tr -d '-'`
dicomaccessionnumber="${dicomstudyid}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

dicomspecimenuid=""
if [ ! -f "${FILEMAPPINGSPECIMENIDTOUID}" ]
then
	touch "${FILEMAPPINGSPECIMENIDTOUID}"
fi

dicomspecimenidentifier="${sample_id}"
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

echo "dicomspecimenidentifier = ${dicomspecimenidentifier}"
echo "dicomspecimenuid = ${dicomspecimenuid}"

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
if [ "${gender}" = "male" ]
then
	dicomsex="M"
elif [ "${gender}" = "female" ]
then
	dicomsex="F"
fi
echo "dicomsex = ${dicomsex}"

dicomage=""
if [ ! -z "${age}" -a "${age}" != "'--" ]
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
ethnicgroupcodevalue_1=""
ethnicgroupcsd_1=""
ethnicgroupcodemeaning_1=""

# SH, so limited to 16 characters
if [ "${race}" = "white" ]
then
	dicomethnicgroup="White"
	ethnicgroupcodevalue_1="413773004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Caucasian race"
elif [ "${race}" = "asian" ]
then
	dicomethnicgroup="Asian"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
elif [ "${race}" = "black or african american" ]
then
	dicomethnicgroup="Black"
	ethnicgroupcodevalue_1="413464008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="African race"
else
	echo 1>&2 "Warning: ignoring unrecognized race ${race}"
fi

echo "dicomethnicgroup = ${dicomethnicgroup}"
echo "ethnicgroupcodevalue_1 = ${ethnicgroupcodevalue_1}"
echo "ethnicgroupcsd_1 = ${ethnicgroupcsd_1}"
echo "ethnicgroupcodemeaning_1 = ${ethnicgroupcodemeaning_1}"

echo "dicompatientname = ${dicompatientname}"
echo "dicompatientid = ${dicompatientid}"
echo "dicomstudyid = ${dicomstudyid}"
echo "dicomstudyuid = ${dicomstudyuid}"
echo "dicomstudydatetime = ${dicomstudydatetime}"
echo "dicomstudydate = ${dicomstudydate}"
echo "dicomstudytime = ${dicomstudytime}"
echo "dicomstudydescription = ${dicomstudydescription}"
echo "dicomaccessionnumber = ${dicomaccessionnumber}"
echo "dicomcontaineridentifier = ${dicomcontaineridentifier}"

echo "dicomclinicaltrialcoordinatingcentername = ${dicomclinicaltrialcoordinatingcentername}"
echo "dicomclinicaltrialsponsorname = ${dicomclinicaltrialsponsorname}"
echo "dicomclinicalprotocolid = ${dicomclinicalprotocolid}"
echo "dicomclinicalprotocolname = ${dicomclinicalprotocolname}"
echo "dicomclinicaltrialsiteid = ${dicomclinicaltrialsiteid}"
echo "dicomclinicaltrialsitename = ${dicomclinicaltrialsitename}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

echo "dicominstitutionname = ${dicominstitutionname}"

echo "anatomycodevalue = ${anatomycodevalue}"
echo "anatomycsd = ${anatomycsd}"
echo "anatomycodemeaning = ${anatomycodemeaning}"

echo "lateralitycodevalue = ${lateralitycodevalue}"
echo "lateralitycsd = ${lateralitycsd}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"

echo "anatomymodifiercodevalue = ${anatomymodifiercodevalue}"
echo "anatomymodifiercsd = ${anatomymodifiercsd}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"


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
if [ ! -z "${additionalpatienthistory}" ]
then
	echo >>"${TMPJSONFILE}" "		\"AdditionalPatientHistory\" : \"${additionalpatienthistory}\","
fi
if [ ! -z "${dicomdiagnosisdescription}" ]
then
	echo >>"${TMPJSONFILE}" "		\"AdmittingDiagnosesDescription\" : \"${dicomdiagnosisdescription}\","
fi
if [ ! -z "${diagnosiscodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "		\"AdmittingDiagnosesCodeSequence\" : { \"cv\" : \"${diagnosiscodevalue}\", \"csd\" : \"${diagnosiscsd}\", \"cm\" : \"${diagnosiscodemeaning}\" },"
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
if [ ! -z "${ethnicgroupcodevalue_1}" ]
then
	if [ ! -z "${ethnicgroupcodevalue_2}" ]
	then
		if [ ! -z "${ethnicgroupcodevalue_3}" ]
		then
			echo >>"${TMPJSONFILE}" "		\"EthnicGroupCodeSequence\" : ["
			echo >>"${TMPJSONFILE}" "			{"
			echo >>"${TMPJSONFILE}" "				\"CodeValue\" : \"${ethnicgroupcodevalue_1}\","
			echo >>"${TMPJSONFILE}" "				\"CodingSchemeDesignator\" : \"${ethnicgroupcsd_1}\","
			echo >>"${TMPJSONFILE}" "				\"CodeMeaning\" : \"${ethnicgroupcodemeaning_1}\""
			echo >>"${TMPJSONFILE}" "			},"
			echo >>"${TMPJSONFILE}" "			{"
			echo >>"${TMPJSONFILE}" "				\"CodeValue\" : \"${ethnicgroupcodevalue_2}\","
			echo >>"${TMPJSONFILE}" "				\"CodingSchemeDesignator\" : \"${ethnicgroupcsd_2}\","
			echo >>"${TMPJSONFILE}" "				\"CodeMeaning\" : \"${ethnicgroupcodemeaning_2}\""
			echo >>"${TMPJSONFILE}" "			},"
			echo >>"${TMPJSONFILE}" "			{"
			echo >>"${TMPJSONFILE}" "				\"CodeValue\" : \"${ethnicgroupcodevalue_3}\","
			echo >>"${TMPJSONFILE}" "				\"CodingSchemeDesignator\" : \"${ethnicgroupcsd_3}\","
			echo >>"${TMPJSONFILE}" "				\"CodeMeaning\" : \"${ethnicgroupcodemeaning_3}\""
			echo >>"${TMPJSONFILE}" "			}"
			echo >>"${TMPJSONFILE}" "		],"
		else
			echo >>"${TMPJSONFILE}" "		\"EthnicGroupCodeSequence\" : ["
			echo >>"${TMPJSONFILE}" "			{"
			echo >>"${TMPJSONFILE}" "				\"CodeValue\" : \"${ethnicgroupcodevalue_1}\","
			echo >>"${TMPJSONFILE}" "				\"CodingSchemeDesignator\" : \"${ethnicgroupcsd_1}\","
			echo >>"${TMPJSONFILE}" "				\"CodeMeaning\" : \"${ethnicgroupcodemeaning_1}\""
			echo >>"${TMPJSONFILE}" "			},"
			echo >>"${TMPJSONFILE}" "			{"
			echo >>"${TMPJSONFILE}" "				\"CodeValue\" : \"${ethnicgroupcodevalue_2}\","
			echo >>"${TMPJSONFILE}" "				\"CodingSchemeDesignator\" : \"${ethnicgroupcsd_2}\","
			echo >>"${TMPJSONFILE}" "				\"CodeMeaning\" : \"${ethnicgroupcodemeaning_2}\""
			echo >>"${TMPJSONFILE}" "			}"
			echo >>"${TMPJSONFILE}" "		],"
		fi
	else
		echo >>"${TMPJSONFILE}" "		\"EthnicGroupCodeSequence\" : { \"cv\" : \"${ethnicgroupcodevalue_1}\", \"csd\" : \"${ethnicgroupcsd_1}\", \"cm\" : \"${ethnicgroupcodemeaning_1}\" },"
	fi
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
	echo >>"${TMPJSONFILE}" "		    \"SpecimenShortDescription\" : \"${dicomspecimenshortdescription}\","
fi
if [ ! -z "${dicomspecimendetaileddescription}" ]
then
	echo >>"${TMPJSONFILE}" "			\"SpecimenDetailedDescription\" : \"${dicomspecimendetaileddescription}\","
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
elif [ "${fixation}" = "FZ" ]
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
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"433469005\", \"csd\" : \"SCT\", \"cm\" : \"Tissue freezing medium\" }"
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
fi

if [ ! -z "${stain2codevalue}" ]
then
	if [ ! -z "${fixation}" ]
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
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"${stain1codevalue}\", \"csd\" : \"${stain1csd}\", \"cm\" : \"${stain1codemeaning}\" }"
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"${stain2codevalue}\", \"csd\" : \"${stain2csd}\", \"cm\" : \"${stain2codemeaning}\" }"
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
elif [ ! -z "${stain1codevalue}" ]
then
	if [ ! -z "${fixation}" ]
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
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"424361007\", \"csd\" : \"SCT\", \"cm\" : \"Using substance\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"${stain1codevalue}\", \"csd\" : \"${stain1csd}\", \"cm\" : \"${stain1codemeaning}\" }"
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
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

#rm "${TMPJSONFILE}"; exit 1

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

if [ -d "${outdir}" ]
then
	echo 1>&2 "Warning: outdir \"${outdir}\" already exists for filename \"${filename}\""
fi

rm -rf "${outdir}"
mkdir -p "${outdir}"

#rm "${TMPJSONFILE}"; exit 1

date

# ${PATHTOADDITIONAL}/jai_imageio.jar not needed if installed in JRE
ls -l ${PATHTOADDITIONAL}/jai_imageio.jar

# for JDK >= 17, may need "--add-exports=java.base/sun.security.action=ALL-UNNAMED" if JIIO not working due to
# Exception in thread "main" java.lang.IllegalAccessError: class com.sun.media.imageioimpl.plugins.pnm.PNMImageReader (in unnamed module @0x2e39ef76) cannot access class sun.security.action.GetPropertyAction (in module java.base) because module java.base does not export sun.security.action to unnamed module @0x2e39ef76
# see "https://medium.com/@varunrathod0045/how-to-resolve-java-lang-illegalaccesserror-553ac2c83af9"
# but can't use in earlier versions else "Unrecognized option: --add-exports"
java -version
ADDEXPORTSARG=""
if [ `java -version 2>&1 | egrep '(java|openjdk) version' | awk '{print $3}' | tr -d '"' | awk -F. '{print $1}'` -ge 17 ]
then
	ADDEXPORTSARG="--add-exports=java.base/sun.security.action=ALL-UNNAMED"
fi
echo "Using ADDEXPORTSARG ${ADDEXPORTSARG}"

java -cp ${PIXELMEDDIR}/pixelmed.jar:${PATHTOADDITIONAL}/jai_imageio.jar:${PATHTOADDITIONAL}/javax.json-1.0.4.jar:${PATHTOADDITIONAL}/opencsv-2.4.jar \
	${ADDEXPORTSARG} \
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
	ADDTIFF MERGESTRIPS DONOTADDDCMSUFFIX INCLUDEFILENAME INCLUDEFILEMESSAGEDIGEST \
	${uidarg}
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
(cd "${outdir}"; dctable -describe -recurse -k TransferSyntaxUID -k FrameOfReferenceUID -k PyramidUID -k AcquisitionUID -k LossyImageCompression -k LossyImageCompressionMethod -k LossyImageCompressionRatio -k InstanceNumber -k ImageType -k FrameType -k PhotometricInterpretation -k NumberOfFrames -k Rows -k Columns -k ImagedVolumeWidth -k ImagedVolumeHeight -k ImagedVolumeDepth -k ImageOrientationSlide -k XOffsetInSlideCoordinateSystem -k YOffsetInSlideCoordinateSystem -k PixelSpacing -k ObjectiveLensPower -k PrimaryAnatomicStructureSequence -k PrimaryAnatomicStructureModifierSequence -k ClinicalTrialProtocolID DCM*)

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
