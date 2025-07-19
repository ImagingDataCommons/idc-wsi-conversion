#!/bin/sh
#
# Usage: ./mcitodcm.sh folder/filename.svs [outdir]

# #### NOW DEPENDS ON csvtool installed (pip3 install csvtool) and in path (e.g., "~/Library/Python/3.9/bin")

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"
TMPFILEDESCRIBINGMULTIPLESAMPLES="/tmp/`basename $0`.samples.$$"

# make sure have performed dos2unix ICD-O-3.2_final_update09102020.csv so that CR is not included in extracted text
ICDOFILE="ICD-O-3.2_final_update09102020.csv"

#METADATABASE="MCI_metatdata_CCDI_v1.7.MCI_Metadata_manifest_v1.6.0_CatchERR20231011_wpathology_CatchERR20231011"
#METADATABASE="MCI_metatdata_CCDI_v1.7.2_wPath_CatchERR20240118"
#METADATABASE="MCI_Metadata_manifest_1-25_updated_Pathology_files_CatchERR20240613_CatchERR20240613"
#METADATABASE="Submission2_CCDI_v1.9.1_phs002790_CatchERR20240816"
#METADATABASE="Submission3_phs002790_MCI_CCDI_v1.9.1_Oct2024_Release30"
#METADATABASE="phs002790_MCI_CCDI_v2.0.0_Dec2024_Release33_IDC_Submission4"
#METADATABASE="phs002790_MCI_Release35_CCDI_v2.1.0_IDC_Submission_5"
METADATABASE="phs002790_MCI_Release38_CCDI_v2.1.0_IDC_Submission_6"

CSVFILENAMEFORSAMPLE="${METADATABASE}_sample.csv"
if [ ! -f "${CSVFILENAMEFORSAMPLE}" ]
then
	echo 1>&2 "Error: no sample metadata CSV file called ${CSVFILENAMEFORSAMPLE}"
	exit 1
fi

CSVFILENAMEFORIMAGING="${METADATABASE}_pathology_file.csv"
if [ ! -f "${CSVFILENAMEFORIMAGING}" ]
then
	echo 1>&2 "Error: no pathology_file metadata CSV file called ${CSVFILENAMEFORIMAGING}"
	exit 1
fi

CSVFILENAMEFORPARTICIPANT="${METADATABASE}_participant.csv"
if [ ! -f "${CSVFILENAMEFORPARTICIPANT}" ]
then
	echo 1>&2 "Error: no participant metadata CSV file called ${CSVFILENAMEFORPARTICIPANT}"
	exit 1
fi

CSVFILENAMEFORDIAGNOSIS="${METADATABASE}_diagnosis.csv"
if [ ! -f "${CSVFILENAMEFORDIAGNOSIS}" ]
then
	echo 1>&2 "Error: no diagnosis metadata CSV file called ${CSVFILENAMEFORDIAGNOSIS}"
	exit 1
fi

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="MCIspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="MCIstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="MCIstudyIDToDateTimeMap.csv"

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

dicomclinicaltrialcoordinatingcentername="Nationwide Children's Hospital"
# exactly 64 chars
dicomclinicaltrialsponsorname="National Cancer Institute (NCI) Childhood Cancer Data Initiative"
# lowercase "phs" as used in study.study_id and "https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/study.cgi?study_id=phs002790.v3.p1"
dicomclinicalprotocolid="phs002790"
issuerofdicomclinicalprotocolid="dbGaP"
# study.study_short_title
#dicomclinicalprotocolname="Childhood Cancer Data Initiative (CCDI): Molecular Characterization Initiative"
#needs to be <= 64 chars
dicomclinicalprotocolname="CCDI Molecular Characterization Initiative"
doiclinicalprotocolid="doi:10.5281/zenodo.11099087"
dicomclinicaltrialsiteid=""

# "idc-source-data-mci/0DAX7K_120804.svs"
# "idc-source-data-mci/0DNA2S.svs"

# do not remove suffix '.svs' from filename since need to match what is in CSVFILENAMEFORIMAGING
filename=`basename "${infile}"`
foldername=`dirname "${infile}"`

#slide_id=`echo ${filename} | sed -e 's/^\([A-Z0-9]*_[A-Z0-9]*\).*$/\1/'`
slide_id=`echo ${filename} | sed -e 's/^\([A-Z0-9_]*\).*$/\1/'`
# slide_id = 0DAX7K_120804
# slide_id = 0DNA2S

if [ -z "${outdir}" ]
then
	# note: variation between '_' and '-' use will be harmonized to '_' ...
	outdir="Converted/${slide_id}"
fi

if [ -f "${CSVFILENAMEFORIMAGING}" ]
then
	# OLD:type,sample.sample_id,pdx.pdx_id,cell_line.cell_line_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_url_in_cds,dcf_indexd_guid,magnification,fixation_embedding_method,staining_method,deidentification_method,file_mapping_level,id,sample.id,pdx.id,cell_line.id
	# OLD:type,sample.sample_id,pdx.pdx_id,cell_line.cell_line_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_url_in_cds,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,file_mapping_level,id,sample.id,pdx.id,cell_line.id
	# OLD:type,sample.sample_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_mapping_level,file_access,acl,authz,file_url,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,id,sample.id
	# type,sample.sample_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_mapping_level,file_access,acl,authz,file_url,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,id,sample.id
	# round 4 inserts extra column before column 5 for data_category
	# type,sample.sample_id,pathology_file_id,file_name,data_category,file_type,file_description,file_size,md5sum,file_mapping_level,file_access,acl,authz,file_url,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,crdc_id,id,sample.id
	# round 5 inserts extra column near end of line for slim_url
	# type,sample.sample_id,pathology_file_id,file_name,data_category,file_type,file_description,file_size,md5sum,file_mapping_level,file_access,acl,authz,file_url,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,slim_url,crdc_id,id,sample.id

	# OLD:pathology_file,0DB9NX,,,0DB9NX_0DAX7K_120804.svs,0DAX7K_120804.svs,svs,,405040431,c76dbd73aea635f4faab6e4a27f38eae,,dg.4DFC/c11ab7c7-bb67-4db1-9295-f154ad12acba,40X,Optimal Cutting Temperature,Hematoxylin and Eosin Staining Method,Not applicable,,,,,
	# OLD:pathology_file,0DB9NX,,,0DAX7K_120804.svs_1,0DAX7K_120804.svs,svs,,405040431,c76dbd73aea635f4faab6e4a27f38eae,s3://TBD/,dg.4DFC/ce953bd0-f1e7-4117-a358-ff491153b894,Slide Microscopy,CC by 4.0,40X,OCT,H&E,Not applicable,100,0,,,,,
	# OLD:pathology_file,0DC7SV,0DC67X_172159.svs_2,0DC67X_172159.svs,svs,,233376443,72548664381cbbcad72acd9a2140d239,Sample,Open,['*'],['/open'],s3://TBD/,dg.4DFC/bf8c7bbc-f2c1-4793-b50a-4fb38a3c97bb,Slide Microscopy,CC by 4.0,40X,Formalin fixed paraffin embedded (FFPE),H&E,automatic,90,0,,
	# pathology_file,0D8ODV,0D8LCB_142727.svs_1,0D8LCB_142727.svs,svs,,182270463,2131afc6c5ad91417002eace6b25588d,Sample,Open,['*'],['/open'],s3://TBD/,dg.4DFC/c35f4043-6770-4f31-967a-4dffab3e0f7a,Slide Microscopy,CC by 4.0,40X,Formalin fixed paraffin embedded (FFPE),H&E,automatic,90,0,,
	# round 4 inserts extra column before column 5 for data_category
	# pathology_file,0DL0J0,00008833-e794-4d9b-947c-b3496c126336.dcm_1,00008833-e794-4d9b-947c-b3496c126336.dcm,Pathology Imaging,dicom,,26746060,b48966f35d3cd38d67b75d3bb5082f9b,Sample,Open,['*'],['/open'],s3://idc-open-data/e4d5cae5-dc21-43d7-ac78-ff728c378c36/00008833-e794-4d9b-947c-b3496c126336.dcm,dg.4DFC/00008833-e794-4d9b-947c-b3496c126336,Slide Microscopy,CC by 4.0,40X,Formalin fixed paraffin embedded (FFPE),H&E,manual,,,,,
	# round 5 inserts extra column near end of line for slim_url
	# pathology_file,0DL0J0,00008833-e794-4d9b-947c-b3496c126336.dcm_1,00008833-e794-4d9b-947c-b3496c126336.dcm,Pathology Imaging,dicom,,26746060,b48966f35d3cd38d67b75d3bb5082f9b,Sample,Open,['*'],['/open'],s3://idc-open-data/e4d5cae5-dc21-43d7-ac78-ff728c378c36/00008833-e794-4d9b-947c-b3496c126336.dcm,dg.4DFC/00008833-e794-4d9b-947c-b3496c126336,Slide Microscopy,CC by 4.0,40X,Formalin fixed paraffin embedded (FFPE),H&E,manual,80,10,https://viewer.imaging.datacommons.cancer.gov/slim/studies/2.25.250394153002116490243339749421147108109/series/1.3.6.1.4.1.5962.99.1.1877722598.1646631702.1719864673766.4.0,,,

	# we expect multiple samples on one slide for this project, so 'head -1' is important
	csvlineforimagingtogetpatientid=`grep ",${filename}," "${CSVFILENAMEFORIMAGING}" | head -1`
	echo "csvlineforimagingtogetpatientid = ${csvlineforimagingtogetpatientid}"
fi

if [ -z "${csvlineforimagingtogetpatientid}" ]
then
	#echo 1>&2 "Warning: cannot find metadata CSV file entry for sample_id ${sample_id} from which to ultimately lookup participant_id"
	echo 1>&2 "Warning: cannot find metadata CSV file entry for filename ${filename} from which to ultimately lookup participant_id"
else
	sample_id_togetpatientid=`echo "${csvlineforimagingtogetpatientid}" | csvtool -c 2 | tr -d '"'`
	echo "sample_id_togetpatientid = ${sample_id_togetpatientid}"
fi

if [ -z "${sample_id_togetpatientid}" ]
then
	echo 1>&2 "Error: cannot find metadata CSV file entry for filename ${filename} to get sample_id from which to extract patient_id and anatomy"
	exit 1
fi

if [ -f "${CSVFILENAMEFORSAMPLE}" ]
then
	# OLD:type,participant.participant_id,sample_id,anatomic_site,participant_age_at_collection,diagnosis_icd_o,diagnosis_finer_resolution,sample_tumor_status,tumor_classification,sample_description,alternate_sample_id,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,diagnosis_icd_cm,id,participant.id
	# OLD:type,participant.participant_id,cell_line.cell_line_id,pdx.pdx_id,sample_id,anatomic_site,participant_age_at_collection,diagnosis_classification,diagnosis_classification_system,diagnosis_verification_status,diagnosis_basis,diagnosis_comment,sample_tumor_status,tumor_classification,sample_description,alternate_sample_id,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,id,participant.id,cell_line.id,pdx.id
	# type,participant.participant_id,pdx.pdx_id,cell_line.cell_line_id,sample_id[5],anatomic_site[6],participant_age_at_collection[7],sample_tumor_status[8],tumor_classification,sample_description,id,participant.id,pdx.id,cell_line.id
	# round 5 moves column tumor_classification from after sample_tumor_status to before anatomic_site
	# type,participant.participant_id,pdx.pdx_id,cell_line.cell_line_id,sample_id[5],tumor_classification[6],anatomic_site[7],participant_age_at_collection[8],sample_tumor_status[9],sample_description,crdc_id,id,participant.id,pdx.id,cell_line.id

	# OLD:sample,PANLMU,0DHY31,Blood,-999,"999 : Unknown, to be completed later",,Normal,Not Applicable,,,,,,,,,,,,
	# OLD:sample,PANLMU,,,0DHY31,C42.0 : Blood,-999,see diagnosis_comment,Indication for Study,Not Reported,Not Reported,Meningioma,Normal,Not Applicable,,,,,,,,,,,,,
	# sample,PBCWKJ,,,0E1HF8,C72.9 : Central nervous system,-999,Tumor,Not Reported,,,,,
	# round 5 moves column tumor_classification from after sample_tumor_status to before anatomic_site
	# sample,PBCYMW,,,0E2VSZ,Not Reported,C72.9 : Central nervous system,-999,Tumor,,,,,,

	csvlineforsampletogetpatientid=`grep ",${sample_id_togetpatientid}," "${CSVFILENAMEFORSAMPLE}" | head -1`
	echo "csvlineforsampletogetpatientid = ${csvlineforsampletogetpatientid}"
