#!/bin/sh
#
# Usage: ./pdxnettodcm.sh filename.svs [outdir]

# #### DEPENDS ON csvtool installed (pip3 install csvtool) and in path (e.g., "${HOME}/Library/Python/3.9/bin")

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

# make sure have performed dos2unix ICD-O-3.2_final_update09102020.csv so that CR is not included in extracted text
#ICDOFILE="ICD-O-3.2_final_update09102020.csv"

CSVFILENAMEFORSLIDE="idc-image-metadata-cleaned-v4.csv"
if [ ! -f "${CSVFILENAMEFORSLIDE}" ]
then
	echo 1>&2 "Error: no slide metadata CSV file called ${CSVFILENAMEFORSLIDE}"
	exit 1
fi

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="PDXnetspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="PDXnetstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="PDXnetstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="idc-conversion-outputs-pdxnet-old_tabulateduids_no_FoR.csv"
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

dicomclinicaltrialcoordinatingcentername=""
dicomclinicaltrialsponsorname="NCI"

dicomclinicaltrialprotocolid="PDXnet"
issuerofdicomclinicalprotocolid=""
# "Patient-Derived Xenograft Development and Trials Center Research Network" is too long
dicomclinicaltrialprotocolname="Patient-Derived Xenograft Research Network"
doiclinicaltrialprotocolid="10.5281/zenodo.16967600"

# dataset = "pdmr"
PDXnet_PDMR_dicomclinicaltrialsiteid="PDXnet-PDMR"
PDXnet_PDMR_dicomclinicaltrialsitename="PDXnet Patient-Derived Models Repository"

# dataset = "pdmr-wgd"
PDXnet_WGD_dicomclinicaltrialsiteid="PDXnet-WGD"
PDXnet_WGD_dicomclinicaltrialsitename="PDXnet Whole-Genome Duplication"

# dataset = "pdmr-xtld"
PDXnet_XTLD_dicomclinicaltrialsiteid="PDXnet-XTLD"
PDXnet_XTLD_dicomclinicaltrialsitename="PDXnet Xenograft-Transplant Lymphoproliferative Disorder"

# "idc-source-data-pdxnet/PDMR/Dataset_PDMR/10059.svs"
# "idc-source-data-pdxnet/PDMR/Dataset_WGD/10444.svs"
# "idc-source-data-pdxnet/PDMR/Dataset_XTLD/88555.svs"

echo "infile = ${infile}"

# do not remove suffix '.svs' from filename
# matches "Image.file.name" in metadata
filename=`basename "${infile}"`
echo "filename = ${filename}"

slide_id=`basename "${filename}" .svs`
# slide_id = 10059
# the supplied SVS files encountered so far have simple numeric names, but the metadata file contains funky ones, like "WU-0122-T1_X1P1_PDX_40X.svs" and "WM3939-2_HS11-27283_1L1.svs"

echo "slide_id = ${slide_id}"

# outdir is assigned later after patientid is assigned

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

if [ -f "${CSVFILENAMEFORSLIDE}" ]
then
	# "dataset","Image.file.name","Magnification","Stain","Patient.ID","Model.ID","Sample.ID","Passage","Model.Type","Mouse.strain","Engraftment.site","Treatment.information.in.patient.tumor","Treatment.information.in.PDX.tumor","Percent.total.cellularity","Percent.tumor.content","Percent.necrotic.content","Percent.stromal.content","Percent.inflammatory.content","Other.pathology.notes","Regional.annotation.available.","Cell.annotation.available.","Staining.scanning.method.available.","Is.information.of.this.model.already.in.CGC.","Sex","Age","Race","Ethnicity","Diagnosis","Primary.cancer.site","Metastatic.site","Diagnosis.Subtype","TNM.Tumor.Stage","Tumor.Stage","Tumor.Grade","Tumor.Biomarkers","WES.Mutations","RNA.Seq..Exp.array","SNP.array","Proteomics","Metabolomics","Treatment.response","Site","Treatment.response.in.PDX.treatment"
	# "pdmr","11923.svs","20x","H&E","918122","036-R","LR0","P0","PDX","NSG","Subcutaneous","Prior 09/2012: Radiation (Stable Disease)",NA,NA,"80","0","20",NA,NA,NA,NA,NA,NA,"Male","80",NA,NA,"Fibrosarcoma - not infantile","Musculoskeletal",NA,"Myxofibrosarcoma",NA,NA,"High grade or poorly differentiated",NA,NA,NA,NA,NA,NA,NA,"PDMR",NA
	# "pdmr","10059.svs","20x","H&E","918122","036-R","ORIGINATOR",NA,"Human","NSG","Subcutaneous","Prior 09/2012: Radiation (Stable Disease)",NA,NA,"90","0","10",NA,NA,NA,NA,NA,NA,"Male","80",NA,NA,"Fibrosarcoma - not infantile","Musculoskeletal",NA,"Myxofibrosarcoma",NA,NA,"High grade or poorly differentiated",NA,NA,NA,NA,NA,NA,NA,"PDMR",NA

	# use filename with .svs, not slide_id without ...
	csvlineforslide=`fgrep ",\\"${filename}\\"," "${CSVFILENAMEFORSLIDE}" | head -1`
	echo "csvlineforslide = ${csvlineforslide}"
