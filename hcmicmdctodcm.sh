#!/bin/sh
#
# Usage: ./hcmicmdctodcm.sh filename.svs [outdir]

# #### DEPENDS ON csvtool installed (pip3 install.csvtool) and in path (e.g., "~/Library/Python/3.9/bin")

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

# make sure have performed dos2unix ICD-O-3.2_final_update09102020.csv so that CR is not included in extracted text
ICDOFILE="ICD-O-3.2_final_update09102020.csv"

METADATABASE="project-hcmi-cmdc.2026-02-05"

#ls -l "biospecimen.${METADATABASE}"

TSVFILENAMEFORSAMPLE="biospecimen.${METADATABASE}/sample.tsv"
if [ ! -f "${TSVFILENAMEFORSAMPLE}" ]
then
	echo 1>&2 "Error: no sample metadata CSV file called ${TSVFILENAMEFORSAMPLE}"
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
FILEMAPPINGSPECIMENIDTOUID="HCMICMDCspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="HCMICMDCstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="HCMICMDCstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="idc-conversion-outputs-hcmi-cmdc-old_tabulateduids_no_FoR.csv"
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
# "Center for Cancer Genomics at the National Cancer Institute (NCI)" is too long
dicomclinicaltrialsponsorname="Center for Cancer Genomics, National Cancer Institute (NCI)"
# lowercase "phs" as used in study.study_id (not in this project's metadata) and "https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/study.cgi?study_id=phs001239"
dicomclinicalprotocolid="phs001486"
issuerofdicomclinicalprotocolid="dbGaP"
# "NCI Cancer Model Development for the Human Cancer Model Initiative (HCMI)"
# project.project_id
dicomclinicalprotocolname="HCMI-CMDC"
doiclinicalprotocolid="10.5281/zenodo.17381441"
# will be populated later from prefix of file name (same as slides.tsv cases.submitter_id or slides.submitter_id) ...
dicomclinicaltrialsiteid=""

# "hcmi_cmdc_pathology_data/2025_10_09/HCM-WCMC-1074-C56-01A-01-S2-HE.FA5DE071-0CB8-4A7C-8FBB-F04DD082F7E4.svs"

# do not remove suffix '.svs' from filename
filename=`basename "${infile}"`
echo "filename = ${filename}"

# want slides.submitter_id not slides.slide_id (the latter being only a UUID rather than what is in filename)
# slides.slide_id fa5de071-0cb8-4a7c-8fbb-f04dd082f7e4
# slides.submitter_id HCM-WCMC-1074-C56-01A-01-S2-HE
slide_id=`echo "${filename}" | sed -e 's/^\([A-Z0-9-]*\)[.].*$/\1/'`
# slide_id = HCM-WCMC-1074-C56-01A-01-S2-HE

echo "slide_id = ${slide_id}"

if [ ! -z "${slide_id}" ]
then
	siteidfromslideid=`echo "${slide_id}" | sed -e 's/^\([A-Z][A-Z]*-[A-Z][A-Z]*\)-.*$/\1/'`
	if [ "${siteidfromslideid}" != "${slide_id}" ]
	then
		dicomclinicaltrialsiteid="${siteidfromslideid}"
	fi