fi

if [ -z "${csvlineforsampletogetpatientid}" ]
then
	echo 1>&2 "Error: cannot find metadata CSV file entry for sample_id ${sample_id_togetpatientid} from which to extract patient_id and anatomy"
	exit 1
else
	patient_id=`echo "${csvlineforsampletogetpatientid}" | csvtool -c 2 | tr -d '"'`
fi

echo "patient_id = ${patient_id}"
echo "patient_id = ${patient_id} for sample_id = ${sample_id_togetpatientid} and filename = ${filename}"

dicomclinicaltrialsubjectid="${patient_id}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

if [ -f "${CSVFILENAMEFORPARTICIPANT}" ]
then
	# gender is now sex_at_birth
	# OLD: type,study.study_id,participant_id,race,sex_at_birth,ethnicity,alternate_participant_id,id,study.id
	# type,study.study_id,participant_id,race,sex_at_birth,id,study.id
	# round 4 adds crdc_id
	# type,study.study_id,participant_id,race,sex_at_birth,crdc_id,id,study.id

	# OLD: participant,phs002790,PANLMU,White,Female,Not Hispanic or Latino,,,
	# participant,phs002790,PBCMMP,Native Hawaiian or other Pacific Islander,Male,,
	# round 4 adds crdc_id
	# participant,phs002790,PANLMU,White,Female,,,

	csvlineforparticipant=`grep ",${patient_id}," "${CSVFILENAMEFORPARTICIPANT}" | head -1`
	echo "csvlineforparticipant = ${csvlineforparticipant}"
fi

if [ -z "${csvlineforparticipant}" ]
then
	echo 1>&2 "Warning: cannot find participant metadata CSV file entry for patient_id ${patient_id} from which to extract patient characteristics"
else
	race=`echo "${csvlineforparticipant}" | csvtool -c 4 | tr -d '"'`
	sex_at_birth=`echo "${csvlineforparticipant}" | csvtool -c 5 | tr -d '"'`
	#ethnicity=`echo "${csvlineforparticipant}" | csvtool -c 6 | tr -d '"'`
fi

echo "race = ${race}"
echo "sex_at_birth = ${sex_at_birth}"
#echo "ethnicity = ${ethnicity}"

# we have multiple samples on one slide, so use the slide_id as the combined specimen_id for now :(
specimen_id="${slide_id}"

echo "infile = ${infile}"
echo "filename = ${filename}"
echo "slide_id = ${slide_id}"
#sample_id handled later as multiple
#specimen_id handled later as multiple

diagnosisdescription=""
dicomdiagnosisdescription=""
additionalpatienthistory=""
diagnosiscodevalue=""
diagnosiscsd=""
diagnosiscodemeaning=""

anatomycodevalue=""
anatomycsd=""
anatomycodemeaning=""
lateralitycodevalue=""
lateralitycsd=""
lateralitycodemeaning=""
anatomymodifiercodevalue=""
anatomymodifiercsd=""
anatomymodifiercodemeaning=""

if [ -f "${CSVFILENAMEFORDIAGNOSIS}" ]
then
	# type,participant.participant_id,diagnosis_id,diagnosis_classification,diagnosis_classification_system,diagnosis_verification_status,diagnosis_basis,diagnosis_comment,disease_phase,tumor_classification,anatomic_site,age_at_diagnosis,toronto_childhood_cancer_staging,age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,id,participant.id
	# type,participant.participant_id,sample.sample_id,diagnosis_id,diagnosis,diagnosis_classification_system,diagnosis_basis,diagnosis_comment,disease_phase,tumor_classification,anatomic_site,age_at_diagnosis,age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_stage_source,tumor_grade,tumor_grade_source,id,participant.id,sample.id
	# type,participant.participant_id,sample.sample_id,diagnosis_id,diagnosis,diagnosis_classification_system,diagnosis_basis,diagnosis_comment,disease_phase,tumor_classification,anatomic_site,age_at_diagnosis,age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_stage_source,tumor_grade,tumor_grade_source,id,participant.id,sample.id
	# round 5 removes age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status
	# type,participant.participant_id,sample.sample_id,diagnosis_id,diagnosis[5],diagnosis_classification_system,diagnosis_basis,diagnosis_comment[8],disease_phase,tumor_classification,anatomic_site[11],age_at_diagnosis[12],toronto_childhood_cancer_staging,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_stage_source,tumor_grade,tumor_grade_source,year_of_diagnosis,laterality,id,participant.id,sample.id

	
	# diagnosis,PBBKUF,PBBKUF_diag,see diagnosis_comment,Indication for Study,Not Reported,Not Reported,Myofibroma,Not Reported,Not Reported,Not Reported,-999,,,,,,,,,,
	# diagnosis,PBBKUF,PBBKUF_4,8824/0 : Myofibroma,ICD-O-3.2,Initial,Clinical,8824-0 Myofibroma,Not Reported,Not Reported,C41.0 : Bones of skull and face and associated joints,1335,,,,,,,,,,
	# diagnosis,PBBMFU,,PBBMFU_5,"9380/3 : Glioma, malignant",ICD-O-3.2,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",2139,,,,,,,,,,,,,
	# diagnosis,,0D88RM,0D88RM_diag,see diagnosis_comment,Indication for Study,Not Reported,Embryonal tumor with multilayered rosettes,Not Reported,Not Reported,C72.9 : Central nervous system,-999,,,,,,,,,,,,,
	# round 5 removes age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status
	# diagnosis,,0E2VSZ,PBCYMW_diag#2,see diagnosis_comment,Indication for Study,Not Reported,Meningioma,Not Reported,Not Reported,Not Reported,-999,,,,,,,,,,,,

	# participant.participant_id is empty for Round 3 - aargh! - switch to using sample.sample_id as key instead :(

	# prioritize based on participant_id over specimen_id, since the former includes more metadata (from COG) (reverse of previous approach)
	csvlinefordiagnosis=`grep ",${patient_id}," "${CSVFILENAMEFORDIAGNOSIS}" | egrep -v '_(CNS_category|CNS5_diagnosis),' | head -1`
	if [ -z "${csvlinefordiagnosis}" ]
	then
		csvlinefordiagnosis=`grep ",${patient_id}," "${CSVFILENAMEFORDIAGNOSIS}" | egrep -v '_(CNS_category|CNS5_diagnosis),' | head -1`
		if [ -z "${csvlinefordiagnosis}" ]
		then
			# fall back to trying sample ...
			csvlinefordiagnosis=`grep ",${sample_id_togetpatientid}," "${CSVFILENAMEFORDIAGNOSIS}" | grep -v '_diag' | head -1`
			if [ -z "${csvlinefordiagnosis}" ]
			then
				csvlinefordiagnosis=`grep ",${sample_id_togetpatientid}," "${CSVFILENAMEFORDIAGNOSIS}" | head -1`
			fi
		fi
	else
		checkdiagnosiscodevalue=`echo "${csvlinefordiagnosis}" | csvtool -c 5 | tr -d '"' | sed -e 's/\([0-9\/]*\).*$/\1/'`
		echo "extracted diagnosiscodevalue to test for unknown and look for alternatives = ${checkdiagnosiscodevalue}"

		if [ "${checkdiagnosiscodevalue}" = "999" ]
		then
		
		# diagnosis,PBDAYX,,PBDAYX_4,"999 : Unknown, to be completed later",ICD-O-3.2,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",840,,,,,,,,,,,,
		# diagnosis,PBDAYX,,PBDAYX_4_CNS_category,Ependymoma,CNS Diagnosis Category,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",840,,,,,,,,,,,,
		# diagnosis,PBDAYX,,PBDAYX_4_CNS5_diagnosis,"Posterior fossa ependymoma, NOS or NEC",WHO CNS5 Integrated Diagnosis,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",840,,,,,,,,,,,,

		# diagnosis,PBDAHJ,,PBDAHJ_4,"999 : Unknown, to be completed later",ICD-O-3.2,Clinical,,Not Reported,Not Reported,C71.4 : Occipital lobe,2675,,,,,,,,,,,,
		# diagnosis,PBDAHJ,,PBDAHJ_4_CNS_category,Low-Grade Glioma,CNS Diagnosis Category,Clinical,,Not Reported,Not Reported,C71.4 : Occipital lobe,2675,,,,,,,,,,,,
		# diagnosis,PBDAHJ,,PBDAHJ_4_CNS5_diagnosis,"Low-grade glioma, NOS or NEC",WHO CNS5 Integrated Diagnosis,Clinical,,Not Reported,Not Reported,C71.4 : Occipital lobe,2675,,,,,,,,,,,,

		# diagnosis,PBCZKW,,PBCZKW_4,"999 : Unknown, to be completed later",ICD-O-3.2,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",3137,,,,,,,,,,,,
		# diagnosis,PBCZKW,,PBCZKW_4_CNS_category,Low-Grade Glioma,CNS Diagnosis Category,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",3137,,,,,,,,,,,,
		# diagnosis,PBCZKW,,PBCZKW_4_CNS5_diagnosis,Pilocytic Astrocytoma,WHO CNS5 Integrated Diagnosis,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",3137,,,,,,,,,,,,

			CNS5csvlinefordiagnosis=`grep ",${patient_id}," "${CSVFILENAMEFORDIAGNOSIS}" | egrep '_CNS5_diagnosis,' | head -1`
			if [ ! -z "${CNS5csvlinefordiagnosis}" ]
			then
				# per Sean Burke e-mail 2025/07/17 use CNS5
				echo 1>&2 "Warning: COG diagnosiscodevalue unknown for patient_id ${patient_id}, using CNS5 for csvlinefordiagnosis instead"
				csvlinefordiagnosis="${CNS5csvlinefordiagnosis}"
			fi
		fi
	fi
	
	echo "csvlinefordiagnosis = ${csvlinefordiagnosis}"
fi

if [ -z "${csvlinefordiagnosis}" ]
then
	echo 1>&2 "Warning: cannot find diagnosis metadata CSV file entry for patient_id ${patient_id} or sample_id ${sample_id_togetpatientid} from which to extract patient characteristics"
