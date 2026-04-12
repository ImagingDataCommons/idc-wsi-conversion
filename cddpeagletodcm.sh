#!/bin/sh
#
# Usage: ./cddpeagletodcm.sh filename.svs [outdir]

# #### DEPENDS ON csvtool installed (pip3 install.csvtool) and in path (e.g., "~/Library/Python/3.9/bin")

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

# make sure have performed dos2unix ICD-O-3.2_final_update09102020.csv so that CR is not included in extracted text
ICDOFILE="ICD-O-3.2_final_update09102020.csv"

METADATABASE="project-cddp_eagle-1.2025-10-13"

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
FILEMAPPINGSPECIMENIDTOUID="CDDPEAGLEspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="CDDPEAGLEstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="CDDPEAGLEstudyIDToDateTimeMap.csv"

UIDMAPPINGFILE="idc-conversion-outputs-ccdp_eagle-old_tabulateduids_no_FoR.csv"
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

# From primary EAGLE paper "https://doi.org/10.1186/1471-2458-8-203"
dicomclinicaltrialcoordinatingcentername="University of Milan - Epidemiology Research Center (EPOCA)"
dicomclinicaltrialsponsorname="NCI - Division of Cancer Epidemiology & Genetics (DCEG)"
# lowercase "phs" as used in study.study_id (not in this project's metadata) and "https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/study.cgi?study_id=phs001239"
dicomclinicalprotocolid="phs001239"
issuerofdicomclinicalprotocolid="dbGaP"
# "Integrative Analysis of Lung Adenocarcinoma in EAGLE (Phase 2)"
# project.project_id
dicomclinicalprotocolname="CDDP_EAGLE-1"
doiclinicalprotocolid="10.5281/zenodo.17372206"
dicomclinicaltrialsiteid=""

# "idc-source-data-ccdp_eagle-1/CDDP-A8B0-TTP1-C-1-0-S1.93AF1AF2-95D4-4E9E-B9CC-189207F91DB4.svs"

# do not remove suffix '.svs' from filename
filename=`basename "${infile}"`
echo "filename = ${filename}"

