#!/bin/sh
#
# Usage: ./rmstodcm.sh folder/filename.svs [outdir]

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

#CSVFILENAMEFORSAMPLE="CCDI_Submission_Template_v1.0.1_DM_Sample.csv"
CSVFILENAMEFORSAMPLE="CCDI_Submission_Template_v1.0.1_DM_v2_Sample_embeddedNLfixed.csv"
if [ ! -f "${CSVFILENAMEFORSAMPLE}" ]
then
	echo 1>&2 "Error: no sample to patient mapping metadata CSV file called ${CSVFILENAMEFORSAMPLE}"
	exit 1
fi

CSVFILENAMEFORIMAGING="CCDI_Submission_Template_v1.0.1_DM_v2_Imaging.csv"
if [ ! -f "${CSVFILENAMEFORIMAGING}" ]
then
	echo 1>&2 "Error: no sample to patient mapping metadata CSV file called ${CSVFILENAMEFORIMAGING}"
	exit 1
fi

#CSVFILENAMEFORPARTICIPANT="CCDI_Submission_Template_v1.0.1_DM_Participant.csv"
CSVFILENAMEFORPARTICIPANT="CCDI_Submission_Template_v1.0.1_DM_v2_Participant.csv"
if [ ! -f "${CSVFILENAMEFORPARTICIPANT}" ]
then
	echo 1>&2 "Error: no participant metadata CSV file called ${CSVFILENAMEFORPARTICIPANT}"
	exit 1
fi

#CSVFILENAMEFORDIAGNOSIS="CCDI_Submission_Template_v1.0.1_DM_Diagnosis.csv"
CSVFILENAMEFORDIAGNOSIS="CCDI_Submission_Template_v1.0.1_DM_v2_Diagnosis.csv"
if [ ! -f "${CSVFILENAMEFORDIAGNOSIS}" ]
then
	echo 1>&2 "Error: no diagnosis metadata CSV file called ${CSVFILENAMEFORDIAGNOSIS}"
	exit 1
fi

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="RMSspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="RMSstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="RMSstudyIDToDateTimeMap.csv"

#JHOVE="${HOME}/work/jhove/jhove"

#PIXELMEDDIR="${HOME}/work/pixelmed/imgbook"
PIXELMEDDIR="${HOME}"
#PATHTOADDITIONAL="${PIXELMEDDIR}/lib/additional"
PATHTOADDITIONAL="${HOME}"

# "source-data-rms/PARPDV-0BLRWU_A2-Q30.svs"
# "source-data-rms/PARPDV-0BLRWU_A2_RAW.tif"
# "source-data-rms/PANJXS-0BMX7D_A2.tif"
# "source-data-rms/PAMHCR-0BH98H.tif"

filename=`basename "${infile}" '.svs'`
filename=`basename "${filename}" '.tif'`
foldername=`dirname "${infile}"`

slide_id=`echo ${filename} | sed -e 's/^\([A-Z0-9]*-[A-Z0-9]*_[A-Z0-9]*\).*$/\1/'`

compressedvariant=`echo ${filename} | egrep '(RAW|Q[0-9]*)' | sed -e 's/^.*\([RQ][A0-9][W0]\)$/\1/'`
if [ -z "${compressedvariant}" ]
then
	compressedvariant="RAW"
fi

if [ -z "${outdir}" ]
then
	# note: variation between '_' and '-' use will be harmonized to '_' ...
	outdir="Converted/${slide_id}_${compressedvariant}"
fi

sample_id=`echo ${slide_id} | sed -e 's/^\([A-Z]*\)-.*$/\1/'`
specimen_id=`echo ${slide_id} | sed -e 's/^\([A-Z]*-[A-Z0-9]*\).*$/\1/'`
# block_id may be absent
block_id=`echo ${slide_id} | egrep '_[A-Z0-9][A-Z0-9]*' | sed -e 's/^[A-Z]*-[A-Z0-9]*_\([A-Z0-9]*\).*$/\1/'`

echo "infile = ${infile}"
echo "filename = ${filename}"
echo "slide_id = ${slide_id}"
echo "sample_id = ${sample_id}"
echo "specimen_id = ${specimen_id}"
echo "block_id = ${block_id}"

anatomycodevalue=""
anatomycsd=""
anatomycodemeaning=""
lateralitycodevalue=""
lateralitycsd=""
lateralitycodemeaning=""
anatomymodifiercodevalue=""
anatomymodifiercsd=""
anatomymodifiercodemeaning=""

if [ -f "${CSVFILENAMEFORSAMPLE}" ]
then
	# type,study.phs_accession,participant.participant_id,sample_id,sample_type,sample_anatomic_site,participant_age_at_collection,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_morphology,tumor_incidence_type,sample_description,sample_tumor_status
	# ,,RMS2277,PARPDV,Tumor,"Soft tissue, pelvis-left",4.33,,,,,,,,Tumor
	csvlineforsample=`grep ",${sample_id}," "${CSVFILENAMEFORSAMPLE}" | head -1`
	echo "csvlineforsample = ${csvlineforsample}"
fi

if [ -z "${csvlineforsample}" ]
then
	echo 1>&2 "Warning: cannot find metadata CSV file entry for sample_id ${sample_id} from which to extract patient_id and anatomy - using sample_id as patient_id"
	patient_id="${sample_id}"