else
	age=`echo "${csvlinefordiagnosis}" | csvtool -c 12 | tr -d '"'`
	if [ "${age}" = "-999" ]
	then
		echo 1>&2 "Warning: ignoring unreported age ${age}"
		age=""
	fi
	echo "age = ${age}"

	anatomic_site=`echo "${csvlinefordiagnosis}" | csvtool -c 11 | tr -d '"'`
	echo "extracted anatomic_site = ${anatomic_site}"
	if [ ! -z "${anatomic_site}" ]
	then
		if   [ "${anatomic_site}" = "C00.5 : Mucosa of lip, NOS" ]
		then
			anatomycodevalue="59641005"
			anatomycsd="SCT"
			anatomycodemeaning="Mucosa of lip"
		elif [ "${anatomic_site}" = "C00.6 : Commissure of lip" ]
		then
			anatomycodevalue="83299001"
			anatomycsd="SCT"
			anatomycodemeaning="Commissure of lip"
		elif [ "${anatomic_site}" = "C00.9 : Lip, NOS" -o "${anatomic_site}" = "C00.9 : Lip, NOS (excludes skin of lip C44.0)" ]
		then
			anatomycodevalue="48477009"
			anatomycsd="SCT"
			anatomycodemeaning="Lip"
		elif [ "${anatomic_site}" = "C01.9 : Base of tongue, NOS" ]
		then
			anatomycodevalue="47975008"
			anatomycsd="SCT"
			anatomycodemeaning="Root of tongue"
		elif [ "${anatomic_site}" = "C02.9 : Tongue, NOS" ]
		then
			anatomycodevalue="21974007"
			anatomycsd="SCT"
			anatomycodemeaning="Tongue"
		elif [ "${anatomic_site}" = "C03.0 : Upper gum" ]
		then
			anatomycodevalue="23114008"
			anatomycsd="SCT"
			anatomycodemeaning="Upper gum"
		elif [ "${anatomic_site}" = "C04.9 : Floor of mouth, NOS" ]
		then
			anatomycodevalue="36360002"
			anatomycsd="SCT"
			anatomycodemeaning="Floor of mouth"
		elif [ "${anatomic_site}" = "C05.0 : Hard palate" ]
		then
			anatomycodevalue="90228003"
			anatomycsd="SCT"
			anatomycodemeaning="Hard palate"
		elif [ "${anatomic_site}" = "C05.1 : Soft palate, NOS" ]
		then
			anatomycodevalue="49460000"
			anatomycsd="SCT"
			anatomycodemeaning="Soft palate"
		elif [ "${anatomic_site}" = "C06.0 : Cheek mucosa" ]
		then
			anatomycodevalue="16811007"
			anatomycsd="SCT"
			anatomycodemeaning="Buccal mucosa"
		elif [ "${anatomic_site}" = "C06.9 : Mouth, NOS" ]
		then
			anatomycodevalue="123851003"
			anatomycsd="SCT"
			anatomycodemeaning="Mouth"
		elif [ "${anatomic_site}" = "C07.9 : Parotid gland" ]
		then
			anatomycodevalue="45289007"
			anatomycsd="SCT"
			anatomycodemeaning="Parotid gland"
		elif [ "${anatomic_site}" = "C08.0 : Submandibular gland" ]
		then
			anatomycodevalue="385296007"
			anatomycsd="SCT"
			anatomycodemeaning="Submandibular gland"
		elif [ "${anatomic_site}" = "C08.9 : Major salivary gland, NOS" ]
		then
			anatomycodevalue="119282003"
			anatomycsd="SCT"
			anatomycodemeaning="Major salivary gland"
		elif [ "${anatomic_site}" = "C10.9 : Oropharynx, NOS" ]
		then
			anatomycodevalue="31389004"
			anatomycsd="SCT"
			anatomycodemeaning="Oropharynx"
		elif [ "${anatomic_site}" = "C10.3 : Posterior wall of oropharynx" ]
		then
			anatomycodevalue="12999009"
			anatomycsd="SCT"
			anatomycodemeaning="Posterior wall of oropharynx"
		elif [ "${anatomic_site}" = "C11.2 : Lateral wall of nasopharynx" ]
		then
			anatomycodevalue="70988003"
			anatomycsd="SCT"
			anatomycodemeaning="Lateral wall of nasopharynx"
		elif [ "${anatomic_site}" = "C11.0 : Superior wall of nasopharynx" ]
		then
			anatomycodevalue="20409001"
			anatomycsd="SCT"
			anatomycodemeaning="Superior wall of nasopharynx"
		elif [ "${anatomic_site}" = "C11.3 : Anterior wall of nasopharynx" ]
		then
			anatomycodevalue="82521001"
			anatomycsd="SCT"
			anatomycodemeaning="Anterior wall of nasopharynx"
		elif [ "${anatomic_site}" = "C11.8 : Overlapping lesion of nasopharynx" ]
		then
			anatomycodevalue="71836000"
			anatomycsd="SCT"
			anatomycodemeaning="Nasopharynx"
		elif [ "${anatomic_site}" = "C11.9 : Nasopharynx, NOS" ]
		then
			anatomycodevalue="71836000"
			anatomycsd="SCT"
			anatomycodemeaning="Nasopharynx"
		elif [ "${anatomic_site}" = "C14.0 : Pharynx, NOS" ]
		then
			anatomycodevalue="54066008"
			anatomycsd="SCT"
			anatomycodemeaning="Pharynx"
		elif [ "${anatomic_site}" = "C14.8 : Overlapping lesion of lip, oral cavity and pharynx" ]
		then
			anatomycodevalue="312533001"
			anatomycsd="SCT"
			anatomycodemeaning="Mouth and/or pharynx"
		elif [ "${anatomic_site}" = "C15.2 : Abdominal esophagus" ]
		then
			anatomycodevalue="60865004"
			anatomycsd="SCT"
			anatomycodemeaning="Abdominal esophagus"
		elif [ "${anatomic_site}" = "C16.2 : Body of stomach" ]
		then
			anatomycodevalue="68560004"
			anatomycsd="SCT"
			anatomycodemeaning="Body of stomach"
		elif [ "${anatomic_site}" = "C16.3 : Gastric antrum" ]
		then
			anatomycodevalue="66051006"
			anatomycsd="SCT"
			anatomycodemeaning="Pyloric antrum"
		elif [ "${anatomic_site}" = "C16.6 : Greater curvature of stomach, NOS" -o "${anatomic_site}" = "C16.6 : Greater curvature of stomach, NOS (not classifiable to C16.0 to C16.4)" ]
		then
			anatomycodevalue="89382009"
			anatomycsd="SCT"
			anatomycodemeaning="Greater curvature of stomach"
		elif [ "${anatomic_site}" = "C16.9 : Stomach, NOS" ]
		then
			anatomycodevalue="69695003"
			anatomycsd="SCT"
			anatomycodemeaning="Stomach"
		elif [ "${anatomic_site}" = "C17.0 : Duodenum" ]
		then
			anatomycodevalue="38848004"
			anatomycsd="SCT"
			anatomycodemeaning="Duodenum"
		elif [ "${anatomic_site}" = "C17.1 : Jejunum" ]
		then
			anatomycodevalue="21306003"
			anatomycsd="SCT"
			anatomycodemeaning="Jejunum"
		elif [ "${anatomic_site}" = "C17.9 : Small intestine, NOS" ]
		then
			anatomycodevalue="30315005"
			anatomycsd="SCT"
			anatomycodemeaning="Small intestine"
		elif [ "${anatomic_site}" = "C18.0 : Cecum" ]
		then
			anatomycodevalue="32713005"
			anatomycsd="SCT"
			anatomycodemeaning="Cecum"
		elif [ "${anatomic_site}" = "C18.1 : Appendix" ]
		then
			anatomycodevalue="66754008"
			anatomycsd="SCT"
			anatomycodemeaning="Appendix"
		elif [ "${anatomic_site}" = "C18.2 : Ascending colon" ]
		then
			anatomycodevalue="9040008"
			anatomycsd="SCT"
			anatomycodemeaning="Ascending colon"
		elif [ "${anatomic_site}" = "C18.7 : Sigmoid colon" ]
		then
			anatomycodevalue="60184004"
			anatomycsd="SCT"
			anatomycodemeaning="Sigmoid colon"
		elif [ "${anatomic_site}" = "C18.6 : Descending colon" ]
		then
			anatomycodevalue="32622004"
			anatomycsd="SCT"
			anatomycodemeaning="Descending colon"
		elif [ "${anatomic_site}" = "C18.9 : Colon, NOS" ]
		then
			anatomycodevalue="71854001"
			anatomycsd="SCT"
			anatomycodemeaning="Colon"
		elif [ "${anatomic_site}" = "C19.9 : Rectosigmoid junction" ]
		then
			anatomycodevalue="49832006"
			anatomycsd="SCT"
			anatomycodemeaning="Rectosigmoid junction"
		elif [ "${anatomic_site}" = "C17.2 : Ileum" ]
		then
			anatomycodevalue="34516001"
			anatomycsd="SCT"
			anatomycodemeaning="Ileum"
		elif [ "${anatomic_site}" = "C20.9 : Rectum, NOS" ]
		then
			anatomycodevalue="34402009"
			anatomycsd="SCT"
			anatomycodemeaning="Rectum"
		elif [ "${anatomic_site}" = "C21.0 : Anus, NOS" -o "${anatomic_site}" = "C21.0 : Anus, NOS (excludes skin of anus and perianal skin C44.5)" ]
		then
			anatomycodevalue="53505006"
			anatomycsd="SCT"
			anatomycodemeaning="Anus"
		elif [ "${anatomic_site}" = "C21.8 : Overlapping lesion of rectum, anus and anal canal" ]
		then
			anatomycodevalue="281088000"
			anatomycsd="SCT"
			anatomycodemeaning="Anorectal structure"
		elif [ "${anatomic_site}" = "C22.0 : Liver" ]
		then
			anatomycodevalue="10200004"
			anatomycsd="SCT"
			anatomycodemeaning="Liver"
		elif [ "${anatomic_site}" = "C22.1 : Intrahepatic bile duct" ]
		then
			anatomycodevalue="1340143004"
			anatomycsd="SCT"
			anatomycodemeaning="Intrahepatic bile duct"
		elif [ "${anatomic_site}" = "C23.9 : Gallbladder" ]
		then
			anatomycodevalue="28231008"
			anatomycsd="SCT"
			anatomycodemeaning="Gallbladder"
		elif [ "${anatomic_site}" = "C25.0 : Head of pancreas" ]
		then
			anatomycodevalue="64163001"
			anatomycsd="SCT"
			anatomycodemeaning="Head of pancreas"
		elif [ "${anatomic_site}" = "C25.1 : Body of pancreas" ]
		then
			anatomycodevalue="40133006"
			anatomycsd="SCT"
			anatomycodemeaning="Body of pancreas"
		elif [ "${anatomic_site}" = "C25.2 : Tail of pancreas" ]
		then
			anatomycodevalue="73239005"
			anatomycsd="SCT"
			anatomycodemeaning="Tail of pancreas"
		elif [ "${anatomic_site}" = "C25.3 : Pancreatic duct" ]
		then
			anatomycodevalue="69930009"
			anatomycsd="SCT"
			anatomycodemeaning="Pancreatic duct"
		elif [ "${anatomic_site}" = "C25.9 : Pancreas, NOS" ]
		then
			anatomycodevalue="15776009"
			anatomycsd="SCT"
			anatomycodemeaning="Pancreas"
		elif [ "${anatomic_site}" = "C26.0 : Intestinal tract, NOS" ]
		then
			anatomycodevalue="113276009"
			anatomycsd="SCT"
			anatomycodemeaning="Intestinal tract"
		elif [ "${anatomic_site}" = "C26.9 : Gastrointestinal tract, NOS" ]
		then
			anatomycodevalue="122865005"
			anatomycsd="SCT"
			anatomycodemeaning="Gastrointestinal tract"
		elif [ "${anatomic_site}" = "C30.0 : Nasal cavity" -o "${anatomic_site}" = "C30.0 : Nasal cavity (excludes nose, NOS C76.0)" ]
		then
			anatomycodevalue="279549004"
			anatomycsd="SCT"
			anatomycodemeaning="Nasal cavity"
		elif [ "${anatomic_site}" = "C30.1 : Middle ear" ]
		then
			anatomycodevalue="25342003"
			anatomycsd="SCT"
			anatomycodemeaning="Middle ear"
		elif [ "${anatomic_site}" = "C31.0 : Maxillary sinus" ]
		then
			anatomycodevalue="15924003"
			anatomycsd="SCT"
			anatomycodemeaning="Maxillary sinus"
		elif [ "${anatomic_site}" = "C31.1 : Ethmoid sinus" ]
		then
			anatomycodevalue="54215007"
			anatomycsd="SCT"
			anatomycodemeaning="Ethmoid sinus"
		elif [ "${anatomic_site}" = "C31.3 : Sphenoid sinus" ]
		then
			anatomycodevalue="24999009"
			anatomycsd="SCT"
			anatomycodemeaning="Sphenoid sinus"
		elif [ "${anatomic_site}" = "C31.9 : Accessory sinus, NOS" ]
		then
			anatomycodevalue="2095001"
			anatomycsd="SCT"
			anatomycodemeaning="Nasal sinus"
		elif [ "${anatomic_site}" = "C32.1 : Supraglottis" ]
		then
			anatomycodevalue="119255006"
			anatomycsd="SCT"
			anatomycodemeaning="Supraglottis"
		elif [ "${anatomic_site}" = "C32.9 : Larynx, NOS" ]
		then
			anatomycodevalue="4596009"
			anatomycsd="SCT"
			anatomycodemeaning="Larynx"
		elif [ "${anatomic_site}" = "C33.9 : Trachea" ]
		then
			anatomycodevalue="44567001"
			anatomycsd="SCT"
			anatomycodemeaning="Trachea"
		elif [ "${anatomic_site}" = "C34.3 : Lower lobe, lung" ]
		then
			anatomycodevalue="90572001"
			anatomycsd="SCT"
			anatomycodemeaning="Lower lobe of lung"
		elif [ "${anatomic_site}" = "C34.2 : Middle lobe, lung" ]
		then
			anatomycodevalue="72481006"
			anatomycsd="SCT"
			anatomycodemeaning="Middle lobe of right lung"
		elif [ "${anatomic_site}" = "C34.1 : Upper lobe, lung" ]
		then
			anatomycodevalue="45653009"
			anatomycsd="SCT"
			anatomycodemeaning="Upper lobe of lung"
		elif [ "${anatomic_site}" = "C34.8 : Overlapping lesion of lung" ]
		then
			# actually means bronchus and lung per "https://www.icd10data.com/ICD10CM/Codes/C00-D49/C30-C39/C34-/C34.8"
			anatomycodevalue="110736001"
			anatomycsd="SCT"
			anatomycodemeaning="Bronchus and lung"
		elif [ "${anatomic_site}" = "C34.9 : Lung, NOS" ]
		then
			anatomycodevalue="39607008"
			anatomycsd="SCT"
			anatomycodemeaning="Lung"
		elif [ "${anatomic_site}" = "C37.9 : Thymus" ]
		then
			anatomycodevalue="9875009"
			anatomycsd="SCT"
			anatomycodemeaning="Thymus"
		elif [ "${anatomic_site}" = "C38.0 : Heart" ]
		then
			anatomycodevalue="80891009"
			anatomycsd="SCT"
			anatomycodemeaning="Heart"
		elif [ "${anatomic_site}" = "C38.1 : Anterior mediastinum" ]
		then
			anatomycodevalue="72410000"
			anatomycsd="SCT"
			anatomycodemeaning="Mediastinum"
			anatomymodifiercodevalue="255549009"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Anterior"
		elif [ "${anatomic_site}" = "C38.2 : Posterior mediastinum" ]
		then
			anatomycodevalue="72410000"
			anatomycsd="SCT"
			anatomycodemeaning="Mediastinum"
			anatomymodifiercodevalue="255551008"
			anatomymodifiercsd="SCT"
			anatomymodifiercodemeaning="Posterior"
		elif [ "${anatomic_site}" = "C38.3 : Mediastinum, NOS" ]
		then
			anatomycodevalue="72410000"
			anatomycsd="SCT"
			anatomycodemeaning="Mediastinum"
		elif [ "${anatomic_site}" = "C38.4 : Pleura, NOS" ]
		then
			anatomycodevalue="3120008"
			anatomycsd="SCT"
			anatomycodemeaning="Pleura"
		elif [ "${anatomic_site}" = "C39.0 : Upper respiratory tract, NOS" ]
		then
			anatomycodevalue="58675001"
			anatomycsd="SCT"
			anatomycodemeaning="Upper respiratory tract"
		elif [ "${anatomic_site}" = "C39.8 : Overlapping lesion of respiratory system and intrathoracic organs" ]
		then
			anatomycodevalue="312419003"
			anatomycsd="SCT"
			anatomycodemeaning="Respiratory and/or intrathoracic structure"
		elif [ "${anatomic_site}" = "C40.0 : Long bones of upper limb, scapula and associated joints" -o "${anatomic_site}" = "C40.0 : Long bones of upper limb, scapula and  associated joints" ]
		then
			anatomycodevalue="400194001"
			anatomycsd="SCT"
			anatomycodemeaning=" Long bone of upper limb"
		elif [ "${anatomic_site}" = "C40.1 : Short bones of upper limb and associated joints" ]
		then
			anatomycodevalue="712522005"
			anatomycsd="SCT"
			anatomycodemeaning="Short bone of upper limb"
		elif [ "${anatomic_site}" = "C40.2 : Long bones of lower limb and associated joints" ]
		then
			anatomycodevalue="400143008"
			anatomycsd="SCT"
			anatomycodemeaning="Long bone of lower limb"
		elif [ "${anatomic_site}" = "C40.3 : Short bones of lower limb and associated joints" ]
		then
			anatomycodevalue="712523000"
			anatomycsd="SCT"
			anatomycodemeaning="Short bone of lower limb"
		elif [ "${anatomic_site}" = "C40.9 : Bone of limb, NOS" ]
		then
			anatomycodevalue="48566001"
			anatomycsd="SCT"
			anatomycodemeaning="Bone of limb"
		elif [ "${anatomic_site}" = "C41.0 : Bones of skull and face and associated joints" -o "${anatomic_site}" = "C41.0 : Bones of skull and face and associated joints (excludes mandible C41.1)" ]
		then
			anatomycodevalue="272679001"
			anatomycsd="SCT"
			anatomycodemeaning="Cranial and/or facial bone"
		elif [ "${anatomic_site}" = "C41.1 : Mandible" ]
		then
			anatomycodevalue="91609006"
			anatomycsd="SCT"
			anatomycodemeaning="Mandible"
		elif [ "${anatomic_site}" = "C41.2 : Vertebral column" -o "${anatomic_site}" = "C41.2 : Vertebral column (excludes sacrum and coccyx C41.4)" ]
		then
			anatomycodevalue="421060004"
			anatomycsd="SCT"
			anatomycodemeaning="Vertebral column"
		elif [ "${anatomic_site}" = "C41.3 : Rib, sternum, clavicle and associated joints" ]
		then
			anatomycodevalue="312563005"
			anatomycsd="SCT"
			anatomycodemeaning="Rib, sternum and/or clavicle"
		elif [ "${anatomic_site}" = "C41.4 : Pelvic bones, sacrum, coccyx and associated joints" ]
		then
			anatomycodevalue="118645006"
			anatomycsd="SCT"
			anatomycodemeaning="Innominate bone and/or sacrum and/or coccyx"
		elif [ "${anatomic_site}" = "C41.9 : Bone, NOS" ]
		then
			anatomycodevalue="272673000"
			anatomycsd="SCT"
			anatomycodemeaning="Bone"
		elif [ "${anatomic_site}" = "C42.0 : Blood" ]
		then
			# use substance code
			anatomycodevalue="87612001"
			anatomycsd="SCT"
			anatomycodemeaning="Blood"
		elif [ "${anatomic_site}" = "C42.1 : Bone marrow" ]
		then
			anatomycodevalue="14016003"
			anatomycsd="SCT"
			anatomycodemeaning="Bone marrow"
		elif [ "${anatomic_site}" = "C44.1 : Eyelid" ]
		then
			anatomycodevalue="80243003"
			anatomycsd="SCT"
			anatomycodemeaning="Eyelid"
		elif [ "${anatomic_site}" = "C44.2 : External ear" ]
		then
			anatomycodevalue="28347008"
			anatomycsd="SCT"
			anatomycodemeaning="External ear"
		elif [ "${anatomic_site}" = "C44.4 : Skin of scalp and neck" ]
		then
			anatomycodevalue="400056003"
			anatomycsd="SCT"
			anatomycodemeaning="Skin of scalp and neck"
		elif [ "${anatomic_site}" = "C44.5 : Skin of trunk" ]
		then
			anatomycodevalue="86381001"
			anatomycsd="SCT"
			anatomycodemeaning="Skin of trunk"
		elif [ "${anatomic_site}" = "C44.6 : Skin of upper limb and shoulder" ]
		then
			anatomycodevalue="371311000"
			anatomycsd="SCT"
			anatomycodemeaning="Skin of upper limb"
		elif [ "${anatomic_site}" = "C44.7 : Skin of lower limb and hip" ]
		then
			anatomycodevalue="371304004"
			anatomycsd="SCT"
			anatomycodemeaning="Skin of lower limb"
		elif [ "${anatomic_site}" = "C44.9 : Skin, NOS" ]
		then
			anatomycodevalue="39937001"
			anatomycsd="SCT"
			anatomycodemeaning="Skin"
		elif [ "${anatomic_site}" = "C47.1 : Peripheral nerves and autonomic nervous system of upper limb and shoulder" ]
		then
			anatomycodevalue="314738007"
			anatomycsd="SCT"
			anatomycodemeaning="Upper limb nerve"
		elif [ "${anatomic_site}" = "C47.3 : Peripheral nerves and autonomic nervous system of thorax" ]
		then
			# this is inactive in SCT but not sure why :(
			anatomycodevalue="359876006"
			anatomycsd="SCT"
			anatomycodemeaning="Nerve of thorax"
		elif [ "${anatomic_site}" = "C47.5 : Peripheral nerves and autonomic nervous system of pelvis" ]
		then
			anatomycodevalue="787219009"
			anatomycsd="SCT"
			anatomycodemeaning="Nerve of pelvis"
		elif [ "${anatomic_site}" = "C47.6 : Peripheral nerves and autonomic nervous system of trunk, NOS" ]
		then
			anatomycodevalue="281248001"
			anatomycsd="SCT"
			anatomycodemeaning="Nerve of trunk"
		elif [ "${anatomic_site}" = "C47.9 : Autonomic nervous system, NOS" ]
		then
			anatomycodevalue="72167002"
			anatomycsd="SCT"
			anatomycodemeaning="Autonomic nervous system"
		elif [ "${anatomic_site}" = "C48.0 : Retroperitoneum" ]
		then
			anatomycodevalue="82849001"
			anatomycsd="SCT"
			anatomycodemeaning="Retroperitoneum"
		elif [ "${anatomic_site}" = "C48.2 : Peritoneum, NOS" ]
		then
			anatomycodevalue="15425007"
			anatomycsd="SCT"
			anatomycodemeaning="Peritoneum"
		elif [ "${anatomic_site}" = "C49.0 : Connective, subcutaneous and other soft tissues of head, face, and neck" -o "${anatomic_site}" = "C49.0 : Connective, subcutaneous and other soft tissues of head, face, and neck (excludes connective tissue of orbit C69.6 and nasal cartilage C30.0)" ]
		then
			# SCT code includes subcutaneous tissue as a child, therefore is inclusive
			anatomycodevalue="34201000"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissues of head and neck"
		elif [ "${anatomic_site}" = "C49.1 : Connective, subcutaneous and other soft tissues of upper limb and shoulder" ]
		then
			anatomycodevalue="75490006"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue of upper extremity"
		elif [ "${anatomic_site}" = "C49.2 : Connective, subcutaneous and other soft tissues of lower limb and hip" ]
		then
			# SCT code includes subcutaneous tissue, and of hip, as children, therefore is inclusive
			anatomycodevalue="67328008"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue of lower extremity"
		elif [ "${anatomic_site}" = "C49.3 : Connective, subcutaneous and other soft tissues of thorax" -o "${anatomic_site}" = "C49.3 : Connective, subcutaneous and other soft tissues of thorax (excludes thymus C37.9, heart and mediastinum C38._)" ]
		then
			anatomycodevalue="31749008"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue of thorax"
		elif [ "${anatomic_site}" = "C49.4 : Connective, subcutaneous and other soft tissues of abdomen" ]
		then
			anatomycodevalue="818997006"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue of abdomen"
		elif [ "${anatomic_site}" = "C49.5 : Connective, subcutaneous and other soft tissues of pelvis" ]
		then
			anatomycodevalue="20159001"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue of pelvis"
		elif [ "${anatomic_site}" = "C49.6 : Connective, subcutaneous and other soft tissues of trunk, NOS" ]
		then
			anatomycodevalue="1490004"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue of trunk"
		elif [ "${anatomic_site}" = "C49.8 : Overlapping lesion of connective, subcutaneous and other soft tissues" ]
		then
			anatomycodevalue="87784001"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue"
		elif [ "${anatomic_site}" = "C49.9 : Connective, subcutaneous and other soft tissues, NOS" ]
		then
			anatomycodevalue="87784001"
			anatomycsd="SCT"
			anatomycodemeaning="Soft tissue"
		elif [ "${anatomic_site}" = "C50.9 : Breast, NOS" ]
		then
			anatomycodevalue="76752008"
			anatomycsd="SCT"
			anatomycodemeaning="Breast"
		elif [ "${anatomic_site}" = "C51.0 : Labium majus" ]
		then
			anatomycodevalue="82462005"
			anatomycsd="SCT"
			anatomycodemeaning="Labium majus"
		elif [ "${anatomic_site}" = "C52.9 : Vagina, NOS" ]
		then
			anatomycodevalue="76784001"
			anatomycsd="SCT"
			anatomycodemeaning="Vagina"
		elif [ "${anatomic_site}" = "C53.0 : Endocervix" ]
		then
			anatomycodevalue="36973007"
			anatomycsd="SCT"
			anatomycodemeaning="Endocervix"
		elif [ "${anatomic_site}" = "C53.9 : Cervix uteri" ]
		then
			anatomycodevalue="71252005"
			anatomycsd="SCT"
			anatomycodemeaning="Cervix uteri"
		elif [ "${anatomic_site}" = "C54.1 : Endometrium" ]
		then
			anatomycodevalue="2739003"
			anatomycsd="SCT"
			anatomycodemeaning="Endometrium"
		elif [ "${anatomic_site}" = "C55.9 : Uterus, NOS" ]
		then
			anatomycodevalue="35039007"
			anatomycsd="SCT"
			anatomycodemeaning="Uterus"
		elif [ "${anatomic_site}" = "C56.9 : Ovary" ]
		then
			anatomycodevalue="15497006"
			anatomycsd="SCT"
			anatomycodemeaning="Ovary"
		elif [ "${anatomic_site}" = "C57.0 : Fallopian tube" ]
		then
			anatomycodevalue="31435000"
			anatomycsd="SCT"
			anatomycodemeaning="Fallopian tube"
		elif [ "${anatomic_site}" = "C57.7 : Other specified parts of female genital organs" ]
		then
			anatomycodevalue="127882003"
			anatomycsd="SCT"
			anatomycodemeaning="Female genital organ"
		elif [ "${anatomic_site}" = "C60.9 : Penis, NOS" ]
		then
			anatomycodevalue="18911002"
			anatomycsd="SCT"
			anatomycodemeaning="Penis"
		elif [ "${anatomic_site}" = "C61.9 : Prostate gland" ]
		then
			anatomycodevalue="41216001"
			anatomycsd="SCT"
			anatomycodemeaning="Prostate"
		elif [ "${anatomic_site}" = "C62.1 : Descended testis" ]
		then
			anatomycodevalue="416953005"
			anatomycsd="SCT"
			anatomycodemeaning="Descended testis"
		elif [ "${anatomic_site}" = "C62.9 : Testis, NOS" ]
		then
			anatomycodevalue="40689003"
			anatomycsd="SCT"
			anatomycodemeaning="Testis"
		elif [ "${anatomic_site}" = "C63.0 : Epididymis" ]
		then
			anatomycodevalue="87644002"
			anatomycsd="SCT"
			anatomycodemeaning="Epididymis"
		elif [ "${anatomic_site}" = "C63.2 : Scrotum, NOS" ]
		then
			anatomycodevalue="20233005"
			anatomycsd="SCT"
			anatomycodemeaning="Scrotum"
		elif [ "${anatomic_site}" = "C63.9 : Male genital organs, NOS" ]
		then
			anatomycodevalue="127903009"
			anatomycsd="SCT"
			anatomycodemeaning="Male genital organ"
		elif [ "${anatomic_site}" = "C64.9 : Kidney, NOS" ]
		then
			anatomycodevalue="64033007"
			anatomycsd="SCT"
			anatomycodemeaning="Kidney"
		elif [ "${anatomic_site}" = "C65.9 : Renal pelvis" ]
		then
			anatomycodevalue="25990002"
			anatomycsd="SCT"
			anatomycodemeaning="Renal pelvis"
		elif [ "${anatomic_site}" = "C67.7 : Urachus" ]
		then
			anatomycodevalue="14105008"
			anatomycsd="SCT"
			anatomycodemeaning="Urachus"
		elif [ "${anatomic_site}" = "C67.9 : Bladder, NOS" ]
		then
			anatomycodevalue="89837001"
			anatomycsd="SCT"
			anatomycodemeaning="Urinary bladder"
		elif [ "${anatomic_site}" = "C68.9 : Urinary system, NOS" ]
		then
			anatomycodevalue="122489005"
			anatomycsd="SCT"
			anatomycodemeaning="Urinary system"
		elif [ "${anatomic_site}" = "C69.0 : Conjunctiva" ]
		then
			anatomycodevalue="29445007"
			anatomycsd="SCT"
			anatomycodemeaning="Conjunctiva"
		elif [ "${anatomic_site}" = "C69.2 : Retina" ]
		then
			anatomycodevalue="5665001"
			anatomycsd="SCT"
			anatomycodemeaning="Retina"
		elif [ "${anatomic_site}" = "C69.3 : Choroid" ]
		then
			anatomycodevalue="68703001"
			anatomycsd="SCT"
			anatomycodemeaning="Choroid of eye"
		elif [ "${anatomic_site}" = "C69.5 : Lacrimal gland" ]
		then
			anatomycodevalue="13561001"
			anatomycsd="SCT"
			anatomycodemeaning="Lacrimal gland"
		elif [ "${anatomic_site}" = "C69.6 : Orbit, NOS" ]
		then
			anatomycodevalue="363654007"
			anatomycsd="SCT"
			anatomycodemeaning="Orbit"
		elif [ "${anatomic_site}" = "C69.9 : Eye, NOS" ]
		then
			anatomycodevalue="81745001"
			anatomycsd="SCT"
			anatomycodemeaning="Eye"
		elif [ "${anatomic_site}" = "C70.0 : Cerebral meninges" ]
		then
			anatomycodevalue="8935007"
			anatomycsd="SCT"
			anatomycodemeaning="Cerebral meninges"
		elif [ "${anatomic_site}" = "C70.1 : Spinal meninges" ]
		then
			anatomycodevalue="75559006"
			anatomycsd="SCT"
			anatomycodemeaning="Spinal meninges"
		elif [ "${anatomic_site}" = "C70.9 : Meninges, NOS" ]
		then
			anatomycodevalue="1231004"
			anatomycsd="SCT"
			anatomycodemeaning="Meninges"
		elif [ "${anatomic_site}" = "C71.0 : Cerebrum" ]
		then
			anatomycodevalue="83678007"
			anatomycsd="SCT"
			anatomycodemeaning="Cerebrum"
		elif [ "${anatomic_site}" = "C71.1 : Frontal lobe" ]
		then
			anatomycodevalue="83251001"
			anatomycsd="SCT"
			anatomycodemeaning="Frontal lobe"
		elif [ "${anatomic_site}" = "C71.2 : Temporal lobe" ]
		then
			anatomycodevalue="78277001"
			anatomycsd="SCT"
			anatomycodemeaning="Temporal lobe"
		elif [ "${anatomic_site}" = "C71.3 : Parietal lobe" ]
		then
			anatomycodevalue="16630005"
			anatomycsd="SCT"
			anatomycodemeaning="Parietal lobe"
		elif [ "${anatomic_site}" = "C71.4 : Occipital lobe" ]
		then
			anatomycodevalue="31065004"
			anatomycsd="SCT"
			anatomycodemeaning="Occipital lobe"
		elif [ "${anatomic_site}" = "C71.5 : Ventricle, NOS" ]
		then
			anatomycodevalue="35764002"
			anatomycsd="SCT"
			anatomycodemeaning="Cerebral ventricle"
		elif [ "${anatomic_site}" = "C71.6 : Cerebellum, NOS" ]
		then
			anatomycodevalue="113305005"
			anatomycsd="SCT"
			anatomycodemeaning="Cerebellum"
		elif [ "${anatomic_site}" = "C71.7 : Brain stem" ]
		then
			anatomycodevalue="15926001"
			anatomycsd="SCT"
			anatomycodemeaning="Brain stem"
		elif [ "${anatomic_site}" = "C71.8 : Overlapping lesion of brain" ]
		then
			anatomycodevalue="12738006"
			anatomycsd="SCT"
			anatomycodemeaning="Brain"
		elif [ "${anatomic_site}" = "C71.9 : Brain, NOS" ]
		then
			anatomycodevalue="12738006"
			anatomycsd="SCT"
			anatomycodemeaning="Brain"
		elif [ "${anatomic_site}" = "C72.0 : Spinal cord" ]
		then
			anatomycodevalue="2748008"
			anatomycsd="SCT"
			anatomycodemeaning="Spinal cord"
		elif [ "${anatomic_site}" = "C72.1 : Cauda equina" ]
		then
			anatomycodevalue="7173007"
			anatomycsd="SCT"
			anatomycodemeaning="Cauda equina"
		elif [ "${anatomic_site}" = "C72.3 : Optic nerve" ]
		then
			anatomycodevalue="18234004"
			anatomycsd="SCT"
			anatomycodemeaning="Optic nerve"
		elif [ "${anatomic_site}" = "C72.5 : Cranial nerve, NOS" ]
		then
			anatomycodevalue="25238003"
			anatomycsd="SCT"
			anatomycodemeaning="Cranial nerve"
		elif [ "${anatomic_site}" = "C72.8 : Overlapping lesion of brain and central nervous system" ]
		then
			anatomycodevalue="21483005"
			anatomycsd="SCT"
			anatomycodemeaning="Central nervous system"
		elif [ "${anatomic_site}" = "C72.9 : Central nervous system" ]
		then
			anatomycodevalue="21483005"
			anatomycsd="SCT"
			anatomycodemeaning="Central nervous system"
		elif [ "${anatomic_site}" = "C73.9 : Thyroid gland" ]
		then
			anatomycodevalue="69748006"
			anatomycsd="SCT"
			anatomycodemeaning="Thyroid"
		elif [ "${anatomic_site}" = "C74.0 : Cortex of adrenal gland" ]
		then
			anatomycodevalue="68594002"
			anatomycsd="SCT"
			anatomycodemeaning="Adrenal cortex"
		elif [ "${anatomic_site}" = "C74.1 : Medulla of adrenal gland" ]
		then
			anatomycodevalue="38254008"
			anatomycsd="SCT"
			anatomycodemeaning="Adrenal medulla"
		elif [ "${anatomic_site}" = "C74.9 : Adrenal gland, NOS" ]
		then
			anatomycodevalue="23451007"
			anatomycsd="SCT"
			anatomycodemeaning="Adrenal gland"
		elif [ "${anatomic_site}" = "C75.1 : Pituitary gland" ]
		then
			anatomycodevalue="56329008"
			anatomycsd="SCT"
			anatomycodemeaning="Pituitary gland"
		elif [ "${anatomic_site}" = "C75.2 : Craniopharyngeal duct" ]
		then
			anatomycodevalue="86394004"
			anatomycsd="SCT"
			anatomycodemeaning="Craniopharyngeal duct"
		elif [ "${anatomic_site}" = "C75.3 : Pineal gland" ]
		then
			anatomycodevalue="45793000"
			anatomycsd="SCT"
			anatomycodemeaning="Pineal gland"
		elif [ "${anatomic_site}" = "C76.0 : Head, face or neck, NOS" ]
		then
			anatomycodevalue="774007"
			anatomycsd="SCT"
			anatomycodemeaning="Head and neck"
		elif [ "${anatomic_site}" = "C76.1 : Thorax, NOS" ]
		then
			anatomycodevalue="51185008"
			anatomycsd="SCT"
			anatomycodemeaning="Thorax"
		elif [ "${anatomic_site}" = "C76.2 : Abdomen, NOS" ]
		then
			anatomycodevalue="818983003"
			anatomycsd="SCT"
			anatomycodemeaning="Abdomen"
		elif [ "${anatomic_site}" = "C76.3 : Pelvis, NOS" ]
		then
			anatomycodevalue="12921003"
			anatomycsd="SCT"
			anatomycodemeaning="Pelvis"
		elif [ "${anatomic_site}" = "C76.4 : Upper limb, NOS" ]
		then
			anatomycodevalue="53120007"
			anatomycsd="SCT"
			anatomycodemeaning="Upper limb"
		elif [ "${anatomic_site}" = "C76.5 : Lower limb, NOS" ]
		then
			anatomycodevalue="61685007"
			anatomycsd="SCT"
			anatomycodemeaning="Lower limb"
		elif [ "${anatomic_site}" = "C77.0 : Lymph nodes of head, face and neck" ]
		then
			anatomycodevalue="312501005"
			anatomycsd="SCT"
			anatomycodemeaning="Head and neck lymph node"
		elif [ "${anatomic_site}" = "C77.3 : Lymph nodes of axilla or arm" ]
		then
			anatomycodevalue="44914007"
			anatomycsd="SCT"
			anatomycodemeaning="Upper limb lymph node"
		elif [ "${anatomic_site}" = "C77.2 : Intra-abdominal lymph nodes" ]
		then
			anatomycodevalue="818991007"
			anatomycsd="SCT"
			anatomycodemeaning="Abdominal lymph node"
		elif [ "${anatomic_site}" = "C77.4 : Lymph nodes of inguinal region or leg" ]
		then
			anatomycodevalue="4942000"
			anatomycsd="SCT"
			anatomycodemeaning="Lower limb lymph node"
		elif [ "${anatomic_site}" = "C77.8 : Lymph nodes of multiple regions" ]
		then
			anatomycodevalue="59441001"
			anatomycsd="SCT"
			anatomycodemeaning="Lymph node"
		elif [ "${anatomic_site}" = "C77.9 : Lymph node, NOS" ]
		then
			anatomycodevalue="59441001"
			anatomycsd="SCT"
			anatomycodemeaning="Lymph node"
		elif [ "${anatomic_site}" = "C80 : UNKNOWN PRIMARY SITE" ]
		then
			# is disorder rather than structure
			anatomycodevalue="255051004"
			anatomycsd="SCT"
			anatomycodemeaning="Neoplasm of unknown origin"
		elif [ "${anatomic_site}" = "C76.7 : Other ill-defined sites" ]
		then
			anatomycodevalue="10003008"
			anatomycsd="SCT"
			anatomycodemeaning="Unspecified"
		else
			echo 1>&2 "Warning: unrecognized anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
			# do not like using unspecified, but want to include the tissue type as a modifer, so need parent :(
			anatomycodevalue="10003008"
			anatomycsd="SCT"
			anatomycodemeaning="Unspecified"
		fi

		if [ "${anatomycodevalue}" = "999" ]
		then
			echo 1>&2 "Warning: no code specified yet for anatomic_site \"${anatomic_site}\" for patient_id ${patient_id}"
			anatomycodevalue=""
			anatomycsd=""
			anatomycodemeaning=""
		fi
	fi

	diagnosis=`echo "${csvlinefordiagnosis}" | csvtool -c 5 | tr -d '"'`
	echo "extracted diagnosis = ${diagnosis}"
	diagnosiscodevalue=`echo "${diagnosis}" | sed -e 's/\([0-9\/]*\).*$/\1/'`
	echo "extracted diagnosiscodevalue = ${diagnosiscodevalue}"

	if [ -z "${diagnosiscodevalue}" ]
	then
		if [ ! -z "${diagnosis}" ]
		then
			if [ "${diagnosis}" = "Pilocytic Astrocytoma" ]
			then
				diagnosiscodevalue="9421/1"
			elif [ "${diagnosis}" = "Low-grade glioma, NOS or NEC" ]
			then
				# https://seer.cancer.gov/seer-inquiry/inquiry-detail/20230080/
				diagnosiscodevalue="9380/1"
			elif [ "${diagnosis}" = "Posterior fossa ependymoma, NOS or NEC" ]
			then
				# "Ependymoma, NOS"
				diagnosiscodevalue="9391/3"
			else
				echo 1>&2 "Warning: ignoring unrecognized diagnosis ${diagnosis} for patient_id ${patient_id}"
			fi
		else
			echo 1>&2 "Warning: ignoring empty value for diagnosiscodevalue for patient_id ${patient_id}"
		fi
	elif [ "${diagnosiscodevalue}" = "999" ]
	then
		echo 1>&2 "Warning: ignoring unknown value for diagnosiscodevalue ${diagnosiscodevalue} for patient_id ${patient_id}"
		diagnosiscodevalue=""
	fi

	if [ -z "${diagnosiscodevalue}" ]
	then
		# type,participant.participant_id,diagnosis_id,diagnosis_classification,diagnosis_classification_system,diagnosis_verification_status,diagnosis_basis,diagnosis_comment,disease_phase,tumor_classification,anatomic_site,age_at_diagnosis,toronto_childhood_cancer_staging,age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,id,participant.id
		# type,participant.participant_id,sample.sample_id,diagnosis_id,diagnosis,diagnosis_classification_system,diagnosis_basis,diagnosis_comment,disease_phase,tumor_classification,anatomic_site,age_at_diagnosis,age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_stage_source,tumor_grade,tumor_grade_source,id,participant.id,sample.id
		# type,participant.participant_id,sample.sample_id,diagnosis_id,diagnosis,diagnosis_classification_system,diagnosis_basis,diagnosis_comment,disease_phase,tumor_classification,anatomic_site,age_at_diagnosis,age_at_recurrence,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,tumor_stage_source,tumor_grade,tumor_grade_source,id,participant.id,sample.id

		# diagnosis,PBBKUF,PBBKUF_diag,see diagnosis_comment,Indication for Study,Not Reported,Not Reported,Myofibroma,Not Reported,Not Reported,Not Reported,-999,,,,,,,,,,
		# diagnosis,PBBKUF,PBBKUF_4,8824/0 : Myofibroma,ICD-O-3.2,Initial,Clinical,8824-0 Myofibroma,Not Reported,Not Reported,C41.0 : Bones of skull and face and associated joints,1335,,,,,,,,,,
		# diagnosis,PBBMFU,,PBBMFU_5,"9380/3 : Glioma, malignant",ICD-O-3.2,Clinical,,Not Reported,Not Reported,"C71.9 : Brain, NOS",2139,,,,,,,,,,,,,
		# diagnosis,,0DA68Z,0DA68Z_diag,see diagnosis_comment,Indication for Study,Not Reported,Low-grade neuroepithelial tumor with FGFR1 pV559M and FGFR1 p.N554K mutations,Not Reported,Not Reported,C72.9 : Central nervous system,-999,,,,,,,,,,,,,
		# diagnosis,,0D88RM,0D88RM_diag,see diagnosis_comment,Indication for Study,Not Reported,Embryonal tumor with multilayered rosettes,Not Reported,Not Reported,C72.9 : Central nervous system,-999,,,,,,,,,,,,,

		diagnosiscomment=`echo "${csvlinefordiagnosis}" | csvtool -c 8 | tr -d '"'`
		diagnosisdescription="${diagnosiscomment}"
	else
		if [ -f "${ICDOFILE}" ]
		then
			# 9570/0,Preferred,"Neuroma, NOS",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
			# may be multiple Preferred entries for same code, so use head -1
			# make sure to match code at beginning of line, not in meaning (as in 'except ...')
			diagnosiscodemeaning=`egrep "^${diagnosiscodevalue},Preferred" "${ICDOFILE}" | head -1 | csvtool -c 3 | tr -d '"'`
			echo "found diagnosiscodemeaning = ${diagnosiscodemeaning}"
			if [ -z "${diagnosiscodemeaning}" ]
			then
				if [ "${diagnosiscodevalue}" = "8833/3" ]
				then
					# https://www.pathologyoutlines.com/topic/skintumornonmelanocyticdfsp.html
					# https://iris.who.int/bitstream/handle/10665/96612/9789241548496_eng.pdf?sequence=1#page=81
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Pigmented dermatofibrosarcoma protuberans"
				elif [ "${diagnosiscodevalue}" = "8936/0" ]
				then
					# 8936/0
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Gastrointestinal stromal tumor, benign"
				elif [ "${diagnosiscodevalue}" = "8936/1" ]
				then
					# 8936/1 GIST, NOS that SEER doesn't like
					# http://www.naaccr.org/wp-content/uploads/2016/11/What-the-GIST.pdf
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Gastrointestinal stromal tumor"
				elif [ "${diagnosiscodevalue}" = "9260/3" ]
				then
					# http://www.pathologyoutlines.com/topic/boneewing.html
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Ewing sarcoma"
				elif [ "${diagnosiscodevalue}" = "9540/1" ]
				then
					# http://seer.cancer.gov/tools/mphrules/mphrules_replacement_pages_04302008.pdf
					# http://seer.cancer.gov/tools/mphrules/2007/brain_benign/mp_text.pdf
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Neurofibromatosis, NOS"
				elif [ "${diagnosiscodevalue}" = "9836/3" ]
				then
					# http://seer.cancer.gov/seertools/hemelymph/51f6cf59e3e27c3994bd5468/
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Precursor B-cell lymphoblastic leukemia"
				elif [ "${diagnosiscodevalue}" = "8240/1" ]
				then
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="8240/1 Carcinoid tumor of uncertain malignant potential"
				elif [ "${diagnosiscodevalue}" = "8680/1" ]
				then
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Paraganglioma, NOS"
				elif [ "${diagnosiscodevalue}" = "8681/1" ]
				then
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Sympathetic paraganglioma"
				elif [ "${diagnosiscodevalue}" = "8700/0" ]
				then
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Pheochromocytoma, NOS"
				elif [ "${diagnosiscodevalue}" = "9530/1" ]
				then
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Meningiomatosis, NOS"
				elif [ "${diagnosiscodevalue}" = "9133/1" ]
				then
					# http://cancercenter.ai/icd-o-pathology-codes/morphological-codes-icd-o-3/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Epithelioid hemangioendothelioma, NOS"
				elif [ "${diagnosiscodevalue}" = "9380/1" ]
				then
					# https://seer.cancer.gov/seer-inquiry/inquiry-detail/20230080/
					diagnosiscsd="ICDO3"
					diagnosiscodemeaning="Glioma, NOS with borderline behavior"
				else
					echo 1>&2 "Warning: cannot find diagnosiscodevalue ${diagnosiscodevalue} in ICD-O dictionary for patient_id ${patient_id} - ignoring"
					diagnosiscodevalue=""
					# could probably just use explicit value in next column, but probably no need for this and complex to parse since quoted
				fi
			else
				if [ "${diagnosiscodevalue}" = "8634/1" ]
				then
					# "Sertoli-Leydig cell tumor, intermediate differentiation, with heterologous elements" is too long
					diagnosiscodemeaning="Sertoli-Leydig cell tumor, mod diff, with heterologous elements"
				elif [ "${diagnosiscodevalue}" = "9561/3" ]
				then
					# "Malignant peripheral nerve sheath tumor with rhabdomyoblastic differentiation" is too long
					diagnosiscodemeaning="Malignant peripheral nerve sheath tumor w. rhabdomyoblastic diff"
				fi
				diagnosiscsd="ICDO3"
				diagnosisdescription="${diagnosiscodemeaning}"
			fi
		fi
	fi