fi

# getcolumnfromcsvheader key csvfilename
# returns value in ${column}
getcolumnfromcsvheader()
{
	key="$1"
	#echo "key = ${key}"
	shift
	csvfilename="$1"
	#echo "csvfilename = ${csvfilename}"
	
	# take care to delimit key when searching, since some may be partial component of longer key names ...
	# take care to use tab delimiter (not comma) when getting line number that is column from output of nl command ...
	column=`head -1 "${csvfilename}" | tr ',' '\n' | tr -d '"' | nl | egrep "\s${key}\$" | csvtool -d '	' -c 1`
	#echo "column = ${column}"
}

if [ -z "${csvlineforslide}" ]
then
	echo 1>&2 "Error: cannot find metadata CSV file entry for filename ${filename}"
	exit 1
else
	getcolumnfromcsvheader "dataset" "${CSVFILENAMEFORSLIDE}"
	dataset=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "dataset = ${dataset}"
	
	getcolumnfromcsvheader "Patient.ID" "${CSVFILENAMEFORSLIDE}"
	original_patient_id=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "original_patient_id = ${original_patient_id}"
	
	getcolumnfromcsvheader "Model.ID" "${CSVFILENAMEFORSLIDE}"
	model_id=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "model_id = ${model_id}"

	getcolumnfromcsvheader "Sample.ID" "${CSVFILENAMEFORSLIDE}"
	sample_id=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "sample_id = ${sample_id}"

	getcolumnfromcsvheader "Passage" "${CSVFILENAMEFORSLIDE}"
	passage=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "passage = ${passage}"

	getcolumnfromcsvheader "Model.Type" "${CSVFILENAMEFORSLIDE}"
	model_type=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "model_type = ${model_type}"

	getcolumnfromcsvheader "Mouse.strain" "${CSVFILENAMEFORSLIDE}"
	mouse_strain=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "mouse_strain = ${mouse_strain}"

	getcolumnfromcsvheader "Stain" "${CSVFILENAMEFORSLIDE}"
	stain=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "stain = ${stain}"

	getcolumnfromcsvheader "Engraftment.site" "${CSVFILENAMEFORSLIDE}"
	engraftment_site=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "engraftment_site = ${engraftment_site}"

	getcolumnfromcsvheader "Other.pathology.notes" "${CSVFILENAMEFORSLIDE}"
	other_pathology_notes=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "other_pathology_notes = ${other_pathology_notes}"

	getcolumnfromcsvheader "Sex" "${CSVFILENAMEFORSLIDE}"
	sex=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "sex = ${sex}"

	getcolumnfromcsvheader "Age" "${CSVFILENAMEFORSLIDE}"
	age=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "age = ${age}"

	getcolumnfromcsvheader "Race" "${CSVFILENAMEFORSLIDE}"
	race=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "race = ${race}"

	getcolumnfromcsvheader "Ethnicity" "${CSVFILENAMEFORSLIDE}"
	ethnicity=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "ethnicity = ${ethnicity}"

	#getcolumnfromcsvheader "Diagnosis" "${CSVFILENAMEFORSLIDE}"
	getcolumnfromcsvheader "NCIt.Diagnosis" "${CSVFILENAMEFORSLIDE}"
	diagnosis=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "diagnosis = ${diagnosis}"
	
	if [ -z "${diagnosis}" -o "${diagnosis}" = "NA" -o "${diagnosis}" = "unknown" ]
	then
		echo "try finding diagnosis from another row for same original_patient_id and model_id"
		# preferrably the Human ORIGINATOR row
		csvlinefordiagnosis=`fgrep ",\\"${original_patient_id}\\",\\"${model_id}\\"," "${CSVFILENAMEFORSLIDE}" | fgrep ',\\"ORIGINATOR\\",' | fgrep ',\\"Human\\",' | head -1`
		echo "csvlinefordiagnosis = ${csvlinefordiagnosis}"
		if [ ! -z "${csvlinefordiagnosis}" ]
		then
			getcolumnfromcsvheader "Diagnosis" "${CSVFILENAMEFORSLIDE}"
			diagnosis=`echo "${csvlinefordiagnosis}" | csvtool -c ${column} | tr -d '"'`
			echo "diagnosis from Human ORIGINATOR = ${diagnosis}"
		else
			echo "try finding diagnosis from another row when no Human ORIGINATOR"
			getcolumnfromcsvheader "Diagnosis" "${CSVFILENAMEFORSLIDE}"
			othercsvlinefordiagnosis=`fgrep ",\\"${original_patient_id}\\",\\"${model_id}\\"," "${CSVFILENAMEFORSLIDE}"`
			if [ ! -z "${othercsvlinefordiagnosis}" ]
			then
				diagnosis=`echo "${othercsvlinefordiagnosis}" | csvtool -c ${column} | grep -v '""' | tr -d '"' | egrep -v '(NA|unknown)' | head -1`
				echo "diagnosis from other row = ${diagnosis}"
			fi
		fi
	fi

	getcolumnfromcsvheader "Primary.cancer.site" "${CSVFILENAMEFORSLIDE}"
	primary_cancer_site=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "primary_cancer_site = ${primary_cancer_site}"

	getcolumnfromcsvheader "Metastatic.site" "${CSVFILENAMEFORSLIDE}"
	metastatic_site=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "metastatic_site = ${metastatic_site}"

	getcolumnfromcsvheader "NCIt.site" "${CSVFILENAMEFORSLIDE}"
	ncit_site=`echo "${csvlineforslide}" | csvtool -c ${column} | tr -d '"'`
	echo "ncit_site = ${ncit_site}"