fi
echo "dicomclinicaltrialsiteid = ${dicomclinicaltrialsiteid}"

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
	# project.project_id	cases.case_id	cases.submitter_id	samples.sample_id	samples.submitter_id	portions.portion_id	portions.submitter_id	slides.bone_marrow_malignant_cells	slides.number_proliferating_cells	slides.percent_eosinophil_infiltration	slides.percent_follicular_component	slides.percent_granulocyte_infiltration	slides.percent_inflam_infiltration	slides.percent_lymphocyte_infiltration	slides.percent_monocyte_infiltration	slides.percent_necrosis	slides.percent_neutrophil_infiltration	slides.percent_normal_cells	slides.percent_rhabdoid_features	slides.percent_sarcomatoid_features	slides.percent_stromal_cells	slides.percent_tumor_cells	slides.percent_tumor_nuclei	slides.prostatic_chips_positive_count	slides.prostatic_chips_total_count	slides.prostatic_involvement_percent	slides.section_location	slides.slide_id	slides.state	slides.submitter_id	slides.tissue_microarray_coordinates
	# HCMI-CMDC	5538445e-03c2-4466-a09a-83d5a527b26e	HCM-WCMC-1074-C56	2256014d-e230-4ef6-8a23-d2c7b3e29d40	HCM-WCMC-1074-C56-01A	73807334-9364-459e-8dff-a3260b91c226	HCM-WCMC-1074-C56-01A-01	'--	'--	'--	'--	'--	'--	0	0	0	0	0	'--	'--	70	30	40	'--	'--	'--	BOTTOM	fa5de071-0cb8-4a7c-8fbb-f04dd082f7e4	released	HCM-WCMC-1074-C56-01A-01-S2-HE	'--
	
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
	
	getcolumnfromtsvheader "portions.submitter_id" "${TSVFILENAMEFORSLIDE}"
	portion_id=`echo "${tsvlineforslide}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "portion_id = ${portion_id}"
	
	# could get derived values for slide too, like "slides.percent_lymphocyte_infiltration" :(
fi

dicomclinicaltrialsubjectid="${patient_id}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

if [ -f "${TSVFILENAMEFORCLINICAL}" ]
then
	# project.project_id	cases.case_id	cases.consent_type	cases.days_to_consent	cases.days_to_lost_to_followup	cases.disease_type	cases.index_date	cases.lost_to_followup	cases.primary_site	cases.submitter_id	demographic.age_at_index	demographic.age_is_obfuscated	demographic.cause_of_death	demographic.cause_of_death_source	demographic.country_of_birth	demographic.country_of_residence_at_enrollment	demographic.days_to_birth	demographic.days_to_death	demographic.demographic_id	demographic.education_level	demographic.ethnicity	demographic.gender	demographic.marital_status	demographic.occupation_duration_years	demographic.population_group	demographic.premature_at_birth	demographic.race	demographic.submitter_id	demographic.vital_status	demographic.weeks_gestation_at_birth	demographic.year_of_birth	demographic.year_of_death	diagnoses.adrenal_hormone	diagnoses.age_at_diagnosis	diagnoses.ajcc_clinical_m	diagnoses.ajcc_clinical_n	diagnoses.ajcc_clinical_stage	diagnoses.ajcc_clinical_t	diagnoses.ajcc_pathologic_m	diagnoses.ajcc_pathologic_n	diagnoses.ajcc_pathologic_stage	diagnoses.ajcc_pathologic_t	diagnoses.ajcc_serum_tumor_markers	diagnoses.ajcc_staging_system_edition	diagnoses.ann_arbor_b_symptoms	diagnoses.ann_arbor_b_symptoms_described	diagnoses.ann_arbor_clinical_stage	diagnoses.ann_arbor_extranodal_involvement	diagnoses.ann_arbor_pathologic_stage	diagnoses.best_overall_response	diagnoses.burkitt_lymphoma_clinical_variant	diagnoses.calgb_risk_group	diagnoses.cancer_detection_method	diagnoses.child_pugh_classification	diagnoses.clark_level	diagnoses.classification_of_tumor	diagnoses.cog_liver_stage	diagnoses.cog_neuroblastoma_risk_group	diagnoses.cog_renal_stage	diagnoses.cog_rhabdomyosarcoma_risk_group	diagnoses.contiguous_organ_invaded	diagnoses.days_to_best_overall_response	diagnoses.days_to_diagnosis	diagnoses.days_to_last_follow_up	diagnoses.days_to_last_known_disease_status	diagnoses.days_to_recurrence	diagnoses.diagnosis_id	diagnoses.diagnosis_is_primary_disease	diagnoses.double_expressor_lymphoma	diagnoses.double_hit_lymphoma	diagnoses.eln_risk_classification	diagnoses.enneking_msts_grade	diagnoses.enneking_msts_metastasis	diagnoses.enneking_msts_stage	diagnoses.enneking_msts_tumor_site	diagnoses.ensat_clinical_m	diagnoses.ensat_pathologic_n	diagnoses.ensat_pathologic_stage	diagnoses.ensat_pathologic_t	diagnoses.esophageal_columnar_dysplasia_degree	diagnoses.esophageal_columnar_metaplasia_present	diagnoses.fab_morphology_code	diagnoses.figo_stage	diagnoses.figo_staging_edition_year	diagnoses.first_symptom_longest_duration	diagnoses.first_symptom_prior_to_diagnosis	diagnoses.gastric_esophageal_junction_involvement	diagnoses.gleason_grade_group	diagnoses.gleason_grade_tertiary	diagnoses.gleason_patterns_percent	diagnoses.gleason_score	diagnoses.goblet_cells_columnar_mucosa_present	diagnoses.icd_10_code	diagnoses.igcccg_stage	diagnoses.inpc_grade	diagnoses.inpc_histologic_group	diagnoses.inrg_stage	diagnoses.inss_stage	diagnoses.international_prognostic_index	diagnoses.irs_group	diagnoses.irs_stage	diagnoses.ishak_fibrosis_score	diagnoses.iss_stage	diagnoses.last_known_disease_status	diagnoses.laterality	diagnoses.margin_distance	diagnoses.margins_involved_site	diagnoses.masaoka_stage	diagnoses.max_tumor_bulk_site	diagnoses.medulloblastoma_molecular_classification	diagnoses.melanoma_known_primary	diagnoses.metastasis_at_diagnosis	diagnoses.metastasis_at_diagnosis_site	diagnoses.method_of_diagnosis	diagnoses.micropapillary_features	diagnoses.mitosis_karyorrhexis_index	diagnoses.mitotic_count	diagnoses.morphology	diagnoses.ovarian_specimen_status	diagnoses.ovarian_surface_involvement	diagnoses.papillary_renal_cell_type	diagnoses.pediatric_kidney_staging	diagnoses.peritoneal_fluid_cytological_status	diagnoses.pregnant_at_diagnosis	diagnoses.primary_diagnosis	diagnoses.primary_disease	diagnoses.primary_gleason_grade	diagnoses.prior_malignancy	diagnoses.prior_treatment	diagnoses.progression_or_recurrence	diagnoses.residual_disease	diagnoses.satellite_nodule_present	diagnoses.secondary_gleason_grade	diagnoses.site_of_resection_or_biopsy	diagnoses.sites_of_involvement	diagnoses.sites_of_involvement_count	diagnoses.submitter_id	diagnoses.supratentorial_localization	diagnoses.synchronous_malignancy	diagnoses.tissue_or_organ_of_origin	diagnoses.tumor_burden	diagnoses.tumor_confined_to_organ_of_origin	diagnoses.tumor_depth	diagnoses.tumor_focality	diagnoses.tumor_grade	diagnoses.tumor_grade_category	diagnoses.tumor_of_origin	diagnoses.tumor_regression_grade	diagnoses.uicc_clinical_m	diagnoses.uicc_clinical_n	diagnoses.uicc_clinical_stage	diagnoses.uicc_clinical_t	diagnoses.uicc_pathologic_m	diagnoses.uicc_pathologic_n	diagnoses.uicc_pathologic_stage	diagnoses.uicc_pathologic_t	diagnoses.uicc_staging_system_edition	diagnoses.ulceration_indicator	diagnoses.weiss_assessment_findings	diagnoses.weiss_assessment_score	diagnoses.who_cns_grade	diagnoses.who_nte_grade	diagnoses.wilms_tumor_histologic_subtype	diagnoses.year_of_diagnosis	treatments.chemo_concurrent_to_radiation	treatments.clinical_trial_indicator	treatments.course_number	treatments.days_to_treatment_end	treatments.days_to_treatment_start	treatments.drug_category	treatments.embolic_agent	treatments.initial_disease_status	treatments.lesions_treated_number	treatments.margin_distance	treatments.margin_status	treatments.margins_involved_site	treatments.number_of_cycles	treatments.number_of_fractions	treatments.prescribed_dose	treatments.prescribed_dose_units	treatments.pretreatment	treatments.protocol_identifier	treatments.radiosensitizing_agent	treatments.reason_treatment_ended	treatments.reason_treatment_not_given	treatments.regimen_or_line_of_therapy	treatments.residual_disease	treatments.route_of_administration	treatments.submitter_id	treatments.therapeutic_agents	treatments.therapeutic_level_achieved	treatments.therapeutic_levels_achieved	treatments.therapeutic_target_level	treatments.timepoint_category	treatments.treatment_anatomic_site	treatments.treatment_anatomic_sites	treatments.treatment_arm	treatments.treatment_dose	treatments.treatment_dose_max	treatments.treatment_dose_units	treatments.treatment_duration	treatments.treatment_effect	treatments.treatment_effect_indicator	treatments.treatment_frequency	treatments.treatment_id	treatments.treatment_intent_type	treatments.treatment_or_therapy	treatments.treatment_outcome	treatments.treatment_outcome_duration	treatments.treatment_type
	
	# each participant may have multiple rows (e.g., for each treatment type)
	# HCMI-CMDC	5538445e-03c2-4466-a09a-83d5a527b26e	'--	'--	'--	Cystic, Mucinous and Serous Neoplasms	Diagnosis	'--	Ovary	HCM-WCMC-1074-C56	'--	FALSE	'--	'--	'--	'--	-26625	'--	a1d1ddd0-b8b9-42fa-9497-35615de24870	'--	not hispanic or latino	female	'--	'--	'--	'--	white	HCM-WCMC-1074-C56_demographic	Alive	'--	1946	'--	'--	26625	'--	'--	'--	'--	'--	NX	'--	T1c2	'--	8th	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	primary	'--	'--	'--	'--	'--	'--	'--	1281	'--	'--	b2ee880b-b20c-443b-9e73-1300c21840cf	TRUE	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Stage IC2	'--	'--	'--	'--	'--	'--	'--	'--	'--	C56.9	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Right	'--	'--	'--	'--	'--	'--	No Metastasis	'--	'--	'--	'--	'--	8480/3	Ovarian Capsule Ruptured	Indeterminate	'--	'--	Non-Malignant	'--	Mucinous adenocarcinoma	'--	'--	no	No	'--	R0	'--	'--	Ovary	'--	'--	HCM-WCMC-1074-C56_diagnosis	'--	'--	Ovary	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Residual Disease	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	HCM-WCMC-1074-C56_treatment4	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	24312c9f-cd1b-49fc-ba65-11eb9b3c3854	Adjuvant	no	'--	'--	Radiation Therapy, NOS
	# HCMI-CMDC	5538445e-03c2-4466-a09a-83d5a527b26e	'--	'--	'--	Cystic, Mucinous and Serous Neoplasms	Diagnosis	'--	Ovary	HCM-WCMC-1074-C56	'--	FALSE	'--	'--	'--	'--	-26625	'--	a1d1ddd0-b8b9-42fa-9497-35615de24870	'--	not hispanic or latino	female	'--	'--	'--	'--	white	HCM-WCMC-1074-C56_demographic	Alive	'--	1946	'--	'--	26625	'--	'--	'--	'--	'--	NX	'--	T1c2	'--	8th	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	primary	'--	'--	'--	'--	'--	'--	'--	1281	'--	'--	b2ee880b-b20c-443b-9e73-1300c21840cf	TRUE	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Stage IC2	'--	'--	'--	'--	'--	'--	'--	'--	'--	C56.9	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Right	'--	'--	'--	'--	'--	'--	No Metastasis	'--	'--	'--	'--	'--	8480/3	Ovarian Capsule Ruptured	Indeterminate	'--	'--	Non-Malignant	'--	Mucinous adenocarcinoma	'--	'--	no	No	'--	R0	'--	'--	Ovary	'--	'--	HCM-WCMC-1074-C56_diagnosis	'--	'--	Ovary	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	HCM-WCMC-1074-C56_treatment	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	29c7170c-64fe-43bc-8119-b5ee6b53d806	Neoadjuvant	no	'--	'--	'--
	# HCMI-CMDC	5538445e-03c2-4466-a09a-83d5a527b26e	'--	'--	'--	Cystic, Mucinous and Serous Neoplasms	Diagnosis	'--	Ovary	HCM-WCMC-1074-C56	'--	FALSE	'--	'--	'--	'--	-26625	'--	a1d1ddd0-b8b9-42fa-9497-35615de24870	'--	not hispanic or latino	female	'--	'--	'--	'--	white	HCM-WCMC-1074-C56_demographic	Alive	'--	1946	'--	'--	26625	'--	'--	'--	'--	'--	NX	'--	T1c2	'--	8th	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	primary	'--	'--	'--	'--	'--	'--	'--	1281	'--	'--	b2ee880b-b20c-443b-9e73-1300c21840cf	TRUE	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Stage IC2	'--	'--	'--	'--	'--	'--	'--	'--	'--	C56.9	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Right	'--	'--	'--	'--	'--	'--	No Metastasis	'--	'--	'--	'--	'--	8480/3	Ovarian Capsule Ruptured	Indeterminate	'--	'--	Non-Malignant	'--	Mucinous adenocarcinoma	'--	'--	no	No	'--	R0	'--	'--	Ovary	'--	'--	HCM-WCMC-1074-C56_diagnosis	'--	'--	Ovary	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	0	'--	'--	Initial Diagnosis	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	HCM-WCMC-1074-C56_treatment2	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	2dfa0f29-36fa-443c-9394-6f5a7db2ec23	'--	yes	'--	'--	Surgery, NOS
	# HCMI-CMDC	5538445e-03c2-4466-a09a-83d5a527b26e	'--	'--	'--	Cystic, Mucinous and Serous Neoplasms	Diagnosis	'--	Ovary	HCM-WCMC-1074-C56	'--	FALSE	'--	'--	'--	'--	-26625	'--	a1d1ddd0-b8b9-42fa-9497-35615de24870	'--	not hispanic or latino	female	'--	'--	'--	'--	white	HCM-WCMC-1074-C56_demographic	Alive	'--	1946	'--	'--	26625	'--	'--	'--	'--	'--	NX	'--	T1c2	'--	8th	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	primary	'--	'--	'--	'--	'--	'--	'--	1281	'--	'--	b2ee880b-b20c-443b-9e73-1300c21840cf	TRUE	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Stage IC2	'--	'--	'--	'--	'--	'--	'--	'--	'--	C56.9	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Right	'--	'--	'--	'--	'--	'--	No Metastasis	'--	'--	'--	'--	'--	8480/3	Ovarian Capsule Ruptured	Indeterminate	'--	'--	Non-Malignant	'--	Mucinous adenocarcinoma	'--	'--	no	No	'--	R0	'--	'--	Ovary	'--	'--	HCM-WCMC-1074-C56_diagnosis	'--	'--	Ovary	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	Residual Disease	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	HCM-WCMC-1074-C56_treatment3	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	8e0f40a5-3c80-4806-8381-267d8dfaaa48	Adjuvant	no	'--	'--	Pharmaceutical Therapy, NOS

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
	diagnosiscodevalue=`grep -i "\x22${diagnosis}\x22" "${ICDOFILE}" | grep ',Preferred,' | head -1 | awk -F, '{print $1}'`
	if [ -z "${diagnosiscodevalue}" ]
	then
		diagnosiscodevalue=`grep -i "${diagnosis}" "${ICDOFILE}" | grep ',Preferred,' | head -1 | awk -F, '{print $1}'`
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

if [ "${diagnosiscodevalue}" = "8453/3" ]
then
	# "Intraductal papillary mucinous neoplasm with an associated invasive carcinoma" is too long (> 64 chars)
	diagnosiscodemeaning="Intraductal papillary mucinous neoplasm with invasive carcinoma"
elif [ "${diagnosiscodevalue}" = "8461/6" ]
then
	# no meaning from look up available
	diagnosiscodevalue="8461/3"
	diagnosiscodemeaning="Serous surface papillary carcinoma"
elif [ "${diagnosiscodevalue}" = "8249/6" ]
then
	# no meaning from look up available
	# https://www.pathologyoutlines.com/topic/lungtumoratypicalcarcinoid.html
	diagnosiscodevalue="8249/3"
	diagnosiscodemeaning="Atypical carcinoid tumor"
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
	if   [ "${anatomic_site}" = "Abdomen, NOS" ]
	then
	    # use code for "Structure of abdominopelvic segment excluding true pelvic segment of trunk (body structure)"
		anatomycodevalue="818985005"
		anatomycsd="SCT"
		anatomycodemeaning="Abdomen proper"
	elif [ "${anatomic_site}" = "Adrenal gland, NOS" ]
	then
		anatomycodevalue="23451007"
		anatomycsd="SCT"
		anatomycodemeaning="Adrenal gland"
	elif [ "${anatomic_site}" = "Ampulla of Vater" ]
	then
		anatomycodevalue="67109009"
		anatomycsd="SCT"
		anatomycodemeaning="Ampulla of Vater"
	elif [ "${anatomic_site}" = "Ascending colon" ]
	then
		anatomycodevalue="9040008"
		anatomycsd="SCT"
		anatomycodemeaning="Ascending colon"
	elif [ "${anatomic_site}" = "Bladder, NOS" ]
	then
		anatomycodevalue="89837001"
		anatomycsd="SCT"
		anatomycodemeaning="Bladder"
	elif [ "${anatomic_site}" = "Blood" ]
	then
		anatomycodevalue="87612001"
		anatomycsd="SCT"
		anatomycodemeaning="Blood"
	elif [ "${anatomic_site}" = "Body of pancreas" ]
	then
		anatomycodevalue="40133006"
		anatomycsd="SCT"
		anatomycodemeaning="Body of pancreas"
	elif [ "${anatomic_site}" = "Body of stomach" ]
	then
		anatomycodevalue="68560004"
		anatomycsd="SCT"
		anatomycodemeaning="Body of stomach"
	elif [ "${anatomic_site}" = "Bone marrow" ]
	then
		anatomycodevalue="14016003"
		anatomycsd="SCT"
		anatomycodemeaning="Bone marrow"
	elif [ "${anatomic_site}" = "Bone, NOS" ]
	then
		anatomycodevalue="272673000"	# use structure
		#anatomycodevalue="3138006"		# not tissue
		anatomycsd="SCT"
		anatomycodemeaning="Bone"
	elif [ "${anatomic_site}" = "Border of tongue" ]
	then
		anatomycodevalue="24649007"
		anatomycsd="SCT"
		anatomycodemeaning="Border of tongue"
	elif [ "${anatomic_site}" = "Brain, NOS" ]
	then
		anatomycodevalue="12738006"
		anatomycsd="SCT"
		anatomycodemeaning="Brain"
	elif [ "${anatomic_site}" = "Breast, NOS" ]
	then
		anatomycodevalue="76752008"
		anatomycsd="SCT"
		anatomycodemeaning="Breast"
	elif [ "${anatomic_site}" = "Cardia, NOS" ]
	then
		anatomycodevalue="80891009"
		anatomycsd="SCT"
		anatomycodemeaning="Heart"
	elif [ "${anatomic_site}" = "Cecum" ]
	then
		anatomycodevalue="32713005"
		anatomycsd="SCT"
		anatomycodemeaning="Cecum"
	elif [ "${anatomic_site}" = "Cheek mucosa" ]
	then
		anatomycodevalue="16811007"
		anatomycsd="SCT"
		anatomycodemeaning="Buccal mucosa"
	elif [ "${anatomic_site}" = "Colon, NOS" ]
	then
		anatomycodevalue="71854001"
		anatomycsd="SCT"
		anatomycodemeaning="Colon"
	elif [ "${anatomic_site}" = "Connective, subcutaneous and other soft tissues of lower limb and hip" ]
	then
		anatomycodevalue="67328008"
		anatomycsd="SCT"
		anatomycodemeaning="Soft tissue of lower extremity"
	elif [ "${anatomic_site}" = "Connective, subcutaneous and other soft tissues of thorax" ]
	then
		anatomycodevalue="31749008"
		anatomycsd="SCT"
		anatomycodemeaning="Soft tissue of thorax"
	elif [ "${anatomic_site}" = "Connective, subcutaneous and other soft tissues, NOS" ]
	then
		anatomycodevalue="87784001"
		anatomycsd="SCT"
		anatomycodemeaning="Soft tissue"
	elif [ "${anatomic_site}" = "Corpus uteri" ]
	then
		anatomycodevalue="23952005"
		anatomycsd="SCT"
		anatomycodemeaning="Body of uterus"
	elif [ "${anatomic_site}" = "Descending colon" ]
	then
		anatomycodevalue="32622004"
		anatomycsd="SCT"
		anatomycodemeaning="Descending colon"
	elif [ "${anatomic_site}" = "Duodenum" ]
	then
		anatomycodevalue="38848004"
		anatomycsd="SCT"
		anatomycodemeaning="Duodenum"
	elif [ "${anatomic_site}" = "Endometrium" ]
	then
		anatomycodevalue="2739003"
		anatomycsd="SCT"
		anatomycodemeaning="Endometrium"
	elif [ "${anatomic_site}" = "Esophagus, NOS" ]
	then
		anatomycodevalue="32849002"
		anatomycsd="SCT"
		anatomycodemeaning="Esophagus"
	elif [ "${anatomic_site}" = "Extrahepatic bile duct" ]
	then
		anatomycodevalue="16014003"
		anatomycsd="SCT"
		anatomycodemeaning="Extrahepatic bile duct"
	elif [ "${anatomic_site}" = "Fundus uteri" ]
	then
		anatomycodevalue="27485007"
		anatomycsd="SCT"
		anatomycodemeaning="Uterine fundus"
	elif [ "${anatomic_site}" = "Gallbladder" ]
	then
		anatomycodevalue="28231008"
		anatomycsd="SCT"
		anatomycodemeaning="Gallbladder"
	elif [ "${anatomic_site}" = "Gastric antrum" ]
	then
		anatomycodevalue="66051006"
		anatomycsd="SCT"
		anatomycodemeaning="Gastric antrum"
	elif [ "${anatomic_site}" = "Glottis" ]
	then
		anatomycodevalue="1307006"
		anatomycsd="SCT"
		anatomycodemeaning="Glottis"
	elif [ "${anatomic_site}" = "Head of pancreas" ]
	then
		anatomycodevalue="64163001"
		anatomycsd="SCT"
		anatomycodemeaning="Head of pancreas"
	elif [ "${anatomic_site}" = "Head, face or neck, NOS" ]
	then
		anatomycodevalue="774007"
		anatomycsd="SCT"
		anatomycodemeaning="Head and neck"
	elif [ "${anatomic_site}" = "Hematopoietic system, NOS" ]
	then
		anatomycodevalue="57171008"
		anatomycsd="SCT"
		anatomycodemeaning="Hematopoietic system"
	elif [ "${anatomic_site}" = "Hepatic flexure of colon" ]
	then
		anatomycodevalue="48338005"
		anatomycsd="SCT"
		anatomycodemeaning="Hepatic flexure of colon"
	elif [ "${anatomic_site}" = "Ileum" ]
	then
		anatomycodevalue="34516001"
		anatomycsd="SCT"
		anatomycodemeaning="Ileum"
	elif [ "${anatomic_site}" = "Intra-abdominal lymph nodes" ]
	then
		anatomycodevalue="818991007"
		anatomycsd="SCT"
		anatomycodemeaning="Abdominal lymph node"
	elif [ "${anatomic_site}" = "Isthmus uteri" ]
	then
		anatomycodevalue="53935009"
		anatomycsd="SCT"
		anatomycodemeaning="Isthmus of uterus"
	elif [ "${anatomic_site}" = "Kidney, NOS" ]
	then
		anatomycodevalue="64033007"
		anatomycsd="SCT"
		anatomycodemeaning="Kidney"
	elif [ "${anatomic_site}" = "Lateral wall of bladder" ]
	then
		anatomycodevalue="19318009"
		anatomycsd="SCT"
		anatomycodemeaning="Lateral wall of bladder"
	elif [ "${anatomic_site}" = "Liver" ]
	then
		anatomycodevalue="10200004"
		anatomycsd="SCT"
		anatomycodemeaning="Liver"
	elif [ "${anatomic_site}" = "Lower gum" ]
	then
		anatomycodevalue="57131003"
		anatomycsd="SCT"
		anatomycodemeaning="Lower gum"
	# for consistency with other TCGA collections (e.g., CCDP-EAGLE), we pre-coordinate laterality for lung lobes :(
	elif [ "${anatomic_site}" = "Lower lobe, lung" ]
	then
		if [ "${laterality}" = "Left" ]
		then
			anatomycodevalue="41224006"
			anatomycsd="SCT"
			anatomycodemeaning="Lower lobe of left lung"
		elif [ "${laterality}" = "Right" ]
		then
			anatomycodevalue="266005"
			anatomycsd="SCT"
			anatomycodemeaning="Lower lobe of right lung"
		else
			anatomycodevalue="90572001"
			anatomycsd="SCT"
			anatomycodemeaning="Lower lobe of lung"
		fi
		laterality=""	# to supress addition of post-coordinated laterality later
	elif [ "${anatomic_site}" = "Upper lobe, lung" ]
	then
		if [ "${laterality}" = "Left" ]
		then
			anatomycodevalue="44714003"
			anatomycsd="SCT"
			anatomycodemeaning="Upper lobe of left lung"
		elif [ "${laterality}" = "Right" ]
		then
			anatomycodevalue="42400003"
			anatomycsd="SCT"
			anatomycodemeaning="Upper lobe of right lung"
		else
			anatomycodevalue="45653009"
			anatomycsd="SCT"
			anatomycodemeaning="Upper lobe of lung"
		fi
		laterality=""	# to supress addition of post-coordinated laterality later
	elif [ "${anatomic_site}" = "Middle lobe, lung" ]
	then
		anatomycodevalue="72481006"
		anatomycsd="SCT"
		anatomycodemeaning="Middle lobe of right lung"
		if [ "${laterality}" = "Left" ]
		then
			echo 1>&2 "Warning: unexpexcted laterality ${laterality} for ${anatomic_site}"
		fi
		laterality=""	# to supress addition of post-coordinated laterality later
	elif [ "${anatomic_site}" = "Lower third of esophagus" ]
	then
		anatomycodevalue="67173009"
		anatomycsd="SCT"
		anatomycodemeaning="Lower third of esophagus"
	elif [ "${anatomic_site}" = "Lung, NOS" ]
	then
		anatomycodevalue="39607008"
		anatomycsd="SCT"
		anatomycodemeaning="Lung"
		# not bothering to precoordinate left and right long (inconsistent with pattern for lobes) :(
	elif [ "${anatomic_site}" = "Lymph node, NOS" ]
	then
		anatomycodevalue="59441001"
		anatomycsd="SCT"
		anatomycodemeaning="Lymph node"
	elif [ "${anatomic_site}" = "Lymph nodes of axilla or arm" ]
	then
		anatomycodevalue="44914007"
		anatomycsd="SCT"
		anatomycodemeaning="Upper limb lymph node"
	elif [ "${anatomic_site}" = "Lymph nodes of inguinal region or leg" ]
	then
		anatomycodevalue="4942000"
		anatomycsd="SCT"
		anatomycodemeaning="Lower limb lymph node"
	elif [ "${anatomic_site}" = "Middle third of esophagus" ]
	then
		anatomycodevalue="19000002"
		anatomycsd="SCT"
		anatomycodemeaning="Middle third of esophagus"
	elif [ "${anatomic_site}" = "Nasal cavity" ]
	then
		anatomycodevalue="279549004"
		anatomycsd="SCT"
		anatomycodemeaning="Nasal cavity"
	elif [ "${anatomic_site}" = "Ovary" ]
	then
		anatomycodevalue="15497006"
		anatomycsd="SCT"
		anatomycodemeaning="Ovary"
	elif [ "${anatomic_site}" = "Overlapping lesion of bladder" ]
	then
		anatomycodevalue="89837001"
		anatomycsd="SCT"
		anatomycodemeaning="Bladder"
	elif [ "${anatomic_site}" = "Overlapping lesion of female genital organs" ]
	then
		anatomycodevalue="127882003"
		anatomycsd="SCT"
		anatomycodemeaning="Female genital organ"
	elif [ "${anatomic_site}" = "Pancreas, NOS" ]
	then
		anatomycodevalue="15776009"
		anatomycsd="SCT"
		anatomycodemeaning="Pancreas"
	elif [ "${anatomic_site}" = "Pancreatic duct" ]
	then
		anatomycodevalue="69930009"
		anatomycsd="SCT"
		anatomycodemeaning="Pancreatic duct"
	elif [ "${anatomic_site}" = "Pancreatic neck" ]
	then
		anatomycodevalue="245381005"
		anatomycsd="SCT"
		anatomycodemeaning="Neck of pancreas"
	elif [ "${anatomic_site}" = "Parotid gland" ]
	then
		anatomycodevalue="45289007"
		anatomycsd="SCT"
		anatomycodemeaning="Parotid gland"
	elif [ "${anatomic_site}" = "Pelvis, NOS" ]
	then
		anatomycodevalue="12921003"
		anatomycsd="SCT"
		anatomycodemeaning="Pelvis"
	elif [ "${anatomic_site}" = "Peritoneum, NOS" ]
	then
		anatomycodevalue="15425007"
		anatomycsd="SCT"
		anatomycodemeaning="Peritoneum"
	elif [ "${anatomic_site}" = "Pleura, NOS" ]
	then
		anatomycodevalue="3120008"
		anatomycsd="SCT"
		anatomycodemeaning="Pleura"
	elif [ "${anatomic_site}" = "Rectosigmoid junction" ]
	then
		anatomycodevalue="49832006"
		anatomycsd="SCT"
		anatomycodemeaning="Rectosigmoid junction"
	elif [ "${anatomic_site}" = "Rectum, NOS" ]
	then
		anatomycodevalue="34402009"
		anatomycsd="SCT"
		anatomycodemeaning="Rectum"
	elif [ "${anatomic_site}" = "Sigmoid colon" ]
	then
		anatomycodevalue="60184004"
		anatomycsd="SCT"
		anatomycodemeaning="Sigmoid colon"
	elif [ "${anatomic_site}" = "Skin, NOS" ]
	then
		anatomycodevalue="39937001"
		anatomycsd="SCT"
		anatomycodemeaning="Skin"
	elif [ "${anatomic_site}" = "Small intestine, NOS" ]
	then
		anatomycodevalue="30315005"
		anatomycsd="SCT"
		anatomycodemeaning="Small intestine"
	elif [ "${anatomic_site}" = "Specified parts of peritoneum" ]
	then
		anatomycodevalue="15425007"
		anatomycsd="SCT"
		anatomycodemeaning="Peritoneum"
	elif [ "${anatomic_site}" = "Spleen" ]
	then
		anatomycodevalue="78961009"
		anatomycsd="SCT"
		anatomycodemeaning="Spleen"
	elif [ "${anatomic_site}" = "Splenic flexure of colon" ]
	then
		anatomycodevalue="72592005"
		anatomycsd="SCT"
		anatomycodemeaning="Splenic flexure of colon"
	elif [ "${anatomic_site}" = "Stomach, NOS" ]
	then
		anatomycodevalue="69695003"
		anatomycsd="SCT"
		anatomycodemeaning="Stomach"
	elif [ "${anatomic_site}" = "Tail of pancreas" ]
	then
		anatomycodevalue="73239005"
		anatomycsd="SCT"
		anatomycodemeaning="Tail of pancreas"
	elif [ "${anatomic_site}" = "Thorax, NOS" ]
	then
		anatomycodevalue="51185008"
		anatomycsd="SCT"
		anatomycodemeaning="Chest"
	elif [ "${anatomic_site}" = "Tongue, NOS" ]
	then
		anatomycodevalue="21974007"
		anatomycsd="SCT"
		anatomycodemeaning="Tongue"
	elif [ "${anatomic_site}" = "Transverse colon" ]
	then
		anatomycodevalue="485005"
		anatomycsd="SCT"
		anatomycodemeaning="Transverse colon"
	elif [ "${anatomic_site}" = "Ureter" ]
	then
		anatomycodevalue="87953007"
		anatomycsd="SCT"
		anatomycodemeaning="Ureter"
	elif [ "${anatomic_site}" = "Uterine adnexa" ]
	then
		anatomycodevalue="23043003"
		anatomycsd="SCT"
		anatomycodemeaning="Uterine adnexa"
	elif [ "${anatomic_site}" = "Uterus, NOS" ]
	then
		anatomycodevalue="35039007"
		anatomycsd="SCT"
		anatomycodemeaning="Uterus"
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
	#if [ "${primary_site}" = "Bronchus and lung" ]
	#then
	#	# include lung and tracheobronchial structure
	#	anatomycodevalue="82094008"
	#	anatomycsd="SCT"
	#	anatomycodemeaning="Lower respiratory tract"
	#else
		# do not like using unspecified, but want to include the tissue type as a modifer, so need parent :(
		anatomycodevalue="10003008"
		anatomycsd="SCT"
		anatomycodemeaning="Unspecified"
	#fi
fi

# may have been supressed by lung lobe pre-coordination
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
	# project.project_id	cases.case_id	cases.submitter_id	samples.biospecimen_anatomic_site	samples.biospecimen_laterality	samples.catalog_reference	samples.composition	samples.current_weight	samples.days_to_collection	samples.days_to_sample_procurement	samples.diagnosis_pathologically_confirmed	samples.distance_normal_to_tumor	samples.distributor_reference	samples.freezing_method	samples.growth_rate	samples.initial_weight	samples.intermediate_dimension	samples.is_ffpe	samples.longest_dimension	samples.method_of_sample_procurement	samples.oct_embedded	samples.passage_count	samples.pathology_report_uuid	samples.preservation_method	samples.sample_id	samples.sample_ordinal	samples.sample_type	samples.sample_type_id	samples.shortest_dimension	samples.specimen_type	samples.state	samples.submitter_id	samples.time_between_clamping_and_freezing	samples.time_between_excision_and_freezing	samples.tissue_collection_type	samples.tissue_type	samples.tumor_code	samples.tumor_code_id	samples.tumor_descriptor
	# CDDP_EAGLE-1	6c37ec77-c88c-49da-9b88-986efafd4d88	CDDP-A8B0	'--	'--	'--	'--	'--	4434	'--	'--	'--	'--	'--	'--	'--	'--	false	'--	'--	false	'--	93EE08D5-9518-401E-9568-DE195CF6E1CA	Snap Frozen	325a1607-7787-4a8c-b19c-1a0aec86e5c0	'--	Primary Tumor	01	'--	Solid Tissue	released	CDDP-A8B0-TTP1-C	'--	'--	'--	Tumor	'--	'--	Primary
	
	tsvlineforsample=`grep "	${sample_id}	" "${TSVFILENAMEFORSAMPLE}" | head -1`
	echo "tsvlineforsample = ${tsvlineforsample}"
fi

if [ ! -z "${tsvlineforsample}" ]
then
	getcolumnfromtsvheader "samples.is_ffpe" "${TSVFILENAMEFORSAMPLE}"
	is_ffpe=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	echo "is_ffpe = ${is_ffpe}"
	
	# samples.oct_embedded is always FALSE
	#getcolumnfromtsvheader "samples.oct_embedded" "${TSVFILENAMEFORSAMPLE}"
	#oct_embedded=`echo "${tsvlineforsample}" | csvtool -d '	' -c ${column} | tr -d '"'`
	#echo "oct_embedded = ${oct_embedded}"
	
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

echo "fixation = ${fixation}"

# not in metadata, seems to be in filenames (e.g., "HCM-WCMC-1074-C56-01A-01-S2-HE.FA5DE071-0CB8-4A7C-8FBB-F04DD082F7E4.svs"), but same for all so don't bother checking filename
staining="HE"
echo "staining = ${staining}"

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

dicomseriesdescription="${fixation} ${staining} ${tissuetypeshortdescription}"
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