fi

echo "anatomycodemeaning = ${anatomycodemeaning}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

echo "diagnosiscodevalue = ${diagnosiscodevalue}"
echo "diagnosiscsd = ${diagnosiscsd}"
echo "diagnosiscodemeaning = ${diagnosiscodemeaning}"
echo "diagnosisdescription = ${diagnosisdescription}"

dicomdiagnosisdescription="${diagnosisdescription}"
if [ `echo -n "${diagnosisdescription}" | wc -c` -gt 64 ]
then
	# too long for VR LO - just truncate (even though VM is actually 1-n so could split with delimiter) :(
	dicomdiagnosisdescription=`echo -n "${diagnosisdescription}" | head -c 64`
	# preserve entire comment in an LT attribute, which could theoretically have other stuff already set (not yet used) ...
	# don't use newline in JSON string, which would need to be escaped, so just use space
	additionalpatienthistory=`echo "${additionalpatienthistory} Diagnosis Comment: ${diagnosisdescription}" | sed -e 's/^[ ]]*//'`
fi
echo "dicomdiagnosisdescription = ${dicomdiagnosisdescription}"
echo "additionalpatienthistory = ${additionalpatienthistory}"

# need to iterate through multiple samples on one slide

rm -f "${TMPFILEDESCRIBINGMULTIPLESAMPLES}"