fi

if [ "${dataset}" = "pdmr" ]
then
	dicomclinicaltrialsiteid="${PDXnet_PDMR_dicomclinicaltrialsiteid}"
	dicomclinicaltrialsitename="${PDXnet_PDMR_dicomclinicaltrialsitename}"
elif [ "${dataset}" = "pdmr-wgd" ]
then
	dicomclinicaltrialsiteid="${PDXnet_WGD_dicomclinicaltrialsiteid}"
	dicomclinicaltrialsitename="${PDXnet_WGD_dicomclinicaltrialsitename}"
elif [ "${dataset}" = "pdmr-xtld" ]
then
	dicomclinicaltrialsiteid="${PDXnet_XTLD_dicomclinicaltrialsiteid}"
	dicomclinicaltrialsitename="${PDXnet_XTLD_dicomclinicaltrialsitename}"
else
	echo 1>&2 "Warning: Unrecognized dataset ${dataset} for patient_id ${patient_id}"
fi

# use "patient_id" that is combination of patient and model and sample (since we don't have mouse ID),
# and use hyphens to match existing TCIA PDMR collections  ...
# but sometimes original_patient_id is "NA"
if [ ! -z "${original_patient_id}" -a ! "${original_patient_id}" = "NA" ]
then
	patient_id="${original_patient_id}-${model_id}-${sample_id}"
else
	# e.g., 99163.svs	NA	A23235-111-X	XHCC54E10G39
	echo 1>&2 "Warning: original_patient_id is missing or NA so assume model_id \"${model_id}\" incorporates it"
	patient_id="${model_id}-${sample_id}"
fi
echo "patient_id = ${patient_id}"

dicomclinicaltrialsubjectid="${patient_id}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

if [ -z "${outdir}" ]
then
	outdir="Converted/${dicomclinicaltrialsubjectid}_${slide_id}"
fi
echo "outdir = ${outdir}"

# do not attempt to find codes for diagnosis yet :(
# not checking diagnosiscodemeaning for length wrt. VR LO since known to be <= 64 :(

diagnosisdescription=""
if [ ! -z "${diagnosis}" -a ! "${diagnosis}" = "NA" -a ! "${diagnosis}" = "unknown" ]
then
	diagnosisdescription="${diagnosis}"
fi

echo "diagnosisdescription = ${diagnosisdescription}"

dicomdiagnosisdescription="${diagnosisdescription}"

# not checking diagnosisdescription for length wrt. VR LO since known to be <= 64 :(
# not using additionalpatienthistory since diagnosisdescription known to fit in VR LO :(

diagnosiscodevalue=""
diagnosiscsd=""
diagnosiscodemeaning=""