else
	patient_id=`echo "${csvlineforsample}" | awk -F, '{print $3}'`

	# due to quoting of earlier column entries +/- quoting of body site column entries, using following two numeric values as signal as to which is body site column
	# type,study.phs_accession,participant.participant_id,sample_id,sample_type,sample_anatomic_site,participant_age_at_collection,Histological_Classification,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_morphology,tumor_incidence_type,sample_description,sample_tumor_status
	# ,,RMS2277,PARPDV,Tumor,"Soft tissue, pelvis-left",4.33,,,,,,,,Tumor
	# ,,RMS2520,PAWWNV,Tumor,Pelvis,8.44,EMBRYONAL RHABDOMYOSARCOMA,,,,,,,,Tumor
	# ,,RMS2521,PAWXFU,Tumor,"Soft tissue, shoulder-left",0.28,EMBRYONAL RHABDOMYOSARCOMA,,,,,,,,Tumor
	# ,,RMS2266,PAKPED,Tumor,Breast-right,14.49,ALVEOLAR RHABDOMYOSARCOMA,,,,,,,,Tumor

	anatomyentry=`echo "${csvlineforsample}" | sed -e 's/^.*,Tumor,"\([^"]*\)".*$/\1/'`
	if [ "${anatomyentry}" = "${csvlineforsample}" ]
	then
		anatomyentry=`echo "${csvlineforsample}" | sed -e 's/^.*,Tumor,\([^,]*\).*$/\1/'`
	fi
	if [ "${anatomyentry}" = "${csvlineforsample}" ]
	then
		# didn't work
		anatomyentry=""
	fi
	echo "original anatomyentry = ${anatomyentry}"
	if [ ! -z "${anatomyentry}" ]
	then
		anatomyentry=`echo "${anatomyentry}" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z]/ /g' | sed -e 's/[ ][ ]*/ /g'`
		echo "normalized anatomyentry = ${anatomyentry}"
		isleft=`echo "${anatomyentry}" | fgrep 'left'`
		if [ -z "${isleft}" ]
		then
			isright=`echo "${anatomyentry}" | fgrep 'right'`
			if [ ! -z "${isright}" ]
			then
				lateralitycodevalue="24028007"
				lateralitycsd="SCT"
				lateralitycodemeaning="Right"
				anatomyentry=`echo "${anatomyentry}" | sed -e 's/[ ]*right//'`
			fi
		else
			lateralitycodevalue="7771000"
			lateralitycsd="SCT"
			lateralitycodemeaning="Left"
			anatomyentry=`echo "${anatomyentry}" | sed -e 's/[ ]*left//'`
		fi
		echo "without laterality anatomyentry = ${anatomyentry}"

		issofttissue=`echo "${anatomyentry}" | fgrep 'soft tissue'`
		if [ ! -z "${issofttissue}" ]
		then
			# may get overridden if later "distal" or similar, since only tracking one non-laterality modifier, but good enough for now :(
			anatomymodifiercodevalue="87784001"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Soft tissue"
			anatomyentry=`echo "${anatomyentry}" | sed -e 's/[ ]*soft tissue[ ]*//'`
		fi
		echo "without soft tissue anatomyentry = ${anatomyentry}"

		anatomyentry=`echo "${anatomyentry}" | sed -e 's/[ ][ ]*/ /g' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'`
		echo "final spaces cleaned anatomyentry = ${anatomyentry}"

		if [ "${anatomyentry}" = "abdomen" ]
		then
			anatomycodevalue="818981001"
			anatomycsd="SCT"
			anatomycodemeaning="Abdomen"
		elif [ "${anatomyentry}" = "abdomen pelvis" ]
		then
			anatomycodevalue="818982008"
			anatomycsd="SCT"
			anatomycodemeaning="Abdomen and pelvis"
		elif [ "${anatomyentry}" = "abdomen bladder" ]
		then
			anatomycodevalue="89837001"
			anatomycsd="SCT"
			anatomycodemeaning="Bladder"
		elif [ "${anatomyentry}" = "abdominal wall" ]
		then
			# need to add to DICOM subset (currently only muscle) :(
			anatomycodevalue="822992007"
			anatomycsd="SCT"
			anatomycodemeaning="Abdominal wall"
		elif [ "${anatomyentry}" = "arm" ]
		then
			# "arm" unqualified is ambiguous - assume excludes forearm :(
			anatomycodevalue="40983000"
			anatomycsd="SCT"
			anatomycodemeaning="Upper arm"
		elif [ "${anatomyentry}" = "arm axillary" ]
		then
			anatomycodevalue="91470000"
			anatomycsd="SCT"
			anatomycodemeaning="Axilla"
		elif [ "${anatomyentry}" = "armpit" ]
		then
			anatomycodevalue="91470000"
			anatomycsd="SCT"
			anatomycodemeaning="Axilla"
		elif [ "${anatomyentry}" = "back" ]
		then
			anatomycodevalue="77568009"
			anatomycsd="SCT"
			anatomycodemeaning="Back"
		elif [ "${anatomyentry}" = "bile duct bilary tract" ]
		then
			anatomycodevalue="34707002"
			anatomycsd="SCT"
			anatomycodemeaning="Bilary tract"
		elif [ "${anatomyentry}" = "bladder" ]
		then
			anatomycodevalue="89837001"
			anatomycsd="SCT"
			anatomycodemeaning="Bladder"
		elif [ "${anatomyentry}" = "bone femur distal" ]
		then
			anatomycodevalue="71341001"
			anatomycsd="SCT"
			anatomycodemeaning="Femur"
			anatomymodifiercodevalue="46053002"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Distal"
		elif [ "${anatomyentry}" = "bone mandible" ]
		then
			anatomycodevalue="91609006"
			anatomycsd="SCT"
			anatomycodemeaning="Mandible"
		elif [ "${anatomyentry}" = "bone mandible pterygoid muscle" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="76738006"
			anatomycsd="SCT"
			anatomycodemeaning="Pterygoid muscle"
		elif [ "${anatomyentry}" = "bone maxilla sinus" ]
		then
			# ?? not sure what to make of "bone" in context of "sinus" :(
			anatomycodevalue="15924003"
			anatomycsd="SCT"
			anatomycodemeaning="Maxillary sinus"
		elif [ "${anatomyentry}" = "bone marrow" ]
		then
			anatomycodevalue="14016003"
			anatomycsd="SCT"
			anatomycodemeaning="Bone marrow"
		elif [ "${anatomyentry}" = "bone maxilla" ]
		then
			anatomycodevalue="70925003"
			anatomycsd="SCT"
			anatomycodemeaning="Maxilla"
		elif [ "${anatomyentry}" = "bone temporal" ]
		then
			anatomycodevalue="60911003"
			anatomycsd="SCT"
			anatomycodemeaning="Temporal bone"
		elif [ "${anatomyentry}" = "bone temporal infra" ]
		then
			# ?? assume infratemporal fossa, despite the word bone :(
			# not in DICOM subset :(
			anatomycodevalue="69541002"
			anatomycsd="SCT"
			anatomycodemeaning="Infratemporal fossa"
		elif [ "${anatomyentry}" = "bone temporal infratemporal fossa" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="69541002"
			anatomycsd="SCT"
			anatomycodemeaning="Infratemporal fossa"
		elif [ "${anatomyentry}" = "bone temporal infra infratemporal fossa" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="69541002"
			anatomycsd="SCT"
			anatomycodemeaning="Infratemporal fossa"
		elif [ "${anatomyentry}" = "bone tibia" ]
		then
			anatomycodevalue="12611008"
			anatomycsd="SCT"
			anatomycodemeaning="Tibia"
		elif [ "${anatomyentry}" = "brain" ]
		then
			anatomycodevalue="12738006"
			anatomycsd="SCT"
			anatomycodemeaning="Brain"
		elif [ "${anatomyentry}" = "breast" ]
		then
			anatomycodevalue="76752008"
			anatomycsd="SCT"
			anatomycodemeaning="Breast"
		elif [ "${anatomyentry}" = "buttock" ]
		then
			anatomycodevalue="46862004"
			anatomycsd="SCT"
			anatomycodemeaning="Buttock"
		elif [ "${anatomyentry}" = "calf" ]
		then
			anatomycodevalue="53840002"
			anatomycsd="SCT"
			anatomycodemeaning="Calf"
		elif [ "${anatomyentry}" = "cervix" ]
		then
			anatomycodevalue="71252005"
			anatomycsd="SCT"
			anatomycodemeaning="Cervix"
		elif [ "${anatomyentry}" = "cheek" ]
		then
			anatomycodevalue="60819002"
			anatomycsd="SCT"
			anatomycodemeaning="Cheek"
		elif [ "${anatomyentry}" = "chin" ]
		then
			anatomycodevalue="30291003"
			anatomycsd="SCT"
			anatomycodemeaning="Chin"
		elif [ "${anatomyentry}" = "chest" ]
		then
			anatomycodevalue="43799004"
			anatomycsd="SCT"
			anatomycodemeaning="Chest"
		elif [ "${anatomyentry}" = "chest anterior" ]
		then
			anatomycodevalue="43799004"
			anatomycsd="SCT"
			anatomycodemeaning="Chest"
			anatomymodifiercodevalue="255549009"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Anterior"
		elif [ "${anatomyentry}" = "ear" ]
		then
			anatomycodevalue="117590005"
			anatomycsd="SCT"
			anatomycodemeaning="Ear"
		elif [ "${anatomyentry}" = "ear ear canal" ]
		then
			anatomycodevalue="84301002"
			anatomycsd="SCT"
			anatomycodemeaning="External auditory canal"
		elif [ "${anatomyentry}" = "ear periauricular" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="113327001"
			anatomycsd="SCT"
			anatomycodemeaning="Pinna"
			# not in DICOM subset :(
			anatomymodifiercodevalue="272447003"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Peri-location"
		elif [ "${anatomyentry}" = "ear middle ear" ]
		then
			anatomycodevalue="25342003"
			anatomycsd="SCT"
			anatomycodemeaning="Middle ear"
		elif [ "${anatomyentry}" = "elbow" ]
		then
			# not sure if this really is specific to the joint :(
			anatomycodevalue="16953009"
			anatomycsd="SCT"
			anatomycodemeaning="Elbow joint"
		elif [ "${anatomyentry}" = "epididymis" ]
		then
			anatomycodevalue="87644002"
			anatomycsd="SCT"
			anatomycodemeaning="Epididymis"
		elif [ "${anatomyentry}" = "eye" ]
		then
			anatomycodevalue="81745001"
			anatomycsd="SCT"
			anatomycodemeaning="Eye"
		elif [ "${anatomyentry}" = "eye orbit" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
		elif [ "${anatomyentry}" = "eye orbit anterior" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
			anatomymodifiercodevalue="255549009"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Anterior"
		elif [ "${anatomyentry}" = "eye orbit medial" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
			anatomymodifiercodevalue="255561001"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Medial"
		elif [ "${anatomyentry}" = "eyelid" ]
		then
			anatomycodevalue="80243003"
			anatomycsd="SCT"
			anatomycodemeaning="Eyelid"
		elif [ "${anatomyentry}" = "face head" ]
		then
			anatomycodevalue="69536005"
			anatomycsd="SCT"
			anatomycodemeaning="Head"
		elif [ "${anatomyentry}" = "face head parapharyngeal pterygoid" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="84765007"
			anatomycsd="SCT"
			anatomycodemeaning="Pterygoid region"
		elif [ "${anatomyentry}" = "foot" ]
		then
			anatomycodevalue="56459004"
			anatomycsd="SCT"
			anatomycodemeaning="Foot"
		elif [ "${anatomyentry}" = "forearm" ]
		then
			anatomycodevalue="14975008"
			anatomycsd="SCT"
			anatomycodemeaning="Forearm"
		elif [ "${anatomyentry}" = "groin" ]
		then
			anatomycodevalue="26893007"
			anatomycsd="SCT"
			anatomycodemeaning="Inguinal region"
		elif [ "${anatomyentry}" = "groin mass" ]
		then
			anatomycodevalue="26893007"
			anatomycsd="SCT"
			anatomycodemeaning="Inguinal region"
		elif [ "${anatomyentry}" = "hand" ]
		then
			anatomycodevalue="85562004"
			anatomycsd="SCT"
			anatomycodemeaning="Hand"
		elif [ "${anatomyentry}" = "infratemporal" ]
		then
			# assume infratemporal fossa :(
			# not in DICOM subset :(
			anatomycodevalue="69541002"
			anatomycsd="SCT"
			anatomycodemeaning="Infratemporal fossa"
		elif [ "${anatomyentry}" = "inguinal" ]
		then
			anatomycodevalue="26893007"
			anatomycsd="SCT"
			anatomycodemeaning="Inguinal region"
		elif [ "${anatomyentry}" = "kidney" ]
		then
			anatomycodevalue="64033007"
			anatomycsd="SCT"
			anatomycodemeaning="Kidney"
		elif [ "${anatomyentry}" = "l testicle mass" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
			lateralitycodevalue="7771000"
			lateralitycsd="SCT"
			lateralitycodemeaning="Left"
		elif [ "${anatomyentry}" = "leg" ]
		then
			# ambiguous -assume lower :(
			anatomycodevalue="30021000"
			anatomycsd="SCT"
			anatomycodemeaning="Lower leg"
		elif [ "${anatomyentry}" = "liver" ]
		then
			anatomycodevalue="10200004"
			anatomycsd="SCT"
			anatomycodemeaning="Liver"
		elif [ "${anatomyentry}" = "lung" ]
		then
			anatomycodevalue="39607008"
			anatomycsd="SCT"
			anatomycodemeaning="Lung"
		elif [ "${anatomyentry}" = "lymph node" ]
		then
			anatomycodevalue="59441001"
			anatomycsd="SCT"
			anatomycodemeaning="Lymph node"
		elif [ "${anatomyentry}" = "lymph node metastatic site" ]
		then
			# ignore the "metastatic site" :(
			anatomycodevalue="59441001"
			anatomycsd="SCT"
			anatomycodemeaning="Lymph node"
		elif [ "${anatomyentry}" = "mandible" ]
		then
			anatomycodevalue="91609006"
			anatomycsd="SCT"
			anatomycodemeaning="Mandible"
		elif [ "${anatomyentry}" = "maxillary sinus" ]
		then
			anatomycodevalue="15924003"
			anatomycsd="SCT"
			anatomycodemeaning="Maxillary sinus"
		elif [ "${anatomyentry}" = "mediastinum" ]
		then
			anatomycodevalue="72410000"
			anatomycsd="SCT"
			anatomycodemeaning="Mediastinum"
		elif [ "${anatomyentry}" = "mouth" ]
		then
			anatomycodevalue="123851003"
			anatomycsd="SCT"
			anatomycodemeaning="Mouth"
		elif [ "${anatomyentry}" = "muscle back" ]
		then
			# just assume back for now, without muscle qualifier :(
			anatomycodevalue="77568009"
			anatomycsd="SCT"
			anatomycodemeaning="Back"
		elif [ "${anatomyentry}" = "nasal" ]
		then
			anatomycodevalue="45206002"
			anatomycsd="SCT"
			anatomycodemeaning="Nose"
		elif [ "${anatomyentry}" = "nasal cavity" ]
		then
			anatomycodevalue="279549004"
			anatomycsd="SCT"
			anatomycodemeaning="Nasal cavity"
		elif [ "${anatomyentry}" = "nasal cavity supra" ]
		then
			# ignore supra for now :(
			anatomycodevalue="279549004"
			anatomycsd="SCT"
			anatomycodemeaning="Nasal cavity"
		elif [ "${anatomyentry}" = "nasal mass" ]
		then
			anatomycodevalue="45206002"
			anatomycsd="SCT"
			anatomycodemeaning="Nose"
		elif [ "${anatomyentry}" = "nasopharyngeal" ]
		then
			anatomycodevalue="360955006"
			anatomycsd="SCT"
			anatomycodemeaning="Nasopharynx"
		elif [ "${anatomyentry}" = "nasopharynx" ]
		then
			anatomycodevalue="360955006"
			anatomycsd="SCT"
			anatomycodemeaning="Nasopharynx"
		elif [ "${anatomyentry}" = "nasopharynx nose" ]
		then
			# ?? is this actually the nose proper and not the nasopharynx :(
			anatomycodevalue="360955006"
			anatomycsd="SCT"
			anatomycodemeaning="Nasopharynx"
		elif [ "${anatomyentry}" = "neck" ]
		then
			anatomycodevalue="45048000"
			anatomycsd="SCT"
			anatomycodemeaning="Neck"
		elif [ "${anatomyentry}" = "neck posterior" ]
		then
			anatomycodevalue="45048000"
			anatomycsd="SCT"
			anatomycodemeaning="Neck"
			anatomymodifiercodevalue="255551008"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Posterior"
		elif [ "${anatomyentry}" = "nose" ]
		then
			anatomycodevalue="45206002"
			anatomycsd="SCT"
			anatomycodemeaning="Nose"
		elif [ "${anatomyentry}" = "nose nasal cavity" ]
		then
			anatomycodevalue="279549004"
			anatomycsd="SCT"
			anatomycodemeaning="Nasal cavity"
		elif [ "${anatomyentry}" = "oral dorsal soft palate" ]
		then
			anatomycodevalue="49460000"
			anatomycsd="SCT"
			anatomycodemeaning="Soft palate"
			# dorsal is not in DICOM subset yet :(
			anatomymodifiercodevalue="255554000"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Dorsal"
		elif [ "${anatomyentry}" = "orbit" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
		elif [ "${anatomyentry}" = "orbital" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
		elif [ "${anatomyentry}" = "orbit anterior" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
			anatomymodifiercodevalue="255549009"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Anterior"
		elif [ "${anatomyentry}" = "orbit posterior" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
			anatomymodifiercodevalue="255551008"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Posterior"
		elif [ "${anatomyentry}" = "oropharynx" ]
		then
			anatomycodevalue="31389004"
			anatomycsd="SCT"
			anatomycodemeaning="Oropharynx"
		elif [ "${anatomyentry}" = "parapharyngeal" ]
		then
			anatomycodevalue="54066008"
			anatomycsd="SCT"
			anatomycodemeaning="Pharynx"
			anatomymodifiercodevalue="272444005"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "paraspinal posterior" ]
		then
			# 261148001 | Paraspinal (qualifier value) - not actually antomy
			anatomycodevalue="261148001"
			anatomycsd="SCT"
			anatomycodemeaning="Paraspinal"
			anatomymodifiercodevalue="255551008"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Posterior"
		elif [ "${anatomyentry}" = "paratesticular" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
			anatomymodifiercodevalue="272444005"
			# not in DICOM subset :(
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "paratestes" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
			# not in DICOM subset :(
			anatomymodifiercodevalue="272444005"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "parotid gland" ]
		then
			anatomycodevalue="45289007"
			anatomycsd="SCT"
			anatomycodemeaning="Parotid gland"
		elif [ "${anatomyentry}" = "pelvis" ]
		then
			anatomycodevalue="816092008"
			anatomycsd="SCT"
			anatomycodemeaning="Pelvis"
		elif [ "${anatomyentry}" = "pelvis prostate" ]
		then
			anatomycodevalue="41216001"
			anatomycsd="SCT"
			anatomycodemeaning="Prostate"
		elif [ "${anatomyentry}" = "peri rectal mass" ]
		then
			# Perirectal region is not in DICOM subset yet :(
			anatomycodevalue="13170006"
			anatomycsd="SCT"
			anatomycodemeaning="Perirectal region"
		elif [ "${anatomyentry}" = "perianal" ]
		then
			# Perianal region is not in DICOM subset yet :(
			anatomycodevalue="397158004"
			anatomycsd="SCT"
			anatomycodemeaning="Perianal region"
		elif [ "${anatomyentry}" = "perineum" ]
		then
			anatomycodevalue="38864007"
			anatomycsd="SCT"
			anatomycodemeaning="Perineum"
		elif [ "${anatomyentry}" = "peritoneum" ]
		then
			anatomycodevalue="15425007"
			anatomycsd="SCT"
			anatomycodemeaning="Peritoneum"
		elif [ "${anatomyentry}" = "pharynx" ]
		then
			anatomycodevalue="54066008"
			anatomycsd="SCT"
			anatomycodemeaning="Pharynx"
		elif [ "${anatomyentry}" = "pharynx para" ]
		then
			anatomycodevalue="54066008"
			anatomycsd="SCT"
			anatomycodemeaning="Pharynx"
			anatomymodifiercodevalue="272444005"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "pharynx parapharyngeal" ]
		then
			anatomycodevalue="54066008"
			anatomycsd="SCT"
			anatomycodemeaning="Pharynx"
			anatomymodifiercodevalue="272444005"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "prostate" ]
		then
			anatomycodevalue="41216001"
			anatomycsd="SCT"
			anatomycodemeaning="Prostate"
		elif [ "${anatomyentry}" = "prostate peri" ]
		then
			# Periprostatic tissue is not in DICOM subset yet :( There is no "region" in SCT
			anatomycodevalue="37446007"
			anatomycsd="SCT"
			anatomycodemeaning="Periprostatic tissue"
		elif [ "${anatomyentry}" = "retroperitoneal" ]
		then
			anatomycodevalue="82849001"
			anatomycsd="SCT"
			anatomycodemeaning="Retroperitoneum"
		elif [ "${anatomyentry}" = "retroperitoneum" ]
		then
			anatomycodevalue="82849001"
			anatomycsd="SCT"
			anatomycodemeaning="Retroperitoneum"
		elif [ "${anatomyentry}" = "retropharynx" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="789564000"
			anatomycsd="SCT"
			anatomycodemeaning="Retropharyngeal space"
		elif [ "${anatomyentry}" = "scalp" ]
		then
			anatomycodevalue="41695006"
			anatomycsd="SCT"
			anatomycodemeaning="Scalp"
		elif [ "${anatomyentry}" = "scrotal" ]
		then
			anatomycodevalue="20233005"
			anatomycsd="SCT"
			anatomycodemeaning="Scrotum"
		elif [ "${anatomyentry}" = "scrotum" ]
		then
			anatomycodevalue="20233005"
			anatomycsd="SCT"
			anatomycodemeaning="Scrotum"
		elif [ "${anatomyentry}" = "shoulder" ]
		then
			anatomycodevalue="16982005"
			anatomycsd="SCT"
			anatomycodemeaning="Shoulder"
		elif [ "${anatomyentry}" = "skin buttock" ]
		then
			anatomycodevalue="22180002"
			anatomycsd="SCT"
			anatomycodemeaning="Skin of buttock"
		elif [ "${anatomyentry}" = "skull base" ]
		then
			# Base of skull is not in DICOM subset yet :(
			anatomycodevalue="31467002"
			anatomycsd="SCT"
			anatomycodemeaning="Base of skull"
		elif [ "${anatomyentry}" = "soft palate" ]
		then
			anatomycodevalue="49460000"
			anatomycsd="SCT"
			anatomycodemeaning="Soft palate"
		elif [ "${anatomyentry}" = "spermatic cord" ]
		then
			# Spermatic cord is not in DICOM subset yet :(
			anatomycodevalue="49957000"
			anatomycsd="SCT"
			anatomycodemeaning="Spermatic cord"
		elif [ "${anatomyentry}" = "spinal cord" ]
		then
			anatomycodevalue="2748008"
			anatomycsd="SCT"
			anatomycodemeaning="Spinal cord"
		elif [ "${anatomyentry}" = "spinal cord para" ]
		then
			# ?? "paraspinal" means around the bony spinal column :(
			# cf. "paraspinal posterior" entry
			anatomycodevalue="2748008"
			anatomycsd="SCT"
			anatomycodemeaning="Spinal cord"
			anatomymodifiercodevalue="272444005"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "spine" ]
		then
			anatomycodevalue="421060004"
			anatomycsd="SCT"
			anatomycodemeaning="Spine"
		elif [ "${anatomyentry}" = "temple" ]
		then
			# not in DICOM subset :(
			anatomycodevalue="450721000"
			anatomycsd="SCT"
			anatomycodemeaning="Temporal region"
		elif [ "${anatomyentry}" = "testcle" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
		elif [ "${anatomyentry}" = "testicle" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
		elif [ "${anatomyentry}" = "testicle extratesticular" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
			# not in DICOM subset :(
			anatomymodifiercodevalue="272437001"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Extra-location"
		elif [ "${anatomyentry}" = "testicle para" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
			# not in DICOM subset :(
			anatomymodifiercodevalue="272444005"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Para-location"
		elif [ "${anatomyentry}" = "testis" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
		elif [ "${anatomyentry}" = "thigh" ]
		then
			anatomycodevalue="68367000"
			anatomycsd="SCT"
			anatomycodemeaning="Thigh"
		elif [ "${anatomyentry}" = "thigh mass" ]
		then
			anatomycodevalue="68367000"
			anatomycsd="SCT"
			anatomycodemeaning="Thigh"
		elif [ "${anatomyentry}" = "thigh posterior" ]
		then
			anatomycodevalue="68367000"
			anatomycsd="SCT"
			anatomycodemeaning="Thigh"
			anatomymodifiercodevalue="255551008"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Posterior"
		elif [ "${anatomyentry}" = "thigh upper" ]
		then
			anatomycodevalue="68367000"
			anatomycsd="SCT"
			anatomycodemeaning="Thigh"
			# Upper is not in DICOM subset yet :(
			anatomymodifiercodevalue="261183002"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Upper"
		elif [ "${anatomyentry}" = "tonsil" ]
		then
			anatomycodevalue="17861009"
			anatomycsd="SCT"
			anatomycodemeaning="Oropharyngeal tonsil"
		elif [ "${anatomyentry}" = "uterus" ]
		then
			anatomycodevalue="35039007"
			anatomycsd="SCT"
			anatomycodemeaning="Uterus"
		elif [ "${anatomyentry}" = "uvula" ]
		then
			anatomycodevalue="26140008"
			anatomycsd="SCT"
			anatomycodemeaning="Uvula"
		elif [ "${anatomyentry}" = "vagina" ]
		then
			anatomycodevalue="76784001"
			anatomycsd="SCT"
			anatomycodemeaning="Vagina"
		elif [ "${anatomyentry}" = "vulva" ]
		then
			anatomycodevalue="45292006"
			anatomycsd="SCT"
			anatomycodemeaning="Vulva"
		elif [ "${anatomyentry}" = "wrist" ]
		then
			# not sure if this really is specific to the joint :(
			anatomycodevalue="74670003"
			anatomycsd="SCT"
			anatomycodemeaning="Wrist joint"
		else
			echo 1>&2 "Warning: unrecognized body site \"${anatomyentry}\" for sample_id ${sample_id}"
		fi
	fi
fi

echo "patient_id = ${patient_id}"

echo "anatomycodemeaning = ${anatomycodemeaning}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

if [ -f "${CSVFILENAMEFORPARTICIPANT}" ]
then
	# type,study.phs_accession,participant_id,race,gender,ethnicity
	# ,,RMS2277,White,Male,Not Hispanic or Latino
	csvlineforparticipant=`grep ",${patient_id}," "${CSVFILENAMEFORPARTICIPANT}" | head -1`
	echo "csvlineforparticipant = ${csvlineforparticipant}"
fi

if [ -z "${csvlineforparticipant}" ]
then
	echo 1>&2 "Warning: cannot find participant metadata CSV file entry for patient_id ${patient_id} from which to extract patient characteristics"
else
	race=`echo "${csvlineforparticipant}" | awk -F, '{print $4}'`
	gender=`echo "${csvlineforparticipant}" | awk -F, '{print $5}'`
	#ethnicity=`echo "${csvlineforparticipant}" | awk -F, '{print $6}'`
fi

if [ -f "${CSVFILENAMEFORDIAGNOSIS}" ]
then
	# type,participant.participant_id,diagnosis_id,disease_type,primary_diagnosis,primary_diagnosis_reference_source,primary_site,age_at_diagnosis,days_to_recurrence,last_known_disease_status,days_to_last_known_disease_status,tissue_or_organ_of_origin,days_to_last_followup,progression_or_recurrence,site_of_resection_or_biopsy
	# ,RMS2277,,"Soft Tissue Tumors and Sarcomas, NOS","Rhabdomyosarcoma (RMS), embryonal",,"Pelvis, site indeterminate",4.33, ,No event,,,1555,,
	csvlinefodiagnosis=`grep ",${patient_id}," "${CSVFILENAMEFORDIAGNOSIS}" | head -1`
	echo "csvlinefodiagnosis = ${csvlinefodiagnosis}"
fi

if [ -z "${csvlinefodiagnosis}" ]
then
	echo 1>&2 "Warning: cannot find diagnosis metadata CSV file entry for patient_id ${patient_id} from which to extract patient characteristics"
else
	# some columns preceding age are sometimes quoted and sometimes not, so search for 1st numeric value (which may or mey not be floating point) after non-numeric string and before Metastatic or Non-metastatic
	# diagnosis,RMS2448,,"Soft Tissue Tumors and Sarcomas, NOS",Rhabdomyosarcoma,,Scalp,6.94,Non-metastatic,1, ,No event,,,4186,,
	# diagnosis,RMS2472,,"Soft Tissue Tumors and Sarcomas, NOS",Rhabdomyosarcoma,,"Pelvis, site indeterminate",6.87,Non-metastatic (unconfirmed),3, ,SMN,,,3247,,
	age=`echo "${csvlinefodiagnosis}" | sed -e 's/^.*[a-z"],\([0-9.][0-9.]*\),[NM].*$/\1/'`
	if [ "${age}" = "${csvlinefodiagnosis}" ]
	then
		# didn't work
		age=""
	fi
	echo "age = ${age}"

	# sometimes there is a conflict between differnt metadata files, e.g. :(
	# csvlineforsample = RMS2502,PATHRZ,SPINDLE CELL RHABDOMYOSARCOMA,FN,Low,3099,3099,0,0,Intermediate,0.37386214
	# csvlineforparticipant = ,,RMS2502,White,Male,Not Hispanic or Latino
	# csvlinefodiagnosis = ,RMS2502,,"Soft Tissue Tumors and Sarcomas, NOS",Embryonal Rhabdomyosarcoma,,Nasopharynx (PM),5.07, ,No event,,,2715,,
	# use the CSVFILENAMEFORDIAGNOSIS rather than the CSVFILENAMEFORSAMPLE file for now :(

	# "Soft Tissue Tumors and Sarcomas, NOS" is always present in column preceding primary_diagnosis
	diagnosis=`echo "${csvlinefodiagnosis}" | sed -e 's/^.*"Soft Tissue Tumors and Sarcomas, NOS","\([^"]*\)",.*$/\1/'`
	if [ "${diagnosis}" = "${csvlinefodiagnosis}" ]
	then
		# was not quoted, so must not contain comma
		diagnosis=`echo "${csvlinefodiagnosis}" | sed -e 's/^.*"Soft Tissue Tumors and Sarcomas, NOS",\([^,]*\),.*$/\1/'`
		if [ "${diagnosis}" = "${csvlinefodiagnosis}" ]
		then
			# didn't work
			diagnosis=""
		fi
	fi
	echo "diagnosis = ${diagnosis}"
fi

#if [ -f "${CSVFILENAMEFORSPECIMENDETAILMANIFEST}" ]
#then
	# USI,H&E Image on Hard Drive,SpecimenType,Protocols,Timepoint,BlockNo,SiteType,% Tumor vs. % Necrosis,% Tumor vs. %Stroma,Comments,,,,,,,,,,,,,
	# PARPDV-0BLRWU,1,Paraffin Stained Primary H&E,D9902,Diagnosis,A2,"Soft tissue, pelvis-left",100,100,,,,,,,,,,,,,,
	# NB. multiple entries in column may result in quotes around strings not normally quoted, so don't rely on position too much
	# just in case there is more than one block for the same specimen ...
#	if [ -z "${block_id}" ]
#	then
#		csvlineforspecimendetailmanifest=`grep "^${specimen_id}," "${CSVFILENAMEFORSPECIMENDETAILMANIFEST}" | head -1`
#	else
#		csvlineforspecimendetailmanifest=`grep "^${specimen_id}," "${CSVFILENAMEFORSPECIMENDETAILMANIFEST}" | grep ",${block_id}," | head -1`
#	fi
#	echo "csvlineforspecimendetailmanifest = ${csvlineforspecimendetailmanifest}"
#fi

fixation=""
staining=""
if [ -f "${CSVFILENAMEFORIMAGING}" ]
then
	csvlineforimaging=`grep ",${sample_id}," "${CSVFILENAMEFORIMAGING}" | head -1`
	echo "csvlineforimaging = ${csvlineforimaging}"
fi

if [ -z "${csvlineforimaging}" ]
then
	echo 1>&2 "Warning: cannot find metadata CSV file entry for sample_id ${sample_id} from which to extract fixation and staining"
else
	# ignore position in case quoted
	isffpehe=`echo "${csvlineforimaging}" | fgrep 'FFPE_H&E_Image'`
	if [ ! -z "${isffpehe}" ]
	then
		fixation="FFPE"
		staining="HE"
	fi
fi

echo "fixation = ${fixation}"
echo "staining = ${staining}"

echo "compressedvariant = ${compressedvariant}"
echo "outdir = ${outdir}"

dicompatientid="${patient_id}"
dicompatientname="${dicompatientid}"

# could try to describe creation of block from parent specimen, or whether specimen used in DICOM is of block or parent specimen, but hold off for now :(
dicomspecimenidentifier="${specimen_id}"
#dicomparentspecimenidentifier=""
if [ ! -z "${block_id}" ]
then
	#dicomparentspecimenidentifier="${dicomspecimenidentifier}"
	dicomspecimenidentifier="${dicomspecimenidentifier}_${block_id}"
fi

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
	# age at diagnosis is in years and may be fractional and small (pediatric disease), so convert to months to preserve precision ...
	echo "age = ${age}"
	# division by unity because bc scale recognition is finicky (https://stackoverflow.com/questions/13963265/bc-is-ignoring-scale-option)
	ageinmonths=`echo "scale=0; (${age} * 12)/1" | bc -l`
	echo "ageinmonths = ${ageinmonths}"
	if [ ${ageinmonths} -ge 999 ]
	then
		# won't fit in months (over 83.25 years) so convert back to years as integer ...
		ageinyearsint=`echo "scale=0; ${age} / 12" | bc -l`
		echo "ageinyearsint = ${ageinyearsint}"
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

dicomethnicgroup=""
# SH, so limited to 16 characters
if [ "${race}" = "American Indian or Alaska Native" ]
then
	dicomethnicgroup="American Indian"
elif [ "${race}" = "American Indian/Alaska Native" ]
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
elif [ "${race}" != "Unknown or not reported" -a ! -z "${race}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized race ${race}"
fi
echo "dicomethnicgroup = ${dicomethnicgroup}"

dicomdiagnosisdescription=""
dicomdiagnosiscodevalue=""
dicomdiagnosiscsd=""
dicomdiagnosiscodemeaning=""
if [ ! -z "${diagnosis}" ]
then
	diagnosislc=`echo "${diagnosis}" | tr '[A-Z]' '[a-z]'`
	if [ "${diagnosislc}" != "no data" ]
	then
		dicomdiagnosisdescription="${diagnosis}"
		# use SCT disorder rather than morphologic abnormality codes when both; none of these are in DICOM subset (yet) :(
		if [ "${diagnosislc}" = "alveolar rhabdomyosarcoma" ]
		then
			# ICD-O-3 M8920/3 (Alveolar rhabdomyosarcoma)
			dicomdiagnosiscodevalue="404053004"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Alveolar rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "botryoid rhabdomyosarcoma" ]
		then
			# not in ICD-O-3
			dicomdiagnosiscodevalue="404052009"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Botryoid rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "embryonal rhabdomyosarcoma" ]
		then
			# ICD-O-3 M8910/3 (Embryonal rhabdomyosarcoma, NOS)
			dicomdiagnosiscodevalue="404051002"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Embryonal rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "embryonal rhabdomyosarcoma with presence of ganglion cells (ectomesenchymoma)" ]
		then
			# ICD-O-3 M8921/3 (Rhabdomyosarcoma with ganglionic differentiation)
			dicomdiagnosiscodevalue="128750008"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Rhabdomyosarcoma with ganglionic differentiation"
		elif [ "${diagnosislc}" = "mixed embryonal/alveolar rhabdomyosarcoma" ]
		then
			# this is problematic since FSN is just "Mixed type rhabdomyosarcoma (morphologic abnormality)" though synonym is specifically embryonal/alveolar :(
			# same is true in ICD-O-3 (ICD-O-3.2_final_update09102020.xls):
			# 8902/3,Preferred,Mixed type rhabdomyosarcoma
			# 8902/3,Related,Mixed embryonal rhabdomyosarcoma and alveolar rhabdomyosarcoma
			dicomdiagnosiscodevalue="62383007"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Mixed embryonal rhabdomyosarcoma and alveolar rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "mixed embryonal/spindle cell rhabdomyosarcoma" ]
		then
			# can't find specific code :(
			dicomdiagnosiscodevalue="302847003"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "mixed spindle cell/embryonal rhabdomyosarcoma" ]
		then
			# can't find specific code :(
			dicomdiagnosiscodevalue="302847003"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "rhabdomyosarcoma" ]
		then
			# ICD-O-3 M8900/3 (Rhabdomyosarcoma, NOS)
			dicomdiagnosiscodevalue="302847003"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "rhabdomyosarcoma (rms)" ]
		then
			# ICD-O-3 M8900/3 (Rhabdomyosarcoma, NOS)
			dicomdiagnosiscodevalue="302847003"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "rhabdomyosarcoma (rms), embryonal" ]
		then
			# ICD-O-3 M8910/3 (Embryonal rhabdomyosarcoma, NOS)
			dicomdiagnosiscodevalue="404051002"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Embryonal rhabdomyosarcoma"
		elif [ "${diagnosislc}" = "rhabdomyosarcoma, nos" ]
		then
			# ICD-O-3 M8900/3 (Rhabdomyosarcoma, NOS)
			dicomdiagnosiscodevalue="302847003"
			dicomdiagnosiscsd="SCT"
			dicomdiagnosiscodemeaning="Rhabdomyosarcoma"
		else
			# there appear to be no (non-mixed) spindle cell rhabdomyosarcoma in the data (would be SCT:404055006)
			# ICD-O-3 M8912/3 (Spindle cell rhabdomyosarcoma)
			# ICD-O-3 M8901/3 (Pleomorphic rhabdomyosarcoma, NOS)
			# ICD-O-3 M8902/3 (Mixed type rhabdomyosarcoma)
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

dicomspecimenshortdescription="${fixation} ${staining}"
echo "dicomspecimenshortdescription = ${dicomspecimenshortdescription}"

dicomspecimendetaileddescription=""
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
	echo >>"${TMPJSONFILE}" "	\"PatientSex\" : \"${dicomsex}\","
fi
if [ ! -z "${dicomdiagnosisdescription}" ]
then
	echo >>"${TMPJSONFILE}" "	\"AdmittingDiagnosesDescription\" : \"${dicomdiagnosisdescription}\","
fi
if [ ! -z "${dicomdiagnosiscodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	\"AdmittingDiagnosesCodeSequence\" : { \"cv\" : \"${dicomdiagnosiscodevalue}\", \"csd\" : \"${dicomdiagnosiscsd}\", \"cm\" : \"${dicomdiagnosiscodemeaning}\" },"
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
if [ "${staining}" = "HE" ]
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
fi
echo >>"${TMPJSONFILE}" "		      }"
if [ ! -z "${anatomycodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "	    ],"
	if [ -z "${lateralitycodevalue}" -a -z "${anatomymodifiercodevalue}" ]
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
		elif [ "${firstifdsamplesperpixel}" = "1" -a "${firstifdbitspersample}" = "16" ]
		then
			echo "Uncompressed or LZW compressed single channel 16 bit so requesting J2K Reversible compression"
			transfersyntaxargs="1.2.840.10008.1.2.4.90"
		fi
	else
		echo "Uncompressed or LZW compressed and when decompressed is less than 2GB"
	fi
fi
echo "transfersyntaxargs=${transfersyntaxargs}"

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
	ADDTIFF MERGESTRIPS DONOTADDDCMSUFFIX INCLUDEFILENAME
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