sample_id_list=""

if [ -f "${CSVFILENAMEFORIMAGING}" -a -f "${CSVFILENAMEFORSAMPLE}" ]
then
	# OLD:type,sample.sample_id,pdx.pdx_id,cell_line.cell_line_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_url_in_cds,dcf_indexd_guid,magnification,fixation_embedding_method,staining_method,deidentification_method,file_mapping_level,id,sample.id,pdx.id,cell_line.id
	# OLD:type,sample.sample_id,pdx.pdx_id,cell_line.cell_line_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_url_in_cds,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,file_mapping_level,id,sample.id,pdx.id,cell_line.id
	# type,sample.sample_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_mapping_level,file_access,acl,authz,file_url,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,id,sample.id
	# type,sample.sample_id,pathology_file_id,file_name,file_type,file_description,file_size,md5sum,file_mapping_level,file_access,acl,authz,file_url,dcf_indexd_guid,image_modality,license,magnification,fixation_embedding_method,staining_method,deidentification_method,percent_tumor,percent_necrosis,id,sample.id

	# OLD:pathology_file,0DB9NX,,,0DB9NX_0DAX7K_120804.svs,0DAX7K_120804.svs,svs,,405040431,c76dbd73aea635f4faab6e4a27f38eae,,dg.4DFC/c11ab7c7-bb67-4db1-9295-f154ad12acba,40X,Optimal Cutting Temperature,Hematoxylin and Eosin Staining Method,Not applicable,,,,,
	# OLD:pathology_file,0DB9NX,,,0DAX7K_120804.svs_1,0DAX7K_120804.svs,svs,,405040431,c76dbd73aea635f4faab6e4a27f38eae,s3://TBD/,dg.4DFC/ce953bd0-f1e7-4117-a358-ff491153b894,Slide Microscopy,CC by 4.0,40X,OCT,H&E,Not applicable,100,0,,,,,
	# pathology_file,0DC7SV,0DC67X_172159.svs_2,0DC67X_172159.svs,svs,,233376443,72548664381cbbcad72acd9a2140d239,Sample,Open,['*'],['/open'],s3://TBD/,dg.4DFC/bf8c7bbc-f2c1-4793-b50a-4fb38a3c97bb,Slide Microscopy,CC by 4.0,40X,Formalin fixed paraffin embedded (FFPE),H&E,automatic,90,0,,
	# pathology_file,0D8ODV,0D8LCB_142727.svs_1,0D8LCB_142727.svs,svs,,182270463,2131afc6c5ad91417002eace6b25588d,Sample,Open,['*'],['/open'],s3://TBD/,dg.4DFC/c35f4043-6770-4f31-967a-4dffab3e0f7a,Slide Microscopy,CC by 4.0,40X,Formalin fixed paraffin embedded (FFPE),H&E,automatic,90,0,,

	# we expect multiple samples on one slide
	for sample_id in `grep ",${filename}," "${CSVFILENAMEFORIMAGING}" | csvtool -c 2 | tr -d '"'`
	do
		echo "Extracting sample-specifics for sample_id = ${sample_id}"

		sample_id_list="${sample_id_list} ${sample_id}"

		sample_fixation=""
		sample_staining=""

		csvlineforimagingforsample=`grep ",${sample_id}," "${CSVFILENAMEFORIMAGING}" | head -1`
		echo "csvlineforimagingforsample = ${csvlineforimagingforsample}"

		if [ -z "${csvlineforimagingforsample}" ]
		then
			echo 1>&2 "Warning: cannot find imaging metadata CSV file entry for sample_id ${sample_id} from which to extract fixation and staining"
		else
			fixation_embedding_method=`echo "${csvlineforimagingforsample}" | csvtool -c 19 | tr -d '"'`
			echo "fixation_embedding_method = ${fixation_embedding_method}"
			staining_method=`echo "${csvlineforimagingforsample}" | csvtool -c 20 | tr -d '"'`
			echo "staining_method = ${staining_method}"
		
			if [ "${staining_method}" = "Hematoxylin and Eosin Staining Method" -o "${staining_method}" = "H&E" ]
			then
				sample_staining="HE"
			fi
			
			if [ "${fixation_embedding_method}" = "Formalin-Fixed Paraffin-Embedded" -o "${fixation_embedding_method}" = "Formalin fixed paraffin embedded (FFPE)" -o "${fixation_embedding_method}" = "FFPE" ]
			then
				sample_fixation="FFPE"
			elif [ "${fixation_embedding_method}" = "Optimal Cutting Temperature" -o "${fixation_embedding_method}" = "OCT" ]
			then
				sample_fixation="OCT"
			fi
		fi

		echo "fixation for sample_id ${sample_id} = ${sample_fixation}"
		echo "staining for sample_id ${sample_id} = ${sample_staining}"
		
		sample_anatomycodevalue=""
		sample_anatomycsd=""
		sample_anatomycodemeaning=""

		sample_tissuetypecodevalue=""
		sample_tissuetypecsd=""
		sample_tissuetypecodemeaning=""
		sample_tissuetypeshortdescription=""

		# type,participant.participant_id,cell_line.cell_line_id,pdx.pdx_id,sample_id,anatomic_site,participant_age_at_collection,diagnosis_classification,diagnosis_classification_system,diagnosis_verification_status,diagnosis_basis,diagnosis_comment,sample_tumor_status,tumor_classification,sample_description,alternate_sample_id,last_known_disease_status,age_at_last_known_disease_status,toronto_childhood_cancer_staging,tumor_grade,tumor_stage_clinical_t,tumor_stage_clinical_n,tumor_stage_clinical_m,id,participant.id,cell_line.id,pdx.id
		# type,participant.participant_id,pdx.pdx_id,cell_line.cell_line_id,sample_id,anatomic_site,participant_age_at_collection,sample_tumor_status,tumor_classification,sample_description,id,participant.id,pdx.id,cell_line.id
		# type,participant.participant_id,pdx.pdx_id,cell_line.cell_line_id,sample_id,anatomic_site,participant_age_at_collection,sample_tumor_status,tumor_classification,sample_description,id,participant.id,pdx.id,cell_line.id

		# sample,PBCCLU,,,0DODO3,Central Nervous System,-999,see diagnosis_comment,Indication for Study,Not Reported,Not Reported,Pontine region tumor,Tumor,Not Reported,Rubbery to gelatinous cellular glioma,,,,,,,,,,,,
		# sample,PANLMU,,,0DHY31,C42.0 : Blood,-999,see diagnosis_comment,Indication for Study,Not Reported,Not Reported,Meningioma,Normal,Not Applicable,,,,,,,,,,,,,
		# sample,PBBHCR,,,0D88RM,C72.9 : Central nervous system,-999,Tumor,Not Reported,Embryonal Tumor,,,,
		# sample,PBCWKJ,,,0E1HF8,C72.9 : Central nervous system,-999,Tumor,Not Reported,,,,,

		csvlineforsample=`grep ",${sample_id}," "${CSVFILENAMEFORSAMPLE}" | head -1`
		echo "csvlineforsample = ${csvlineforsample}"

		if [ ! -z "${csvlineforsample}" ]
		then
			sample_anatomic_site=`echo "${csvlineforsample}" | csvtool -c 7 | tr -d '"'`
			echo "original sample_anatomic_site = ${sample_anatomic_site}"
			if [ ! -z "${sample_anatomic_site}" ]
			then
				sample_anatomic_site=`echo "${sample_anatomic_site}" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9.:]/ /g' | sed -e 's/[ ][ ]*/ /g'`
				echo "normalized sample_anatomic_site = ${sample_anatomic_site}"
				sample_anatomic_site=`echo "${sample_anatomic_site}" | sed -e 's/[ ][ ]*/ /g' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'`
				echo "final spaces cleaned sample_anatomic_site = ${sample_anatomic_site}"

				if [ "${sample_anatomic_site}" = "blood" -o "${sample_anatomic_site}" = "c42.0 : blood" ]
				then
					sample_anatomycodevalue="87612001"
					sample_anatomycsd="SCT"
					sample_anatomycodemeaning="Blood"
				elif [ "${sample_anatomic_site}" = "central nervous system" -o "${sample_anatomic_site}" = "c72.9 : central nervous system" ]
				then
					sample_anatomycodevalue="21483005"
					sample_anatomycsd="SCT"
					sample_anatomycodemeaning="Central nervous system"
				else
					echo 1>&2 "Warning: unrecognized anatomic_site \"${sample_anatomic_site}\" for sample_id ${sample_id}"
					# do not like using unknown, but want to include the tissue type as a modifer, so need parent :(
					sample_anatomycodevalue="10003008"
					sample_anatomycsd="SCT"
					sample_anatomycodemeaning="Unspecified"
				fi
			fi

			sample_tumor_status=`echo "${csvlineforsample}" | csvtool -c 9 | tr -d '"'`
			echo "sample_tumor_status = ${sample_tumor_status}"

			if [ "${sample_tumor_status}" = "Normal" ]
			then
				sample_tissuetypecodevalue="17621005"
				sample_tissuetypecsd="SCT"
				sample_tissuetypecodemeaning="Normal"
				sample_tissuetypeshortdescription="N"
			elif [ "${sample_tumor_status}" = "Tumor" ]
			then
				# don't know if it is primary or secondary
				sample_tissuetypecodevalue="108369006"
				sample_tissuetypecsd="SCT"
				sample_tissuetypecodemeaning="Tumor"
				sample_tissuetypeshortdescription="T"
			fi
		fi

		echo "sample_anatomycodemeaning = ${sample_anatomycodemeaning}"
		echo "sample_tissuetypecodemeaning = ${sample_tissuetypecodemeaning}"
		echo "sample_tissuetypeshortdescription = ${sample_tissuetypeshortdescription}"

		# the sample code value is usually very non-specific, so if there is a better one from diagnosis metadata, use it
		if [ -z "${anatomycodevalue}" -o "${anatomycodevalue}" = "10003008" ]
		then
			echo "Using anatomy from sample metadata since diagnosis metadata missing or unknown or unrecognized"
			use_anatomycodevalue="${sample_anatomycodevalue}"
			use_anatomycsd="${sample_anatomycsd}"
			use_anatomycodemeaning="${sample_anatomycodemeaning}"

			use_lateralitycodevalue=""
			use_lateralitycsd=""
			use_lateralitycodemeaning=""

			use_anatomymodifiercodevalue=""
			use_anatomymodifiercsd=""
			use_anatomymodifiercodemeaning=""
		else
			echo "Using anatomy from diagnosis metadata"
			use_anatomycodevalue="${anatomycodevalue}"
			use_anatomycsd="${anatomycsd}"
			use_anatomycodemeaning="${anatomycodemeaning}"

			use_lateralitycodevalue="${lateralitycodevalue}"
			use_lateralitycsd="${lateralitycsd}"
			use_lateralitycodemeaning="${lateralitycodemeaning}"

			use_anatomymodifiercodevalue="${anatomymodifiercodevalue}"
			use_anatomymodifiercsd="${anatomymodifiercsd}"
			use_anatomymodifiercodemeaning="${anatomymodifiercodemeaning}"
		fi

		# use pipe delimiters so as not to be confused by quoted strings if any when reading later
		echo >>"${TMPFILEDESCRIBINGMULTIPLESAMPLES}" "${sample_id}|${sample_fixation}|${sample_staining}|${use_anatomycodevalue}|${use_anatomycsd}|${use_anatomycodemeaning}|${use_lateralitycodevalue}|${use_lateralitycsd}|${use_lateralitycodemeaning}|${use_anatomymodifiercodevalue}|${use_anatomymodifiercsd}|${use_anatomymodifiercodemeaning}|${sample_tissuetypecodevalue}|${sample_tissuetypecsd}|${sample_tissuetypecodemeaning}|${sample_tissuetypeshortdescription}"
	done