# SCT - use disorder if defined, else morphological abnormality
if [ ! -z "${diagnosis}" ]
then
	if   [ "${diagnosis}" = "Acinar Cell Carcinoma" ]
	then
		diagnosiscodevalue="45410002"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Acinar cell carcinoma"
	elif [ "${diagnosis}" = "Adenocarcinoma - cervix" -o "${diagnosis}" = "Cervical Adenocarcinoma" ]
	then
		diagnosiscodevalue="254887002"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Adenocarcinoma of cervix"
	elif [ "${diagnosis}" = "Adenocarcinoma - colon" -o "${diagnosis}" = "Colon Adenocarcinoma" ]
	then
		diagnosiscodevalue="1701000119104"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Primary adenocarcinoma of colon"
	elif [ "${diagnosis}" = "Adenocarcinoma - pancreas" -o "${diagnosis}" = "Pancreatic Adenocarcinoma" ]
	then
		diagnosiscodevalue="700423003"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Adenocarcinoma of pancreas"
	elif [ "${diagnosis}" = "Adenocarcinoma - rectum" -o "${diagnosis}" =  "Rectal Adenocarcinoma" ]
	then
		diagnosiscodevalue="254582000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Adenocarcinoma of rectum"
	elif [ "${diagnosis}" = "Adenocarcinoma - small intest." -o "${diagnosis}" = "Small Intestinal Adenocarcinoma" ]
	then
		diagnosiscodevalue="424440001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Adenocarcinoma of small intestine"
	elif [ "${diagnosis}" = "Adrenocortical carcinoma" -o "${diagnosis}" = "Adrenal Cortical Carcinoma" ]
	then
		diagnosiscodevalue="2227007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Adrenal cortical carcinoma"
	elif [ "${diagnosis}" = "Bladder Small Cell Neuroendocrine Carcinoma" ]
	then
		diagnosiscodevalue="718604008"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Small cell neuroendocrine carcinoma of bladder"
	elif [ "${diagnosis}" = "Carcinosarcoma" ]
	then
		diagnosiscodevalue="63264007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Carcinosarcoma"
	elif [ "${diagnosis}" = "Carcinosarcoma of the uterus" ]
	then
		diagnosiscodevalue="702369008"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Carcinosarcoma of uterus"
	elif [ "${diagnosis}" = "Chondrosarcoma" ]
	then
		diagnosiscodevalue="443520009"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Chondrosarcoma"
	elif [ "${diagnosis}" = "Colorectal cancer, NOS" -o "${diagnosis}" = "Colorectal Carcinoma" ]
	then
		# there is no SCT concept specific to colorectal "carcinoma" (only adeno, which is too specific), and colon, which is too specific
		diagnosiscodevalue="1286877004"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant neoplasm of cecum and/or colon and/or rectum"
	elif [ "${diagnosis}" = "Ewing sarcoma/Peripheral PNET" -o "${diagnosis}" = "Ewing Sarcoma|Primitive Neuroectodermal Tumor" ]
	then
		diagnosiscodevalue="703707001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Ewing sarcoma / peripheral neuroectodermal tumor"
	elif [ "${diagnosis}" = "Female reprod. system cancer, NOS" ]
	then
		diagnosiscodevalue="93797001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Primary malignant neoplasm of female genital organ"
	elif [ "${diagnosis}" = "Fibrosarcoma - not infantile" ]
	then
		diagnosiscodevalue="1290852005"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Fibrosarcoma"
	elif [ "${diagnosis}" = "Gastric Adenocarcinoma" ]
	then
		# no SCT concept specific to "adeno"
		diagnosiscodevalue="372143007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Gastric carcinoma"
	elif [ "${diagnosis}" = "Gastric cancer, NOS" ]
	then
		diagnosiscodevalue="363349007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant neoplasm of stomach"
	elif [ "${diagnosis}" = "Gastrointestinal stromal tumor" -o "${diagnosis}" = "Gastrointestinal Stromal Tumor" ]
	then
		diagnosiscodevalue="420120006"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Gastrointestinal stromal tumor"
	elif [ "${diagnosis}" = "H & N squamous cell car., NOS" -o "${diagnosis}" = "Head and Neck Squamous Cell Carcinoma" ]
	then
		diagnosiscodevalue="716659002"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Squamous cell carcinoma of head and neck"
	elif [ "${diagnosis}" = "Hurthle cell neoplasm (thyroid)" -o "${diagnosis}" = "Thyroid Gland Oncocytic Carcinoma" ]
	then
		diagnosiscodevalue="1255193005"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Primary oncocytic carcinoma of thyroid"
	elif [ "${diagnosis}" = "Laryngeal squamous cell carcinoma" ]
	then
		diagnosiscodevalue="405822008"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Squamous cell carcinoma of larynx"
	elif [ "${diagnosis}" = "Leiomyosarcoma - not uterine" -o "${diagnosis}" = "Leiomyosarcoma" ]
	then
		diagnosiscodevalue="443719001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Leiomyosarcoma"
	elif [ "${diagnosis}" = "Leiomyosarcoma - uterus" ]
	then
		diagnosiscodevalue="447389009"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Leiomyosarcoma of uterus"
	elif [ "${diagnosis}" = "Lip/oral cavity squam. cell car." ]
	then
		diagnosiscodevalue="307502000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Squamous cell carcinoma of mouth"
	elif [ "${diagnosis}" = "Lung adenocarcinoma" -o "${diagnosis}" = "Lung Adenocarcinoma" ]
	then
		diagnosiscodevalue="254626006"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Adenocarcinoma of lung"
	elif [ "${diagnosis}" = "Malig. periph. nerve sheath tum." -o "${diagnosis}" =  "Malignant Peripheral Nerve Sheath Tumor" ]
	then
		diagnosiscodevalue="404037002"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant peripheral nerve sheath tumor"
	elif [ "${diagnosis}" = "Melanoma" ]
	then
		diagnosiscodevalue="372244006"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant melanoma"
		
	elif [ "${diagnosis}" = "Merkel cell tumor" -o "${diagnosis}" = "Merkel Cell Carcinoma" ]
	then
		diagnosiscodevalue="253001006"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Merkel cell carcinoma"
	elif [ "${diagnosis}" = "Mesothelial Neoplasm" ]
	then
		diagnosiscodevalue="115232000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Mesothelial neoplasm"
	elif [ "${diagnosis}" = "Mesothelioma" ]
	then
		diagnosiscodevalue="109378008"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant mesothelioma"
	elif [ "${diagnosis}" = "Mucoepidermoid Carcinoma" ]
	then
		diagnosiscodevalue="4079000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Mucoepidermoid carcinoma"
	elif [ "${diagnosis}" = "Myxofibrosarcoma" ]
	then
		diagnosiscodevalue="703609007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Myxofibrosarcoma"
	elif [ "${diagnosis}" = "Neuroendocrine cancer, NOS" ]
	then
		diagnosiscodevalue="1290125003"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Neuroendocrine neoplasm, malignant"
	elif [ "${diagnosis}" = "Neuroendocrine Carcinoma" ]
	then
		diagnosiscodevalue="253000007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Neuroendocrine carcinoma"
	elif [ "${diagnosis}" = "Non-Rhabdo. soft tissue sarcoma" ]
	then
		diagnosiscodevalue="424413001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Sarcoma"
	elif [ "${diagnosis}" = "Osteosarcoma" ]
	then
		diagnosiscodevalue="189878003"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Osteosarcoma"
	elif [ "${diagnosis}" = "Ovarian epithelial cancer" -o "${diagnosis}" = "Ovarian Carcinoma" ]
	then
		diagnosiscodevalue="254849005"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Carcinoma of ovary"
	elif [ "${diagnosis}" = "Prostate cancer, NOS" ]
	then
		diagnosiscodevalue="399068003"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant neoplasm of prostate"
	elif [ "${diagnosis}" = "Prostate Carcinoma" ]
	then
		diagnosiscodevalue="254900004"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Prostate carcinoma"
	elif [ "${diagnosis}" = "Renal cell carcinoma, NOS" -o "${diagnosis}" = "Renal Cell Carcinoma, Not Otherwise Specified" ]
	then
		diagnosiscodevalue="702391001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Renal cell carcinoma"
	elif [ "${diagnosis}" = "Rhabdomyosarcoma, NOS" -o "${diagnosis}" = "Rhabdomyosarcoma" ]
	then
		diagnosiscodevalue="302847003"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Rhabdomyosarcoma"
	elif [ "${diagnosis}" = "Salivary gland cancer" ]
	then
		diagnosiscodevalue="255072001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant neoplasm of salivary gland"
	elif [ "${diagnosis}" = "Small cell car. (extrapulmonary)" ]
	then
		diagnosiscodevalue="1259462007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Primary small cell carcinoma"
	elif [ "${diagnosis}" = "Small cell lung cancer" -o "${diagnosis}" = "Lung Small Cell Carcinoma" ]
	then
		diagnosiscodevalue="254632001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Small cell carcinoma of lung"
	elif [ "${diagnosis}" = "Squamous cell lung carcinoma" -o "${diagnosis}" = "Lung Squamous Cell Carcinoma" ]
	then
		diagnosiscodevalue="254634000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Squamous cell carcinoma of lung"
	elif [ "${diagnosis}" = "Spindle Cell Sarcoma" ]
	then
		diagnosiscodevalue="9801004"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Spindle cell sarcoma"
	elif [ "${diagnosis}" = "Synovial sarcoma" -o "${diagnosis}" = "Synovial Sarcoma" ]
	then
		diagnosiscodevalue="302851001"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Synovial sarcoma"
	elif [ "${diagnosis}" = "Transitional cell car. - uroth." -o "${diagnosis}" = "Urothelial Carcinoma" -o "${diagnosis}" = "Transitional Cell Carcinoma" ]
	then
		diagnosiscodevalue="27090000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Transitional cell carcinoma"
	elif [ "${diagnosis}" = "Urothelial/bladder cancer, NOS" ]
	then
		diagnosiscodevalue="399326009"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant neoplasm of urinary bladder"
	elif [ "${diagnosis}" = "Vaginal cancer, NOS" ]
	then
		diagnosiscodevalue="363445000"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Malignant neoplasm of vagina"
	elif [ "${diagnosis}" = "Vaginal Carcinoma" ]
	then
		diagnosiscodevalue="254893005"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="Carcinoma of vagina"
	elif [ "${diagnosis}" = "Xenograft associated B cell lymphomas" ]
	then
		diagnosiscodevalue="109979007"
		diagnosiscsd="SCT"
		diagnosiscodemeaning="B-cell lymphoma"
	else
		#echo 1>&2 "Warning: ignoring unrecognized diagnosis ${diagnosis} for patient_id ${patient_id}"
		echo 1>&2 "Warning: ignoring unrecognized diagnosis ${diagnosis}"
	fi