# want slides.submitter_id not slides.slide_id (the latter, btw., being lowercase rather than what is in filename)
slide_id=`echo "${filename}" | sed -e 's/^\([A-Z0-9-]*\)[.].*$/\1/'`
# slide_id = CDDP-A8B0-TTP1-C-1-0-S1

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
	# project.project_id	cases.case_id	cases.submitter_id	samples.sample_id	samples.submitter_id	portions.portion_id	portions.submitter_id	slides.bone_marrow_malignant_cells	slides.number_proliferating_cells	slides.percent_eosinophil_infiltration	slides.percent_follicular_component	slides.percent_granulocyte_infiltration	slides.percent_inflam_infiltration	slides.percent_lymphocyte_infiltration	slides.percent_monocyte_infiltration	slides.percent_necrosis	slides.percent_neutrophil_infiltration	slides.percent_normal_cells	slides.percent_rhabdoid_features	slides.percent_sarcomatoid_features	slides.percent_stromal_cells	slides.percent_tumor_cells	slides.percent_tumor_nuclei	slides.prostatic_chips_positive_count	slides.prostatic_chips_total_count	slides.prostatic_involvement_percent	slides.section_location	slides.slide_id	slides.state	slides.submitter_id	slides.tissue_microarray_coordinates
	# CDDP_EAGLE-1	6c37ec77-c88c-49da-9b88-986efafd4d88	CDDP-A8B0	325a1607-7787-4a8c-b19c-1a0aec86e5c0	CDDP-A8B0-TTP1-C	bb78961e-05f7-4bc2-a671-937d9eca0ea3	CDDP-A8B0-TTP1-C-1-0	'--	'--	'--	'--	'--	'--	0.0	0.0	15.0	0.0	0.0	'--	'--	0.0	85.0	65.0	'--	'--	'--	TOP	7e7c37e2-125e-4a2e-9921-8d790405536e	released	CDDP-A8B0-TTP1-C-1-0-S1	'--
	
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
	# project.project_id	cases.case_id	cases.consent_type	cases.days_to_consent	cases.days_to_lost_to_followup	cases.disease_type	cases.index_date	cases.lost_to_followup	cases.primary_site	cases.submitter_id	demographic.age_at_index	demographic.age_is_obfuscated	demographic.cause_of_death	demographic.cause_of_death_source	demographic.country_of_birth	demographic.country_of_residence_at_enrollment	demographic.days_to_birth	demographic.days_to_death	demographic.demographic_id	demographic.education_level	demographic.ethnicity	demographic.gender	demographic.marital_status	demographic.occupation_duration_years	demographic.population_group	demographic.premature_at_birth	demographic.race	demographic.submitter_id	demographic.vital_status	demographic.weeks_gestation_at_birth	demographic.year_of_birth	demographic.year_of_death	diagnoses.adrenal_hormone	diagnoses.age_at_diagnosis	diagnoses.ajcc_clinical_m	diagnoses.ajcc_clinical_diagnoses.ajcc_clinical_stage	diagnoses.ajcc_clinical_t	diagnoses.ajcc_pathologic_m	diagnoses.ajcc_pathologic_n	diagnoses.ajcc_pathologic_stage	diagnoses.ajcc_pathologic_t	diagnoses.ajcc_serum_tumor_markers	diagnoses.ajcc_staging_system_edition	diagnoses.ann_arbor_b_symptoms	diagnoses.ann_arbor_b_symptoms_described	diagnoses.ann_arbor_clinical_stage	diagnoses.ann_arbor_extranodal_involvement	diagnoses.ann_arbor_pathologic_stage	diagnoses.best_overall_response	diagnoses.burkitt_lymphoma_clinical_variant	diagnoses.calgb_risk_group	diagnoses.cancer_detection_method	diagnoses.child_pugh_classification	diagnoses.clark_level	diagnoses.classification_of_tumor	diagnoses.cog_liver_stage	diagnoses.cog_neuroblastoma_risk_group	diagnoses.cog_renal_stage	diagnoses.cog_rhabdomyosarcoma_risk_group	diagnoses.contiguous_organ_invaded	diagnoses.days_to_best_overall_response	diagnoses.days_to_diagnosis	diagnoses.days_to_last_follow_up	diagnoses.days_to_last_known_disease_status	diagnoses.days_to_recurrence	diagnoses.diagnosis_id	diagnoses.diagnosis_is_primary_disease	diagnoses.double_expressor_lymphoma	diagnoses.double_hit_lymphoma	diagnoses.eln_risk_classification	diagnoses.enneking_msts_grade	diagnoses.enneking_msts_metastasis	diagnoses.enneking_msts_stage	diagnoses.enneking_msts_tumor_site	diagnoses.ensat_clinical_m	diagnoses.ensat_pathologic_n	diagnoses.ensat_pathologic_stage	diagnoses.ensat_pathologic_t	diagnoses.esophageal_columnar_dysplasia_degree	diagnoses.esophageal_columnar_metaplasia_present	diagnoses.fab_morphology_code	diagnoses.figo_stage	diagnoses.figo_staging_edition_year	diagnoses.first_symptom_longest_duration	diagnoses.first_symptom_prior_to_diagnosis	diagnoses.gastric_esophageal_junction_involvement	diagnoses.gleason_grade_group	diagnoses.gleason_grade_tertiary	diagnoses.gleason_patterns_percent	diagnoses.gleason_score	diagnoses.goblet_cells_columnar_mucosa_present	diagnoses.icd_10_code	diagnoses.igcccg_stage	diagnoses.inpc_grade	diagnoses.inpc_histologic_group	diagnoses.inrg_stage	diagnoses.inss_stage	diagnoses.international_prognostic_index	diagnoses.irs_group	diagnoses.irs_stage	diagnoses.ishak_fibrosis_score	diagnoses.iss_stage	diagnoses.last_known_disease_status	diagnoses.laterality	diagnoses.margin_distance	diagnoses.margins_involved_site	diagnoses.masaoka_stage	diagnoses.max_tumor_bulk_site	diagnoses.medulloblastoma_molecular_classification	diagnoses.melanoma_known_primary	diagnoses.metastasis_at_diagnosis	diagnoses.metastasis_at_diagnosis_site	diagnoses.method_of_diagnosis	diagnoses.micropapillary_features	diagnoses.mitosis_karyorrhexis_index	diagnoses.mitotic_count	diagnoses.morphology	diagnoses.ovarian_specimen_status	diagnoses.ovarian_surface_involvement	diagnoses.papillary_renal_cell_type	diagnoses.pediatric_kidney_staging	diagnoses.peritoneal_fluid_cytological_status	diagnoses.pregnant_at_diagnosis	diagnoses.primary_diagnosis	diagnoses.primary_disease	diagnoses.primary_gleason_grade	diagnoses.prior_malignancy	diagnoses.prior_treatment	diagnoses.progression_or_recurrence	diagnoses.residual_disease	diagnoses.satellite_nodule_present	diagnoses.secondary_gleason_grade	diagnoses.site_of_resection_or_biopsy	diagnoses.sites_of_involvement	diagnoses.sites_of_involvement_count	diagnoses.submitter_id	diagnoses.supratentorial_localization	diagnoses.synchronous_malignancy	diagnoses.tissue_or_organ_of_origin	diagnoses.tumor_burden	diagnoses.tumor_confined_to_organ_of_origin	diagnoses.tumor_depth	diagnoses.tumor_focality	diagnoses.tumor_grade	diagnoses.tumor_grade_category	diagnoses.tumor_of_origin	diagnoses.tumor_regression_grade	diagnoses.uicc_clinical_m	diagnoses.uicc_clinical_n	diagnoses.uicc_clinical_stage	diagnoses.uicc_clinical_diagnoses.uicc_pathologic_m	diagnoses.uicc_pathologic_n	diagnoses.uicc_pathologic_stage	diagnoses.uicc_pathologic_t	diagnoses.uicc_staging_system_edition	diagnoses.ulceration_indicator	diagnoses.weiss_assessment_findings	diagnoses.weiss_assessment_score	diagnoses.who_cns_grade	diagnoses.who_nte_grade	diagnoses.wilms_tumor_histologic_subtype	diagnoses.year_of_diagnosis	treatments.chemo_concurrent_to_radiation	treatments.clinical_trial_indicator	treatments.course_number	treatments.days_to_treatment_end	treatments.days_to_treatment_start	treatments.drug_category	treatments.embolic_agent	treatments.initial_disease_status	treatments.lesions_treated_number	treatments.margin_distance	treatments.margin_status	treatments.margins_involved_site	treatments.number_of_cycles	treatments.number_of_fractions	treatments.prescribed_dose	treatments.prescribed_dose_units	treatments.pretreatment	treatments.protocol_identifier	treatments.radiosensitizing_agent	treatments.reason_treatment_ended	treatments.reason_treatment_not_given	treatments.regimen_or_line_of_therapy	treatments.residual_disease	treatments.route_of_administration	treatments.submitter_id	treatments.therapeutic_agents	treatments.therapeutic_level_achieved	treatments.therapeutic_levels_achieved	treatments.therapeutic_target_level	treatments.timepoint_category	treatments.treatment_anatomic_site	treatments.treatment_anatomic_sites	treatments.treatment_arm	treatments.treatment_dose	treatments.treatment_dose_max	treatments.treatment_dose_units	treatments.treatment_duration	treatments.treatment_effect	treatments.treatment_effect_indicator	treatments.treatment_frequency	treatments.treatment_id	treatments.treatment_intent_type	treatments.treatment_or_therapy	treatments.treatment_outcome	treatments.treatment_outcome_duration	treatments.treatment_type

	# each participant may have multiple rows (e.g., for each treatment type)
	# CDDP_EAGLE-1	6c37ec77-c88c-49da-9b88-986efafd4d88	'--	'--	'--	Adenomas and Adenocarcinomas	'--	No	Bronchus and lung	CDDP-A8B0	66	'--	Cancer Related	'--	'--	'--	-24386	308	806504a7-49cb-5d25-b972-0fee7a042d89	'--	not hispanic or latino	male	'--	'--	'--	'--	white	CDDP-A8B0_demographic	Dead	'--	1937	2003	'--	66	'--	'--	'--	'--	M0	N0	Stage IA	T1b	'--	7th	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	not reported	'--	'--	'--	'--	'--	'--	0	308.0	'--	'--	fe14f4e2-dd07-54c1-aeb9-058e188ccf29	true	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	C34.3	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	With tumor	Left	'--	'--	'--	'--	'--	'--	'--	'--	Surgical Resection	'--	'--	'--	8255/3	'--	'--	'--	'--	'--	'--	Adenocarcinoma with mixed subtypes	'--	'--	no	No	not reported	'--	'--	'--	Lung, NOS	'--	'--	CDDP-A8B0_diagnosis	'--	No	Lower lobe, lung	'--	'--	'--	'--	Not Reported	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	2003	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	CDDP-A8B0_treatment_1	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	498ee05d-748f-5d04-ac82-3d4ad8a02bf3	'--	no	'--	'--	Pharmaceutical Therapy, NOS
	# CDDP_EAGLE-1	6c37ec77-c88c-49da-9b88-986efafd4d88	'--	'--	'--	Adenomas and Adenocarcinomas	'--	No	Bronchus and lung	CDDP-A8B0	66	'--	Cancer Related	'--	'--	'--	-24386	308	806504a7-49cb-5d25-b972-0fee7a042d89	'--	not hispanic or latino	male	'--	'--	'--	'--	white	CDDP-A8B0_demographic	Dead	'--	1937	2003	'--	66	'--	'--	'--	'--	M0	N0	Stage IA	T1b	'--	7th	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	not reported	'--	'--	'--	'--	'--	'--	0	308.0	'--	'--	fe14f4e2-dd07-54c1-aeb9-058e188ccf29	true	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	C34.3	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	With tumor	Left	'--	'--	'--	'--	'--	'--	'--	'--	Surgical Resection	'--	'--	'--	8255/3	'--	'--	'--	'--	'--	'--	Adenocarcinoma with mixed subtypes	'--	'--	no	No	not reported	'--	'--	'--	Lung, NOS	'--	'--	CDDP-A8B0_diagnosis	'--	No	Lower lobe, lung	'--	'--	'--	'--	Not Reported	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	2003	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	CDDP-A8B0_treatment	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	'--	d8e763a6-967b-59c0-a9f9-9e6cd29760e2	'--	no	'--	'--	Radiation Therapy, NOS

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

	getcolumnfromtsvheader "diagnoses.tissue_or_organ_of_origin" "${TSVFILENAMEFORCLINICAL}"
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
	fi
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