fi

# use last values for multiple samples as expedient description ...
dicomseriesdescription="${sample_fixation} ${sample_staining} ${sample_tissuetypeshortdescription}"
echo "dicomseriesdescription = ${dicomseriesdescription}"

echo "sample_id_list = ${sample_id_list}"

cat "${TMPFILEDESCRIBINGMULTIPLESAMPLES}"

echo "outdir = ${outdir}"

dicompatientid="${patient_id}"
dicompatientname="${dicompatientid}"

#dicomspecimenidentifier is generated later for each sample, since may be more than one sample. aka. specimen

dicomstudyid="${patient_id}"
dicomaccessionnumber="${patient_id}"

# container is the slide
dicomcontaineridentifier="${slide_id}"

dicomspecimenuid=""
if [ ! -f "${FILEMAPPINGSPECIMENIDTOUID}" ]
then
	touch "${FILEMAPPINGSPECIMENIDTOUID}"
fi

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
if [ "${sex_at_birth}" = "Male" ]
then
	dicomsex="M"
elif [ "${sex_at_birth}" = "Female" ]
then
	dicomsex="F"
fi
echo "dicomsex = ${dicomsex}"

dicomage=""
if [ ! -z "${age}" ]
then
	# age at diagnosis is in days and does not ever appear to be fractional but may be small (pediatric disease)
	echo "age = ${age}"
	ageindays="${age}"
	if [ ${ageindays} -ge 999 ]
	then
		ageinmonths=`echo "scale=0; ${ageindays} / 30" | bc -l`
		echo "ageinmonths = ${ageinmonths}"
		if [ ${ageinmonths} -ge 999 ]
		then
			# won't fit in months (over 83.25 years) so convert to years as integer ...
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
	else
		if [ ${ageindays} -ge 100 ]
		then
			dicomage="${ageindays}D"
		elif [ ${ageindays} -ge 10 ]
		then
			dicomage="0${ageindays}D"
		else
			dicomage="00${ageindays}D"
		fi
	fi