else
	echo 1>&2 "Warning: missing diagnosis for patient_id ${patient_id}"
fi

anatomycodevalue=""
anatomycsd=""
anatomycodemeaning=""
lateralitycodevalue=""
lateralitycsd=""
lateralitycodemeaning=""
anatomymodifiercodevalue=""
anatomymodifiercsd=""
anatomymodifiercodemeaning=""

anatomic_site=""
#if [ ! -z "${primary_cancer_site}" -a ! "${primary_cancer_site}" = "NA" ]
if [ ! -z "${ncit_site}" -a ! "${ncit_site}" = "NA" ]
then
	echo 1>&2 "Using ncit_site as anatomic_site"
	anatomic_site="${ncit_site}"
elif [ ! -z "${primary_cancer_site}" -a ! "${primary_cancer_site}" = "NA" ]
then
	echo 1>&2 "Using primary_cancer_site as anatomic_site since ncit_site empty or NA"
	anatomic_site="${primary_cancer_site}"
fi

# some of these are morphologic abnormality rather than disorder :(
if [ ! -z "${anatomic_site}" ]
then
	if   [ "${anatomic_site}" = "adrenal cortex" ]
	then
			anatomycodevalue="68594002"
			anatomycsd="SCT"
			anatomycodemeaning="Adrenal cortex"
	elif [ "${anatomic_site}" = "bladder organ" ]
	then
			anatomycodevalue="89837001"
			anatomycsd="SCT"
			anatomycodemeaning="Bladder"
	elif [ "${anatomic_site}" = "bone element" ]
	then
			anatomycodevalue="272673000"
			anatomycsd="SCT"
			anatomycodemeaning="Bone"
	elif [ "${anatomic_site}" = "Breast" ]
	then
			anatomycodevalue="76752008"
			anatomycsd="SCT"
			anatomycodemeaning="Breast"
	elif [ "${anatomic_site}" = "Colon" -o "${anatomic_site}" = "colon" ]
	then
			anatomycodevalue="71854001"
			anatomycsd="SCT"
			anatomycodemeaning="Colon"
	elif [ "${anatomic_site}" = "Digestive/Gastrointestinal" -o "${anatomic_site}" = "Gastrointestinal" -o "${anatomic_site}" = "Digestive System" ]
	then
			#could use more general parent of 122865005, 51289009 "Digestive tract structure", or its parent 86762007 "Digestive system"
			anatomycodevalue="122865005"
			anatomycsd="SCT"
			anatomycodemeaning="Gastrointestinal tract"
	elif [ "${anatomic_site}" = "Endocrine and Neuroendocrine" ]
	then
			anatomycodevalue="113331007"
			anatomycsd="SCT"
			anatomycodemeaning="Endocrine"
	elif [ "${anatomic_site}" = "Genitourinary" -o "${anatomic_site}" = "genitourinary system" ]
	then
			anatomycodevalue="21514008"
			anatomycsd="SCT"
			anatomycodemeaning="Genitourinary tract"
	elif [ "${anatomic_site}" = "Gynecologic" -o "${anatomic_site}" = "Female Reproductive System Part" ]
	then
			anatomycodevalue="413344004"
			anatomycsd="SCT"
			anatomycodemeaning="Female genital tract"
	elif [ "${anatomic_site}" = "Head and Neck" ]
	then
			anatomycodevalue="774007"
			anatomycsd="SCT"
			anatomycodemeaning="Head and neck"
	elif [ "${anatomic_site}" = "larynx" ]
	then
			anatomycodevalue="4596009"
			anatomycsd="SCT"
			anatomycodemeaning="Larynx"
	elif [ "${anatomic_site}" = "lip|oral cavity" ]
	then
			anatomycodevalue="74336005"
			anatomycsd="SCT"
			anatomycodemeaning="Oral soft tissue"
	elif [ "${anatomic_site}" = "Lung" -o "${anatomic_site}" = "lung" ]
	then
			anatomycodevalue="39607008"
			anatomycsd="SCT"
			anatomycodemeaning="Lung"
	elif [ "${anatomic_site}" = "Musculoskeletal" -o "${anatomic_site}" = "Musculoskeletal System" ]
	then
			anatomycodevalue="26107004"
			anatomycsd="SCT"
			anatomycodemeaning="Musculoskeletal"
	elif [ "${anatomic_site}" = "Neuroendocrine System" ]
	then
			# SCT only has a tissue 2639009 which is undesirable so use NCIt
			anatomycodevalue="C12945"
			anatomycsd="NCIt"
			anatomycodemeaning="Neuroendocrine system"
	elif [ "${anatomic_site}" = "ovary" ]
	then
			anatomycodevalue="15497006"
			anatomycsd="SCT"
			anatomycodemeaning="Ovary"
	elif [ "${anatomic_site}" = "pancreas" ]
	then
			anatomycodevalue="15776009"
			anatomycsd="SCT"
			anatomycodemeaning="Pancreas"
	elif [ "${anatomic_site}" = "peripheral nervous system" ]
	then
			anatomycodevalue="3058005"
			anatomycsd="SCT"
			anatomycodemeaning="Peripheral nervous system"
	elif [ "${anatomic_site}" = "prostate gland" ]
	then
			anatomycodevalue="41216001"
			anatomycsd="SCT"
			anatomycodemeaning="Prostate"
	elif [ "${anatomic_site}" = "Respiratory/Thoracic" ]
	then
			anatomycodevalue="816094009"
			anatomycsd="SCT"
			anatomycodemeaning="Chest"
	elif [ "${anatomic_site}" = "rectum" ]
	then
			anatomycodevalue="34402009"
			anatomycsd="SCT"
			anatomycodemeaning="Rectum"
	elif [ "${anatomic_site}" = "Skin" -o "${anatomic_site}" = "sking of body" ]
	then
			anatomycodevalue="39937001"
			anatomycsd="SCT"
			anatomycodemeaning="Skin"
	elif [ "${anatomic_site}" = "small intestine" ]
	then
			anatomycodevalue="30315005"
			anatomycsd="SCT"
			anatomycodemeaning="Small intestine"
	elif [ "${anatomic_site}" = "thyroid gland" ]
	then
			anatomycodevalue="69748006"
			anatomycsd="SCT"
			anatomycodemeaning="Thyroid"
	elif [ "${anatomic_site}" = "uterine cervix" ]
	then
			anatomycodevalue="71252005"
			anatomycsd="SCT"
			anatomycodemeaning="Cervix"
	elif [ "${anatomic_site}" = "uterus" ]
	then
			anatomycodevalue="35039007"
			anatomycsd="SCT"
			anatomycodemeaning="Uterus"
	elif [ "${anatomic_site}" = "vagina" ]
	then
			anatomycodevalue="76784001"
			anatomycsd="SCT"
			anatomycodemeaning="Vagina"
	elif [ "${anatomic_site}" = "NA" -o "${anatomic_site}" = "Unknown Primary" ]
	then
		#echo 1>&2 "Warning: anatomic_site not available (NA) or unkown for patient_id ${patient_id}"
		echo 1>&2 "Warning: anatomic_site not available (NA) or unkown for patient_id ${patient_id}"
		# fall through to generic unknown/unrecognized handling
	else
		#echo 1>&2 "Warning: unrecognized anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
		echo 1>&2 "Warning: unrecognized anatomic_site \"${anatomic_site}\""
		# fall through to generic unknown/unrecognized handling
	fi