if [ ! -z "${anatomic_site}" ]
then
	if   [ "${anatomic_site}" = "Lower lobe, lung" ]
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
	elif [ "${anatomic_site}" = "Middle lobe, lung" ]
	then
		anatomycodevalue="72481006"
		anatomycsd="SCT"
		anatomycodemeaning="Middle lobe of right lung"
		if [ "${laterality}" = "Left" ]
		then
			echo 1>&2 "Warning: unexpexcted laterality ${laterality} for ${anatomic_site}"
		fi
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
	if [ "${primary_site}" = "Bronchus and lung" ]
	then
		# include lung and tracheobronchial structure
		anatomycodevalue="82094008"
		anatomycsd="SCT"
		anatomycodemeaning="Lower respiratory tract"
	else
		# do not like using unspecified, but want to include the tissue type as a modifer, so need parent :(
		anatomycodevalue="10003008"
		anatomycsd="SCT"
		anatomycodemeaning="Unspecified"
	fi
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
elif [ "${preservation_method}" = "Snap Frozen" ]
then
	# not "OCT" sinces amples.oct_embedded is always FALSE, and don't know what freezing method was used :(
	fixation="FZ"
fi

echo "fixation = ${fixation}"

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

dicomstudyid="${patient_id}"
dicomaccessionnumber="${patient_id}"

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