fi
echo "dicomage = ${dicomage}"

dicomethnicgroup=""
ethnicgroupcodevalue_1=""
ethnicgroupcsd_1=""
ethnicgroupcodemeaning_1=""
ethnicgroupcodevalue_2=""
ethnicgroupcsd_2=""
ethnicgroupcodemeaning_2=""
ethnicgroupcodevalue_3=""
ethnicgroupcsd_3=""
ethnicgroupcodemeaning_3=""
# SH, so limited to 16 characters
if [ "${race}" = "American Indian or Alaska Native" ]
then
	dicomethnicgroup="American Indian"
	ethnicgroupcodevalue_1="413490006"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="American Indian or Alaska native"
elif [ "${race}" = "American Indian/Alaska Native" ]
then
	dicomethnicgroup="American Indian"
	ethnicgroupcodevalue_1="413490006"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="American Indian or Alaska native"
elif [ "${race}" = "American Indian or Alaska Native;White" ]
then
	dicomethnicgroup="Mx AmerInd White"
	ethnicgroupcodevalue_1="413490006"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="American Indian or Alaska native"
	ethnicgroupcodevalue_2="413773004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Caucasian race"
elif [ "${race}" = "American Indian or Alaska Native;Hispanic or Latino" ]
then
	dicomethnicgroup="Mx AmerInd Hisp"
	ethnicgroupcodevalue_1="413490006"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="American Indian or Alaska native"
	ethnicgroupcodevalue_2="414408004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Hispanic"