fi

# do not need to provide code for "Unspecified" since not providing modifiers
if [ -z "${anatomycodemeaning}" ]
then
	echo 1>&2 "Warning: anatomy information missing or unrecognized for patient_id ${patient_id}"
fi
	
echo "anatomycodemeaning = ${anatomycodemeaning}"
#echo "lateralitycodemeaning = ${lateralitycodemeaning}"
#echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

# have no information about fixation so assume FFPE ...
fixation="FFPE"
echo "fixation = ${fixation}"

if [ "${stain}" = "H&E" ]
then
	stain="HE"
elif [ "${stain}" = "NA" ]
then
	echo 1>&2 "Warning: stain \"${stain}\" for slide_id ${slide_id} - assuming HE"
	stain="HE"
fi

echo "stain = ${stain}"

if [ "${model_type}" = "Human" ]
then
	dicomseriesdescription="Human, ${fixation} ${stain}"
else
	dicomseriesdescription="Model ${model_type}, Passage ${passage}, ${fixation} ${stain}"
fi
echo "dicomseriesdescription = ${dicomseriesdescription}"

dicompatientid="${patient_id}"
dicompatientname="${dicompatientid}"

# may be too long without removing delimiters, and even then, so trunctate prn.
dicomstudyid=`echo "${patient_id}" | sed 's/[^a-zA-Z0-9]//g' | head -c 16`
dicomaccessionnumber="${dicomstudyid}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