elif [ "${race}" = "Asian" -o "${race}" = "Asian;Unknown" ]
then
	dicomethnicgroup="Asian"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
elif [ "${race}" = "Asian;Black or African American" ]
then
	dicomethnicgroup="Mx Asian Black"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
	ethnicgroupcodevalue_2="413464008"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="African race"
elif [ "${race}" = "Asian;Hispanic or Latino;White" ]
then
	dicomethnicgroup="Mx Asn Hisp Wh"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
	ethnicgroupcodevalue_2="414408004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Hispanic"
	ethnicgroupcodevalue_2="414408004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Hispanic"
elif [ "${race}" = "Asian;Hispanic or Latino" ]
then
	dicomethnicgroup="Mx Asian Hisp"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
	ethnicgroupcodevalue_2="414408004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Hispanic"
elif [ "${race}" = "Asian;Native Hawaiian or other Pacific Islander" ]
then
	dicomethnicgroup="Mx Asian Pacific"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
	ethnicgroupcodevalue_2="C41219"
	ethnicgroupcsd_2="NCIt"
	ethnicgroupcodemeaning_2="Native Hawaiian or other Pacific Islander"
elif [ "${race}" = "Black or African American" -o "${race}" = "Black or African American;Unknown" ]
then
	dicomethnicgroup="Black"
	ethnicgroupcodevalue_1="413464008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="African race"
elif [ "${race}" = "Black or African American;Hispanic or Latino" ]
then
	dicomethnicgroup="Mx Black Hisp"
	ethnicgroupcodevalue_1="413464008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="African race"
	ethnicgroupcodevalue_2="414408004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Hispanic"
elif [ "${race}" = "Black or African American;Hispanic or Latino;White" ]
then
	dicomethnicgroup="Mx Black Hisp Wh"
	ethnicgroupcodevalue_1="413464008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="African race"
	ethnicgroupcodevalue_2="414408004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Hispanic"
	ethnicgroupcodevalue_3="413773004"
	ethnicgroupcsd_3="SCT"
	ethnicgroupcodemeaning_3="Caucasian race"
elif [ "${race}" = "Hispanic or Latino" ]
then
	dicomethnicgroup="Hispanic"
	ethnicgroupcodevalue_1="414408004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Hispanic"
elif [ "${race}" = "Hispanic or Latino;Unknown" ]
then
	dicomethnicgroup="Hispanic"
	ethnicgroupcodevalue_1="414408004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Hispanic"
elif [ "${race}" = "Hispanic or Latino;Native Hawaiian or other Pacific Islander" ]
then
	dicomethnicgroup="Mx Hisp White"
	ethnicgroupcodevalue_1="414408004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Hispanic"
	ethnicgroupcodevalue_2="C41219"
	ethnicgroupcsd_2="NCIt"
	ethnicgroupcodemeaning_2="Native Hawaiian or other Pacific Islander"
elif [ "${race}" = "Hispanic or Latino;White" ]
then
	dicomethnicgroup="Mx Hisp White"
	ethnicgroupcodevalue_1="414408004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Hispanic"
	ethnicgroupcodevalue_2="413773004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Caucasian race"
elif [ "${race}" = "Native Hawaiian or Other Pacific Islander" -o "${race}" = "Native Hawaiian or other Pacific Islander" ]
then
	dicomethnicgroup="Pacific Islander"
	ethnicgroupcodevalue_1="C41219"
	ethnicgroupcsd_1="NCIt"
	ethnicgroupcodemeaning_1="Native Hawaiian or other Pacific Islander"
elif [ "${race}" = "White" -o "${race}" = "Unknown;White" ]
then
	dicomethnicgroup="White"
	ethnicgroupcodevalue_1="413773004"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Caucasian race"
elif [ "${race}" = "Asian;White" ]
then
	dicomethnicgroup="Mx Asian White"
	ethnicgroupcodevalue_1="413582008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="Asian race"
	ethnicgroupcodevalue_2="413773004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Caucasian race"
elif [ "${race}" = "Black or African American;White" ]
then
	dicomethnicgroup="Mx Black White"
	ethnicgroupcodevalue_1="413464008"
	ethnicgroupcsd_1="SCT"
	ethnicgroupcodemeaning_1="African race"
	ethnicgroupcodevalue_2="413773004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Caucasian race"
elif [ "${race}" = "Native Hawaiian or other Pacific Islander;White" ]
then
	dicomethnicgroup="Mx Pacific White"
	ethnicgroupcodevalue_1="C41219"
	ethnicgroupcsd_1="NCIt"
	ethnicgroupcodemeaning_1="Native Hawaiian or other Pacific Islander"
	ethnicgroupcodevalue_2="413773004"
	ethnicgroupcsd_2="SCT"
	ethnicgroupcodemeaning_2="Caucasian race"
elif [ "${race}" != "Unknown or not reported" -a "${race}" != "Not Reported;Unknown" -a "${race}" != "Unknown" -a ! -z "${race}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized race ${race}"
fi

echo "dicomethnicgroup = ${dicomethnicgroup}"
echo "ethnicgroupcodevalue_1 = ${ethnicgroupcodevalue_1}"
echo "ethnicgroupcsd_1 = ${ethnicgroupcsd_1}"
echo "ethnicgroupcodemeaning_1 = ${ethnicgroupcodemeaning_1}"
echo "ethnicgroupcodevalue_2 = ${ethnicgroupcodevalue_2}"
echo "ethnicgroupcsd_2 = ${ethnicgroupcsd_2}"
echo "ethnicgroupcodemeaning_2 = ${ethnicgroupcodemeaning_2}"
echo "ethnicgroupcodevalue_3 = ${ethnicgroupcodevalue_2}"
echo "ethnicgroupcsd_3 = ${ethnicgroupcsd_3}"
echo "ethnicgroupcodemeaning_3 = ${ethnicgroupcodemeaning_2}"

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

writeSpecimenDescriptionSequenceItem()
{
	echo "Invoked writeSpecimenDescriptionSequenceItem $@"
	comma="$1"
	sample_id="$2"
	if [ ! -f "${TMPFILEDESCRIBINGMULTIPLESAMPLES}" ]
	then
		echo 2>&1 "Warning: cannot extract sample information from temporary file"
	else
		#"${sample_id}|${sample_fixation}|${sample_staining}|${use_anatomycodevalue}|${use_anatomycsd}|${use_anatomycodemeaning}|${use_lateralitycodevalue}|${use_lateralitycsd}|${use_lateralitycodemeaning}|${use_anatomymodifiercodevalue}|${use_anatomymodifiercsd}|${use_anatomymodifiercodemeaning}|${sample_tissuetypecodevalue}|${sample_tissuetypecsd}|${sample_tissuetypecodemeaning}|${sample_tissuetypeshortdescription}"
		lineforsample=`grep "^${sample_id}|" "${TMPFILEDESCRIBINGMULTIPLESAMPLES}" | head -1`
		echo "lineforsample = ${lineforsample}"

		fixation=`echo "${lineforsample}" | awk -F'|' '{print $2}'`
		staining=`echo "${lineforsample}" | awk -F'|' '{print $3}'`

		anatomycodevalue=`echo "${lineforsample}" | awk -F'|' '{print $4}'`
		anatomycsd=`echo "${lineforsample}" | awk -F'|' '{print $5}'`
		anatomycodemeaning=`echo "${lineforsample}" | awk -F'|' '{print $6}'`

		lateralitycodevalue=`echo "${lineforsample}" | awk -F'|' '{print $7}'`
		lateralitycsd=`echo "${lineforsample}" | awk -F'|' '{print $8}'`
		lateralitycodemeaning=`echo "${lineforsample}" | awk -F'|' '{print $9}'`

		anatomymodifiercodevalue=`echo "${lineforsample}" | awk -F'|' '{print $10}'`
		anatomymodifiercsd=`echo "${lineforsample}" | awk -F'|' '{print $11}'`
		anatomymodifiercodemeaning=`echo "${lineforsample}" | awk -F'|' '{print $12}'`

		tissuetypecodevalue=`echo "${lineforsample}" | awk -F'|' '{print $13}'`
		tissuetypecsd=`echo "${lineforsample}" | awk -F'|' '{print $14}'`
		tissuetypecodemeaning=`echo "${lineforsample}" | awk -F'|' '{print $15}'`
		tissuetypeshortdescription=`echo "${lineforsample}" | awk -F'|' '{print $16}'`

		echo "fixation for ${sample_id} = ${fixation}"
		echo "staining for ${sample_id} = ${staining}"

		echo "anatomycodevalue for ${sample_id} = ${anatomycodevalue}"
		echo "anatomycsd for ${sample_id} = ${anatomycsd}"
		echo "anatomycodemeaning for ${sample_id} = ${anatomycodemeaning}"

		echo "lateralitycodevalue for ${sample_id} = ${lateralitycodevalue}"
		echo "lateralitycsd for ${sample_id} = ${lateralitycsd}"
		echo "lateralitycodemeaning for ${sample_id} = ${lateralitycodemeaning}"

		echo "anatomymodifiercodevalue for ${sample_id} = ${anatomymodifiercodevalue}"
		echo "anatomymodifiercsd for ${sample_id} = ${anatomymodifiercsd}"
		echo "anatomymodifiercodemeaning for ${sample_id} = ${anatomymodifiercodemeaning}"

		echo "tissuetypecodevalue for ${sample_id} = ${tissuetypecodevalue}"
		echo "tissuetypecsd for ${sample_id} = ${tissuetypecsd}"
		echo "tissuetypecodemeaning for ${sample_id} = ${tissuetypecodemeaning}"
		echo "tissuetypeshortdescription for ${sample_id} = ${tissuetypeshortdescription}"

		dicomspecimenshortdescription="${fixation} ${staining} ${tissuetypeshortdescription}"
		echo "dicomspecimenshortdescription = ${dicomspecimenshortdescription}"

		dicomspecimendetaileddescription=""
		echo "dicomspecimendetaileddescription = ${dicomspecimendetaileddescription}"

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

if [ ! -z "${comma}" ]
then
	echo >>"${TMPJSONFILE}" "		${comma}"
fi
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
elif [ "${fixation}" = "OCT" ]
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
if [ ! -z "${fixation}" -o ! -z "${staining}" ]
then
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
	fi
}

comma=""
for sample_id in ${sample_id_list}
do
	writeSpecimenDescriptionSequenceItem "${comma}" "${sample_id}"
	comma=","
done

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
	ADDTIFF MERGESTRIPS DONOTADDDCMSUFFIX INCLUDEFILENAME INCLUDEFILEMESSAGEDIGEST
# do NOT use ADDPYRAMID since upsets BioFormats :(
date

rm "${TMPJSONFILE}"
rm "${TMPFILEDESCRIBINGMULTIPLESAMPLES}"

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