dicomspecimenuid=""
if [ ! -f "${FILEMAPPINGSPECIMENIDTOUID}" ]
then
	touch "${FILEMAPPINGSPECIMENIDTOUID}"
fi

# specimen identifier is already as unique as possible, since it uses original_patient_id, model_id and sample_id
dicomspecimenidentifier="${patient_id}"
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
if [ "${sex}" = "Male" ]
then
	dicomsex="M"
elif [ "${sex}" = "Female" ]
then
	dicomsex="F"
fi
echo "dicomsex = ${dicomsex}"

dicomage=""
if [ ! -z "${age}" -a "${age}" != "NA" -a "${age}" != "unknown" ]
then
	if [ ${age} -ge 100 ]
	then
		dicomage="${age}Y"
	elif [ ${age} -ge 10 ]
	then
		dicomage="0${age}Y"
	elif [ ${age} -ge 1 ]
	then
		dicomage="00${age}Y"
	fi
fi
echo "dicomage = ${dicomage}"

dicomethnicgroup=""
ethnicgroupcodevalue_1=""
ethnicgroupcsd_1=""
ethnicgroupcodemeaning_1=""

# SH, so limited to 16 characters
if [ "${race}" = "American Indian" ]
then
	dicomethnicgroup="American Indian"
	ethnicgroupcodevalue_1="413490006"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="American Indian or Alaska native"
elif [ "${race}" = "Black or African American" ]
then
	dicomethnicgroup="Black"
	ethnicgroupcodevalue_1="413464008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="African race"
elif [ "${race}" = "White" -o "${race}" = "Caucasian" ]
then
	dicomethnicgroup="White"
	ethnicgroupcodevalue_1="413773004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Caucasian race"
elif [ "${race}" = "NA" -o "${race}" = "Not Provided" -o "${race}" = "Not Reported" -o "${race}" = "Unknown" -o "${race}" = "NA" ]
then
	echo 1>&2 "Warning: ignoring unavailable, unreported or unknown race ${race}"
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
echo "dicomclinicaltrialprotocolid = ${dicomclinicaltrialprotocolid}"
echo "dicomclinicaltrialprotocolname = ${dicomclinicaltrialprotocolname}"
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

if [ "${sample_id}" = "ORIGINATOR" -o "${model_type}" = "Human" ]
then
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
	echo >>"${TMPJSONFILE}" "		\"PatientSpeciesCodeSequence\" : { \"cv\" : \"337915000\", \"csd\" : \"SCT\", \"cm\" : \"Homo sapiens\" },"
else
	echo >>"${TMPJSONFILE}" "		\"PatientSpeciesCodeSequence\" : { \"cv\" : \"447612001\", \"csd\" : \"SCT\", \"cm\" : \"Mus musculus\" },"
	echo >>"${TMPJSONFILE}" "		\"PatientBreedDescription\" : \"\","
	echo >>"${TMPJSONFILE}" "		\"PatientBreedCodeSequence\" : [],"
	echo >>"${TMPJSONFILE}" "		\"BreedRegistrationSequence\" : [],"
	if [ "${mouse_strain}" = "NSG" ]
	then
		echo >>"${TMPJSONFILE}" "		\"StrainDescription\" : \"NSG\","
		echo >>"${TMPJSONFILE}" "		\"StrainCodeSequence\" : { \"cv\" : \"3577020\", \"csd\" : \"MGI\", \"cm\" : \"NOD.Cg-Prkdc<scid> Il2rg<tm1Wjl>/SzJ\" },"
	else
		echo 1>&2 "Warning: ignoring unrecognized mouse_strain ${mouse_strain}"
	fi
	echo >>"${TMPJSONFILE}" "		\"ResponsiblePerson\" : \"\","
	echo >>"${TMPJSONFILE}" "		\"ResponsibleOrganization\" : \"\","
	echo >>"${TMPJSONFILE}" "		\"PatientSexNeutered\" : \"\","
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
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolID\" : \"${dicomclinicaltrialprotocolid}\","
if [ ! -z "${issuerofdicomclinicaltrialprotocolid}" ]
then
	echo >>"${TMPJSONFILE}" "		\"IssuerOfClinicalTrialProtocolID\" : \"${issuerofdicomclinicaltrialprotocolid}\","
fi
if [ ! -z "${doiclinicaltrialprotocolid}" ]
then
	echo >>"${TMPJSONFILE}" "		\"OtherClinicalTrialProtocolIDsSequence\" : ["
	echo >>"${TMPJSONFILE}" "			{"
	echo >>"${TMPJSONFILE}" "				\"ClinicalTrialProtocolID\" : \"${doiclinicaltrialprotocolid}\","
	echo >>"${TMPJSONFILE}" "				\"IssuerOfClinicalTrialProtocolID\" : \"DOI\""
	echo >>"${TMPJSONFILE}" "			}"
	echo >>"${TMPJSONFILE}" "		],"
fi
echo >>"${TMPJSONFILE}" "		\"00130010\" : \"CTP\","
echo >>"${TMPJSONFILE}" "		\"00131010\" : \"${dicomclinicaltrialprotocolid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolName\" : \"${dicomclinicaltrialprotocolname}\","
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
if [ "${stain}" = "HE" ]
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
	echo 1>&2 "Warning: outdir \"${outdir}\" already exists - deleting and replacing"
fi

rm -rf "${outdir}"
mkdir -p "${outdir}"
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
