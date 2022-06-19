#!/bin/sh
#
# Usage: ./htantodcm.sh path/filename.tif|tiff|svs [outdir]

infile="$1"
outdir="$2"

# may need -m 0 to disable memory limit on buffer else fails with large files (added in libtiff 4.2.0)
#tiffcpoptions="-m 0"
tiffcpoptions=""

outdirprefix="Converted/HTAN-V1-Feb-2022/HTAN"

#csvfilename="htan-metadata-orig-332.csv"
#csvfilename="htan_metadata_v1_178_Feb2022.csv"
#csvfilename="HTAN-V1-Feb-2022_htan_metadata_v1_256_Mar2022.csv"
#csvfilename="HTAN_V1_metadata_256_May2022.csv"
csvfilename="HTAN_V1_metadata.csv"

channelindexfilename="bq_channel_files.csv"
channelmetadatadirectory="channel_metadata_files"

specimenanddemographicmetadatadirecory="MetadataFromPortal"

TMPJSONFILE="/tmp/`basename $0`.$$.json"
TMPTIFFCPOUTPUTDIR="/tmp"

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="HTANspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="HTANstudyIDToUIDMap.csv"
#FILEMAPPINGSTUDYIDTODATETIME="HTANstudyIDToDateTimeMap.csv"

#JHOVE="${HOME}/work/jhove/jhove"

PIXELMEDDIR="${HOME}/work/pixelmed/imgbook"
PATHTOADDITIONAL="${PIXELMEDDIR}/lib/additional"

filename=`basename "${infile}"`
echo "filename = ${filename}"
filenamewithoutextension=`echo "${filename}" | sed -e 's/[.]ome[.]tiff$//' -e 's/[.]ome[.]tif$//' -e 's/[.]tiff$//' -e 's/[.]tif$//' -e 's/[.]svs$//'`
echo "filenamewithoutextension = ${filenamewithoutextension}"
# at this point ${filenamewithoutextension} may have embedded spaces and/or funky characters, which cause problems iterating through outdir later
filenamewithoutextensionorfunkychars=`echo "${filenamewithoutextension}" | tr -c '[_0-9A-Za-z]' '_' | sed -e 's/^_//g' -e 's/_$//g'`
echo "filenamewithoutextensionorfunkychars = ${filenamewithoutextensionorfunkychars}"
tmptiffcpoutputfile="${TMPTIFFCPOUTPUTDIR}/${filename}"
echo "tmptiffcpoutputfile = ${tmptiffcpoutputfile}"

# "HTAN-WUSTL/H&E/HT60P1 REMAINS.svs"
# "HTAN-WUSTL/IMC/HT061P1_PA_A1_A4_ROI_01.ome.tiff"
# "HTAN-OHSU/CyCIF/BEMS350173_Scene-004.ome.tif"
# "HTAN-Vanderbilt/MxIF/HTA11_377_20000010115220280010000000000.tif"

if [ -f "${csvfilename}" ]
then
	# deal with commas in quoted strings
	# tr in case CSV has DOS rather than Unix line ending
	csvlineforslide=`grep "${filename}" "${csvfilename}" | tr -d '\r' | sed -e 's/\("[^"]*\),\([^"]*"\)/\1;\2/g' | head -1`
else
	echo 1>&2 "Error: cannot find metadata CSV file ${csvfilename} - not converting"
	exit 1
fi

htancenter=`echo "${infile}" | sed -e 's/^.*\(HTAN[ -][A-Z][A-Za-z]*\)\/.*$/\1/'`
echo "htancenter from filename = ${htancenter}"

if [ -z "${csvlineforslide}" ]
then
	if [ "${htancenter}" = "HTAN WUSTL" -o "${htancenter}" = "HTAN-WUSTL" ]
	then
		# 2022/03/06 - deal with WUSTL IMC images not in spreadsheet :(
		# "HT056P1_PA_A1_A4_ROI_01.ome.tiff"
		# "HTAN_HT122P1_S1H3_L1_L4_ROI_001.ome.tiff"
		# Judging by SVS examples that are in the spreadsheet, the filename has nothing to with HTAN participant or parent specimen ID,
		# e.g., "HT56P1 A.svs" => slide parent specimen HTA12_1_101
		# so, just for testing, assume HTnn is the participant and HTnn[A-Z]nn is the parent specimen ID
		htanparentspecimenid=`echo "$filenamewithoutextensionorfunkychars}" | sed -e 's/^.*\(HT[0-9]*\)\([A-Z]*[0-9]*\)_\([^_]*\).*$/\1_\2_\3/'`
		echo "htanparentspecimenid from filename for WUSTL not in metadata = ${htanparentspecimenid}"
	else
		echo 1>&2 "Error: cannot find metadata CSV file entry for filename ${filename} - not converting"
		exit 1
	fi
else
	# HTAN_Parent_Biospecimen_ID
	htanparentspecimenid=`echo "${csvlineforslide}" | awk -F, '{print $4}'`
	# HTAN_Data_File_ID
	htandatafileid=`echo "${csvlineforslide}" | awk -F, '{print $5}'`
	# Imaging_Assay_Type
	htanassaytype=`echo "${csvlineforslide}" | awk -F, '{print $7}'`
	# HTAN_Center - used to fail because some earlier columns ($8) are sometimes quoted and contain ',', but fixed that now with sed - vide supra
	htancenter=`echo "${csvlineforslide}" | awk -F, '{print $45}'`
	echo "htancenter from metadata = ${htancenter}"

	physicalsizex=`echo "${csvlineforslide}" | awk -F, '{print $30}'`
	echo "physicalsizex = ${physicalsizex}"
	physicalsizexunits=`echo "${csvlineforslide}" | awk -F, '{print $31}'`
	echo "physicalsizexunits = ${physicalsizexunits}"
	physicalsizey=`echo "${csvlineforslide}" | awk -F, '{print $32}'`
	echo "physicalsizey = ${physicalsizey}"
	physicalsizeyunits=`echo "${csvlineforslide}" | awk -F, '{print $33}'`
	echo "physicalsizeyunits = ${physicalsizeyunits}"
	physicalsizez=`echo "${csvlineforslide}" | awk -F, '{print $34}'`
	echo "physicalsizez = ${physicalsizez}"
	physicalsizezunits=`echo "${csvlineforslide}" | awk -F, '{print $35}'`
	echo "physicalsizezunits = ${physicalsizezunits}"

	nominalmagnification=`echo "${csvlineforslide}" | awk -F, '{print $12}' | sed -e 's/[^0-9.]//g'`	# sometimes has "X" on end as in "40X" - just want number
	echo "nominalmagnification = ${nominalmagnification}"

	lensna=`echo "${csvlineforslide}" | awk -F, '{print $13}' | sed -e 's/[^0-9]//g'`	# sometimes has non-numeric entry, e.g., "Not Applicable" (WUSTL-IMC)
	echo "lensna = ${lensna}"

	microscope=`echo "${csvlineforslide}" | awk -F, '{print $10}' | sed -e 's/"//g'`
	echo "microscope = ${microscope}"
fi

echo "htanparentspecimenid = ${htanparentspecimenid}"
echo "htandatafileid = ${htandatafileid}"
echo "htanassaytype = ${htanassaytype}"

htanproject=`echo "${htancenter}" | sed -e 's/ /-/g'`
echo "htanproject = ${htanproject}"

if [ -z "${outdir}" ]
then
	outdir="${outdirprefix}/${htanproject}/${filenamewithoutextensionorfunkychars}"
fi

if [ -z "${htanparentspecimenid}" ]
then
	echo 1>&2 "Error: could not extract htanparentspecimenid from metadata CSV file entry for filename ${filename} - not converting"
	exit 1
else
	# per Adam Taylor, "HTAN Participant ID is always resolvable from a HTAN Biospecimen or Data File ID by regex to capture the first two elements of the ID"
	# HTA9_1_93 -> HTA9_1
	# HTA7_963_2 -> HTA7_963 - fixed after 2022/02/28 HMS conversion released to group
	htanparticipantid=`echo "${htanparentspecimenid}" | sed -e 's/^\([^_]*_[^_]*\)_.*$/\1/'`
	echo "htanparticipantid = ${htanparticipantid}"
	dicompatientid="${htanparticipantid}"
	dicompatientname="${dicompatientid}^"
	dicomparentspecimenidentifier="${htanparentspecimenid}"
	dicomspecimenidentifier="${htandatafileid}"

	# there may be commas embedded in quoted strings, esp. Adjacent Biospecimen IDs column
	csvlinefromdemographics=`cat ${specimenanddemographicmetadatadirecory}/synapse_storage_manifest_*_Demographics_*.csv | grep ",${htanparticipantid}," | sed -e 's/\("[^"]*\),\([^"]*"\)/\1;\2/g' | head -1`

	if [ -z "${csvlinefromdemographics}" ]
	then
		echo 1>&2 "Warning: could not find ${htanparticipantid} in Demographics metadata"
	else
		gender=`echo "${csvlinefromdemographics}" | awk -F, '{print $4}'`
		race=`echo "${csvlinefromdemographics}" | awk -F, '{print $5}'`
		vitalstatus=`echo "${csvlinefromdemographics}" | awk -F, '{print $6}'`
	fi

	csvlinefrombiospecimen=`cat ${specimenanddemographicmetadatadirecory}/synapse_storage_manifest_*_Biospecimen_*.csv | grep ",${htanparentspecimenid}," | sed -e 's/\("[^"]*\),\([^"]*"\)/\1;\2/g' | head -1`
	if [ -z "${csvlinefrombiospecimen}" ]
	then
		echo 1>&2 "Warning: could not find ${htanparentspecimenid} in Biospecimen metadata"
	else
		siteofbiopsy=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $10}'`
		fixative=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $9}'`
		acquisitionmethod=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $8}'`
		biospecimentype=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $7}'`
		timepoint=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $4}'`
		preservationmethod=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $51}'`
		tissuetype=`echo "${csvlinefrombiospecimen}" | awk -F, '{print $60}'`
	fi
fi

echo "gender = ${gender}"
echo "race = ${race}"
echo "vitalstatus = ${vitalstatus}"

echo "siteofbiopsy = ${siteofbiopsy}"
echo "fixative = ${fixative}"
echo "acquisitionmethod = ${acquisitionmethod}"
echo "biospecimentype = ${biospecimentype}"
echo "timepoint = ${timepoint}"
echo "preservationmethod = ${preservationmethod}"
echo "tissuetype = ${tissuetype}"

# make study, accession same as case (patient)
# ideally would make sure these are no longer than 16 chars ... assume it for now :(
dicomstudyid="${dicompatientid}"
dicomaccessionnumber="${dicompatientid}"

# container is the slide
#dicomcontaineridentifier="${filenamewithoutextension}"
dicomcontaineridentifier="${dicomspecimenidentifier}"

dicomclinicaltrialcoordinatingcentername="HTAN"
dicomclinicaltrialsponsorname="NCI"
dicomclinicalprotocolid="${htanproject}"
dicomclinicalprotocolname=""

dicomclinicaltrialsiteid="${htanproject}"

dicomclinicaltrialsitename=""
if [ "${dicomclinicaltrialsiteid}" = "HTAN-OHSU" ]
then
	dicomclinicaltrialsitename="Oregon Health Sciences University"
elif [ "${dicomclinicaltrialsiteid}" = "HTAN-WUSTL" ]
then
	dicomclinicaltrialsitename="Washington University St Louis"
elif [ "${dicomclinicaltrialsiteid}" = "HTAN-Vanderbilt" ]
then
	dicomclinicaltrialsitename="Vanderbilt University Medical Center"
elif [ "${dicomclinicaltrialsiteid}" = "HTAN-HMS" ]
then
	dicomclinicaltrialsitename="Harvard Medical School"
fi

dicominstitutionname="${dicomclinicaltrialsitename}"
dicomclinicaltrialsubjectid="${dicompatientid}"
dicomclinicaltrialtimepointid="${timepoint}"

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

# not trying to make StudyDate/Time consistent, because not present in OME-TIFF and not enough SVS to justify ... :(

dicommanufacturer=""
dicommanufacturermodelname=""
if [ "${microscope}" = "Leica SCN400;Leica SCN" ]
then
	dicommanufacturer="Leica Biosystems"
	dicommanufacturermodelname="SCN400 converted by com.pixelmed.convert.TIFFToDicom"
elif [ "${microscope}" = "Leica; Aperio AT2" ]
then
	dicommanufacturer="Leica Biosystems"
	dicommanufacturermodelname="Aperio AT2 converted by com.pixelmed.convert.TIFFToDicom"
elif [ "${microscope}" = "PATH-APERIOAT2" ]
then
	dicommanufacturer="Leica Biosystems"
	dicommanufacturermodelname="Aperio AT2 converted by com.pixelmed.convert.TIFFToDicom"
elif [ "${microscope}" = "AxiScan Z1" ]
then
	dicommanufacturer="ZEISS"
	dicommanufacturermodelname="AxioScan.Z1 converted by com.pixelmed.convert.TIFFToDicom"
elif [ "${microscope}" = "RareCyte;CF;46" ]
then
	dicommanufacturer="RareCyte"
	dicommanufacturermodelname="CyteFinder converted by com.pixelmed.convert.TIFFToDicom"
	# what significance is the "46" ?
else
	echo 1>&2 "Warning: ignoring unrecognized or unwanted microscope ${microscope}"
fi
echo "dicommanufacturer = ${dicommanufacturer}"
echo "dicommanufacturermodelname = ${dicommanufacturermodelname}"

dicomsex=""
if [ "${gender}" = "male" ]
then
	dicomsex="M"
elif [ "${gender}" = "female" ]
then
	dicomsex="F"
fi
echo "dicomsex = ${dicomsex}"

dicomethnicgroup=""
# SH, so limited to 16 characters
if [ "${race}" = "asian" ]
then
	dicomethnicgroup="Asian"
elif [ "${race}" = "black or african american" ]
then
	dicomethnicgroup="Black"
elif [ "${race}" = "white" ]
then
	dicomethnicgroup="White"
else
	# ignore "Not Reported"
	# ignore "Other"
	# ignore "unknown"
	echo 1>&2 "Warning: ignoring unrecognized or unwanted race ${race}"
fi
echo "dicomethnicgroup = ${dicomethnicgroup}"

healthstatuscodevalue=""
healthstatuscsd="SCT"
healthstatuscodemeaning=""
if [ "${vitalstatus}" = "Alive" ]
then
	healthstatuscodevalue="438949009"
	healthstatuscodemeaning="Alive"
elif [ "${vitalstatus}" = "Dead" ]
then
	healthstatuscodevalue="419099009"
	healthstatuscodemeaning="Deceased"
else
	# ignore "Not Reported"
	# ignore "unknown"
	echo 1>&2 "Warning: ignoring unrecognized or unwanted vitalstatus ${vitalstatus}"
fi
echo "dicompatientname = ${dicompatientname}"
echo "dicompatientid = ${dicompatientid}"
echo "dicomstudyid = ${dicomstudyid}"
echo "dicomstudyuid = ${dicomstudyuid}"
#echo "dicomstudydatetime = ${dicomstudydatetime}"
#echo "dicomstudydate = ${dicomstudydate}"
#echo "dicomstudytime = ${dicomstudytime}"
echo "dicomaccessionnumber = ${dicomaccessionnumber}"
echo "dicomparentspecimenidentifier = ${dicomparentspecimenidentifier}"
echo "dicomspecimenidentifier = ${dicomspecimenidentifier}"
echo "dicomspecimenuid = ${dicomspecimenuid}"
echo "dicomcontaineridentifier = ${dicomcontaineridentifier}"
echo "dicomclinicaltrialcoordinatingcentername = ${dicomclinicaltrialcoordinatingcentername}"
echo "dicomclinicaltrialsponsorname = ${dicomclinicaltrialsponsorname}"
echo "dicomclinicalprotocolid = ${dicomclinicalprotocolid}"
echo "dicomclinicalprotocolname = ${dicomclinicalprotocolname}"
echo "dicomclinicaltrialsiteid = ${dicomclinicaltrialsiteid}"
echo "dicomclinicaltrialsitename = ${dicomclinicaltrialsitename}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"
echo "dicomclinicaltrialtimepointid = ${dicomclinicaltrialtimepointid}"
echo "dicominstitutionname = ${dicominstitutionname}"

specimencollectioncodevalue=""
specimencollectioncsd="SCT"
specimencollectioncodemeaning=""

# CID 8109
if [ "${acquisitionmethod}" = "Biopsy" ]
then
	specimencollectioncodevalue="86273004"
	specimencollectioncodemeaning="Biopsy"
elif [ "${acquisitionmethod}" = "Punch Biopsy" ]
then
	# need to add to CID 8109, freeset :(
	specimencollectioncodevalue="68660007"
	specimencollectioncodemeaning="Punch biopsy"
elif [ "${acquisitionmethod}" = "Shave Biopsy" ]
then
	# need to add to CID 8109, freeset :(
	specimencollectioncodevalue="72342005"
	specimencollectioncodemeaning="Shave biopsy"
elif [ "${acquisitionmethod}" = "Excision" ]
then
	# same code for Excision and Resection in SNOMED - CP2160
	specimencollectioncodevalue="65801008"
	specimencollectioncodemeaning="Excision"
elif [ "${acquisitionmethod}" = "Surgical Resection" ]
then
	# same code for Excision and Resection in SNOMED - CP2160
	specimencollectioncodevalue="65801008"
	specimencollectioncodemeaning="Resection"
else
	# ignore "Other Acquisition Method"
	echo 1>&2 "Warning: ignoring unrecognized or unwanted acquisitionmethod ${acquisitionmethod}"
fi

tissuetypecodevalue=""
tissuetypecsd="SCT"
tissuetypecodemeaning=""

# not ideal mapping - mixes qualifier value, finding and morphological abnormality :(
if [ "${tissuetype}" = "Normal" ]
then
	tissuetypecodevalue="17621005"
	tissuetypecodemeaning="Normal"
elif [ "${tissuetype}" = "Primary" ]
then
	tissuetypecodevalue="86049000"
	tissuetypecodemeaning="Neoplasm, Primary"
elif [ "${tissuetype}" = "Metastatic" ]
then
	tissuetypecodevalue="14799000"
	tissuetypecodemeaning="Neoplasm, Metastatic"
elif [ "${tissuetype}" = "Recurrent" ]
then
	tissuetypecodevalue="25173007"
	tissuetypecodemeaning="Recurrent tumor"
elif [ "${tissuetype}" = "Atypia - hyperplasia" ]
then
	# do not use 32416003 "Atypical hyperplasia", since that is only for breast ?? :(
	# encountered with colon locations
	# which is it ? atypia or hyperplasia? or both? - pick hyperplasia since only one choice :(
	tissuetypecodevalue="76197007"
	tissuetypecodemeaning="Hyperplasia"
elif [ "${tissuetype}" = "Premalignant" ]
then
	tissuetypecodevalue="C25624"
	tissuetypecsd="NCIt"
	tissuetypecodemeaning="Premalignant"
else
	# ignore "Not Reported"
	# ignore "Not Otherwise Specified"
	echo 1>&2 "Warning: ignoring unrecognized or unwanted tissuetype ${tissuetype}"
fi

echo "tissuetypecodevalue = ${tissuetypecodevalue}"
echo "tissuetypecsd = ${tissuetypecsd}"
echo "tissuetypecodemeaning = ${tissuetypecodemeaning}"

anatomycodevalue=""
anatomycsd="SCT"
anatomycodemeaning=""

if [ "${siteofbiopsy}" = "Appendix" ]
then
	anatomycodevalue="66754008"
	anatomycodemeaning="Appendix"
elif [ "${siteofbiopsy}" = "Ascending colon" ]
then
	anatomycodevalue="9040008"
	anatomycodemeaning="Ascending colon"
elif [ "${siteofbiopsy}" = "Blood" ]
then
	anatomycodevalue="87612001"
	anatomycodemeaning="Blood"
elif [ "${siteofbiopsy}" = "Body of pancreas" ]
then
	anatomycodevalue="40133006"
	anatomycodemeaning="Body of pancreas"
elif [ "${siteofbiopsy}" = "Bone NOS" ]
then
	anatomycodevalue="272673000"
	anatomycodemeaning="Bone"
elif [ "${siteofbiopsy}" = "Breast NOS" ]
then
	anatomycodevalue="76752008"
	anatomycodemeaning="Breast"
elif [ "${siteofbiopsy}" = "Cecum" ]
then
	anatomycodevalue="32713005"
	anatomycodemeaning="Cecum"
elif [ "${siteofbiopsy}" = "Descending colon" ]
then
	anatomycodevalue="32622004"
	anatomycodemeaning="Descending colon"
elif [ "${siteofbiopsy}" = "Head of pancreas" ]
then
	anatomycodevalue="64163001"
	anatomycodemeaning="Head of pancreas"
elif [ "${siteofbiopsy}" = "Hepatic flexure of colon" ]
then
	anatomycodevalue="48338005"
	anatomycodemeaning="Hepatic flexure of colon"
elif [ "${siteofbiopsy}" = "Liver" ]
then
	anatomycodevalue="10200004"
	anatomycodemeaning="Liver"
elif [ "${siteofbiopsy}" = "Lymph node NOS" ]
then
	anatomycodevalue="59441001"
	anatomycodemeaning="Lymph node"
elif [ "${siteofbiopsy}" = "Lymph nodes of axilla or arm" ]
then
	anatomycodevalue="44914007"
	anatomycodemeaning="Upper limb lymph node"
elif [ "${siteofbiopsy}" = "Rectosigmoid junction" ]
then
	anatomycodevalue="49832006"
	anatomycodemeaning="Rectosigmoid junction"
elif [ "${siteofbiopsy}" = "Rectum NOS" ]
then
	anatomycodevalue="34402009"
	anatomycodemeaning="Rectum"
elif [ "${siteofbiopsy}" = "Sigmoid colon" ]
then
	anatomycodevalue="60184004"
	anatomycodemeaning="Sigmoid colon"
elif [ "${siteofbiopsy}" = "Skin of lower limb and hip" ]
then
	anatomycodevalue="371304004"
	anatomycodemeaning="Skin of lower extremity"
elif [ "${siteofbiopsy}" = "Skin of scalp and neck" ]
then
	anatomycodevalue="400056003"
	anatomycodemeaning="Skin of scalp and/or neck"
elif [ "${siteofbiopsy}" = "Skin of trunk" ]
then
	anatomycodevalue="86381001"
	anatomycodemeaning="Skin of trunk"
elif [ "${siteofbiopsy}" = "Skin of upper limb and shoulder" ]
then
	anatomycodevalue="371311000"
	anatomycodemeaning="Skin of upper extremity"
elif [ "${siteofbiopsy}" = "Splenic flexure of colon" ]
then
	anatomycodevalue="72592005"
	anatomycodemeaning="Splenic flexure of colon"
elif [ "${siteofbiopsy}" = "Tail of pancreas" ]
then
	anatomycodevalue="73239005"
	anatomycodemeaning="Tail of pancreas"
elif [ "${siteofbiopsy}" = "Transverse colon" ]
then
	anatomycodevalue="485005"
	anatomycodemeaning="Transverse colon"
else
	# ignore "Not Reported"
	echo 1>&2 "Warning: ignoring unrecognized or unwanted siteofbiopsy ${siteofbiopsy}"
fi

echo "anatomycodevalue = ${anatomycodevalue}"
echo "anatomycsd = ${anatomycsd}"
echo "anatomycodemeaning = ${anatomycodemeaning}"

# Latest WUSTL IMC images are not float but integer, but claim to be signed when they are not; signed is not supported by WSMI SOP Class
#sampleformatsignedinteger=`tiffinfo "${infile}" | grep 'Sample Format: signed integer' | head -1`
#needtoforceunsignedpixelrepresentation="no"
#if [ ! -z "${sampleformatsignedinteger}" ]
#then
#	echo 1>&2 "Warning: overriding signed integer PixelRepresentation since not allowed and no -ve values are expected to be present"
#	needtoforceunsignedpixelrepresentation="yes"
#fi

echo  >"${TMPJSONFILE}" "{"
echo >>"${TMPJSONFILE}" "	\"options\" : {"
echo >>"${TMPJSONFILE}" "		\"AppendToContributingEquipmentSequence\" : false"
echo >>"${TMPJSONFILE}" "	},"
echo >>"${TMPJSONFILE}" "	\"top\" : {"
#if [ "${needtoforceunsignedpixelrepresentation}" = "yes" ]
#then
#	echo >>"${TMPJSONFILE}" "		\"PixelRepresentation\" : \"0\","
#fi
echo >>"${TMPJSONFILE}" "		\"PatientName\" : \"${dicompatientname}\","
echo >>"${TMPJSONFILE}" "		\"PatientID\" : \"${dicompatientid}\","
if [ ! -z "${dicomsex}" ]
then
	echo >>"${TMPJSONFILE}" "		\"PatientSex\" : \"${dicomsex}\","
fi
if [ ! -z "${dicomethnicgroup}" ]
then
	echo >>"${TMPJSONFILE}" "		\"EthnicGroup\" : \"${dicomethnicgroup}\","
fi
if [ ! -z "${healthstatuscodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "		\"AcquisitionContextSequence\" : ["
	echo >>"${TMPJSONFILE}" "	      {"
	echo >>"${TMPJSONFILE}" "	      	\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "	      	\"ConceptNameCodeSequence\" : { \"cv\" : \"11323-3\", \"csd\" : \"LN\", \"cm\" : \"Health status\" },"
	echo >>"${TMPJSONFILE}" "	      	\"ConceptCodeSequence\" :     { \"cv\" : \"${healthstatuscodevalue}\", \"csd\" : \"${healthstatuscsd}\", \"cm\" : \"${healthstatuscodemeaning}\" }"
	echo >>"${TMPJSONFILE}" "		  }"
	echo >>"${TMPJSONFILE}" "		],"
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
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSponsorName\" : \"${dicomclinicaltrialsponsorname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolID\" : \"${dicomclinicalprotocolid}\","
echo >>"${TMPJSONFILE}" "		\"00130010\" : \"CTP\","
echo >>"${TMPJSONFILE}" "		\"00131010\" : \"${dicomclinicalprotocolid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialProtocolName\" : \"${dicomclinicalprotocolname}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteID\" : \"${dicomclinicaltrialsiteid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSiteName\" : \"${dicomclinicaltrialsitename}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialSubjectID\" : \"${dicomclinicaltrialsubjectid}\","
echo >>"${TMPJSONFILE}" "		\"ClinicalTrialCoordinatingCenterName\" : \"${dicomclinicaltrialcoordinatingcentername}\","
if [ ! -z "${dicomclinicaltrialtimepointid}" ]
then
	echo >>"${TMPJSONFILE}" "		\"ClinicalTrialTimePointID\" : \"${dicomclinicaltrialtimepointid}\","
fi
if [ ! -z "${dicominstitutionname}" ]
then
	echo >>"${TMPJSONFILE}" "		\"InstitutionName\" : \"${dicominstitutionname}\","
fi
if [ ! -z "${dicommanufacturer}" ]
then
	echo >>"${TMPJSONFILE}" "		\"Manufacturer\" : \"${dicommanufacturer}\","
fi
if [ ! -z "${dicommanufacturermodelname}" ]
then
	echo >>"${TMPJSONFILE}" "		\"ManufacturerModelName\" : \"${dicommanufacturermodelname}\","
fi
echo >>"${TMPJSONFILE}" "		\"SeriesDescription\" : \"${htanassaytype}\","
echo >>"${TMPJSONFILE}" "		\"SeriesNumber\" : \"1\","
echo >>"${TMPJSONFILE}" "		\"AccessionNumber\" : \"${dicomaccessionnumber}\","
echo >>"${TMPJSONFILE}" "		\"ContainerIdentifier\" : \"${dicomcontaineridentifier}\","
echo >>"${TMPJSONFILE}" "		\"IssuerOfTheContainerIdentifierSequence\" : [],"
# CP 2143 - use 433466003 Microscope slide (physical object) rather than 258661006 Slide (specimen) (being inactivated) or new 1179252003 Slide submitted as specimen (specimen)
echo >>"${TMPJSONFILE}" "		\"ContainerTypeCodeSequence\" : { \"cv\" : \"433466003\", \"csd\" : \"SCT\", \"cm\" : \"Microscope slide\" },"
echo >>"${TMPJSONFILE}" "		\"SpecimenDescriptionSequence\" : ["
echo >>"${TMPJSONFILE}" "	      {"
echo >>"${TMPJSONFILE}" "		    \"SpecimenIdentifier\" : \"${dicomspecimenidentifier}\","
echo >>"${TMPJSONFILE}" "		    \"IssuerOfTheSpecimenIdentifierSequence\" : [],"
echo >>"${TMPJSONFILE}" "		    \"SpecimenUID\" : \"${dicomspecimenuid}\","
echo >>"${TMPJSONFILE}" "		    \"SpecimenShortDescription\" : \"${htanassaytype}\","
echo >>"${TMPJSONFILE}" "		    \"SpecimenPreparationSequence\" : ["
echo >>"${TMPJSONFILE}" "		      {"
if [ ! -z "${specimencollectioncodevalue}" ]
then
	echo >>"${TMPJSONFILE}" "			    \"SpecimenPreparationStepContentItemSequence\" : ["
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"TEXT\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"121041\", \"csd\" : \"DCM\", \"cm\" : \"Specimen Identifier\" },"
	echo >>"${TMPJSONFILE}" "		    		\"TextValue\" : \"${dicomparentspecimenidentifier}\""
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111701\", \"csd\" : \"DCM\", \"cm\" : \"Processing type\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"17636008\", \"csd\" : \"SCT\", \"cm\" : \"Specimen Collection\" }"
	echo >>"${TMPJSONFILE}" "			      },"
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"17636008\", \"csd\" : \"SCT\", \"cm\" : \"Specimen Collection\" },"
	echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"${specimencollectioncodevalue}\", \"csd\" : \"${specimencollectioncsd}\", \"cm\" : \"${specimencollectioncodemeaning}\" }"
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
# not yet in TID 8001 Specimen Preparation or TID 8002 Specimen Sampling :(
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"434711009\", \"csd\" : \"SCT\", \"cm\" : \"Specimen container\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"433466003\", \"csd\" : \"SCT\", \"cm\" : \"Microscope slide\" }"
echo >>"${TMPJSONFILE}" "			      },"
# not yet in TID 8001 Specimen Preparation or TID 8002 Specimen Sampling :(
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"371439000\", \"csd\" : \"SCT\", \"cm\" : \"Specimen type\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"1179252003\", \"csd\" : \"SCT\", \"cm\" : \"Slide\" }"
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111701\", \"csd\" : \"DCM\", \"cm\" : \"Processing type\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"433465004\", \"csd\" : \"SCT\", \"cm\" : \"Specimen Sampling\" }"
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111704\", \"csd\" : \"DCM\", \"cm\" : \"Sampling Method\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"434472006\", \"csd\" : \"SCT\", \"cm\" : \"Block sectioning\" }"
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"TEXT\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111705\", \"csd\" : \"DCM\", \"cm\" : \"Parent Specimen Identifier\" },"
echo >>"${TMPJSONFILE}" "		    		\"TextValue\" : \"${dicomparentspecimenidentifier}\""
echo >>"${TMPJSONFILE}" "			      },"
echo >>"${TMPJSONFILE}" "			      {"
echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"CODE\","
echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"111707\", \"csd\" : \"DCM\", \"cm\" : \"Parent specimen type\" },"
echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"430861001\", \"csd\" : \"SCT\", \"cm\" : \"Gross specimen\" }"
echo >>"${TMPJSONFILE}" "			      }"
echo >>"${TMPJSONFILE}" "			    ]"
echo >>"${TMPJSONFILE}" "		      }"
if [ "${htanassaytype}" = 'H&E' ]
then
	echo >>"${TMPJSONFILE}" "		      ,"
	echo >>"${TMPJSONFILE}" "		      {"
	echo >>"${TMPJSONFILE}" "			    \"SpecimenPreparationStepContentItemSequence\" : ["
	echo >>"${TMPJSONFILE}" "			      {"
	echo >>"${TMPJSONFILE}" "		    		\"ValueType\" : \"TEXT\","
	echo >>"${TMPJSONFILE}" "					\"ConceptNameCodeSequence\" : { \"cv\" : \"121041\", \"csd\" : \"DCM\", \"cm\" : \"Specimen Identifier\" },"
	echo >>"${TMPJSONFILE}" "		    		\"TextValue\" : \"${dicomparentspecimenidentifier}\""
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
	echo >>"${TMPJSONFILE}" "		    		\"TextValue\" : \"${dicomparentspecimenidentifier}\""
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
#else ... say nothing for CyCIF, IMC, MxIF, mIHC ... immunostaining added during conversion; fixation/embedding omitted :(
fi
echo >>"${TMPJSONFILE}" "			]"
if [ ! -z "${anatomycodevalue}" ]
then
	if [ -z "${tissuetypecodevalue}" ]
	then
		echo >>"${TMPJSONFILE}" "	    ,\"PrimaryAnatomicStructureSequence\" : { \"cv\" : \"${anatomycodevalue}\", \"csd\" : \"${anatomycsd}\", \"cm\" : \"${anatomycodemeaning}\" }"
	else
		echo >>"${TMPJSONFILE}" "	    ,\"PrimaryAnatomicStructureSequence\" : ["
		echo >>"${TMPJSONFILE}" "	      {"
		echo >>"${TMPJSONFILE}" "	   		\"CodeValue\" : \"${anatomycodevalue}\","
		echo >>"${TMPJSONFILE}" "	   		\"CodingSchemeDesignator\" : \"${anatomycsd}\","
		echo >>"${TMPJSONFILE}" "	   		\"CodeMeaning\" : \"${anatomycodemeaning}\","
		echo >>"${TMPJSONFILE}" "	   		\"PrimaryAnatomicStructureModifierSequence\" : { \"cv\" : \"${tissuetypecodevalue}\", \"csd\" : \"${tissuetypecsd}\", \"cm\" : \"${tissuetypecodemeaning}\" }"
		echo >>"${TMPJSONFILE}" "	      }"
		echo >>"${TMPJSONFILE}" "	    ]"
	fi
fi
echo >>"${TMPJSONFILE}" "	      }"
echo >>"${TMPJSONFILE}" "		]"
#OpticalPathIdentifier may get replaced, and ObjectiveLensPower may be added, by TIFFToDicom, but the other values will still be used
echo >>"${TMPJSONFILE}" "		,\"OpticalPathSequence\" : ["
echo >>"${TMPJSONFILE}" "	      {"
echo >>"${TMPJSONFILE}" "		    \"OpticalPathIdentifier\" : \"1\","
if [ ! -z "${nominalmagnification}" ]
then
	echo >>"${TMPJSONFILE}" "		    \"ObjectiveLensPower\" : \"${nominalmagnification}\","
fi
if [ ! -z "${lensna}" ]
then
	echo >>"${TMPJSONFILE}" "		    \"ObjectiveLensNumericalAperture\" : \"${lensna}\","
fi
if [ "${htanassaytype}" = 'H&E' ]
then
	echo >>"${TMPJSONFILE}" "		    \"IlluminationColorCodeSequence\" : { \"cv\" : \"414298005\", \"csd\" : \"SCT\", \"cm\" : \"Full Spectrum\" },"
	echo >>"${TMPJSONFILE}" "		    \"IlluminationTypeCodeSequence\" :  { \"cv\" : \"111744\",  \"csd\" : \"DCM\", \"cm\" : \"Brightfield illumination\" }"
else
	# CyCIF, IMC, MxIF, mIHC
	# do not know what "color" the excitation wavelengths are to use in IlluminationColorCodeSequence - but adding IlluminationTypeCodeSequence will trigger a reqt for either IlluminationColorCodeSequence or IlluminationWaveLength
	# so use generic qualifier value "Narrow" from SCT to indicate that the broad spectrum light has been filtered
	echo >>"${TMPJSONFILE}" "		    \"IlluminationColorCodeSequence\" : { \"cv\" : \"134223000\", \"csd\" : \"SCT\", \"cm\" : \"Narrow\" },"
	echo >>"${TMPJSONFILE}" "		    \"IlluminationTypeCodeSequence\" :  { \"cv\" : \"111743\",  \"csd\" : \"DCM\", \"cm\" : \"Epifluorescence illumination\" }"
fi
echo >>"${TMPJSONFILE}" "	      }"
echo >>"${TMPJSONFILE}" "		]"
echo >>"${TMPJSONFILE}" "	}"
echo >>"${TMPJSONFILE}" "}"

cat "${TMPJSONFILE}"

if [ "${htanassaytype}" = 'H&E' ]
then
	echo 1>&2 "Ignoring any channel metadata information since htanassaytype is "'H&E'
elif [ -f "${channelindexfilename}" ]
then
	# tr in case CSV has DOS rather than Unix line ending
	csvlineforchannel=`grep "${filename}" "${channelindexfilename}" | tr -d '\r' | head -1`
	if [ -z "${csvlineforchannel}" ]
	then
		echo 1>&2 "Warning: cannot find channel metadata CSV file entry for filename ${filename} in ${channelindexfilename}"
	else
		#echo "csvlineforchannel = ${csvlineforchannel}"
		#metadata_synapseID was $6 is now $7
		#was             Imaging_Assay_Type,HTAN_Image_File_ID,image_filename,image_synapseID,metadata_synapse_file_path,metadata_synapseID
		#now HTAN_Center,Imaging_Assay_Type,HTAN_Image_File_ID,image_filename,image_synapseID,metadata_synapse_file_path,metadata_synapseID
		channelmetadataid=`echo "${csvlineforchannel}" | awk -F, '{print $7}'`
		channelmetadatafilepath="${channelmetadatadirectory}/${channelmetadataid}.csv"
		if [ -f "${channelmetadatafilepath}" ]
		then
			echo 1>&2 "Using channel metadata file ${channelmetadatafilepath} for filename ${filename}"
			channelmetadataargs="CHANNELFILE ${channelmetadatafilepath}"
		else
			echo 1>&2 "Warning: cannot find channel metadata file ${channelmetadatafilepath} for filename ${filename}"
		fi
	fi
else
	echo 1>&2 "Warning: have no channel metadata index file for htanassaytype ${htanassaytype}"
fi

echo "tiffinfo for ${infile}"
tiffinfo "${infile}"

# [DO NOT DO THIS ANYMNORE - DISCARDS SUBIFDS - HAVE OUR OWN LZW NOW] need to decompress LZW OME-TIFF files but not JPEG or J2K SVS files ...
# also need to make tiled if stripped, since (a) that's what we want (b) sometimes too large to allocate as one memory array when strips merged
#firstifdcompression=`tiffinfo "${infile}" | grep 'Compression Scheme' | sed -e 's/  Compression Scheme: //' | head -1`
#istiled=`tiffinfo "${infile}" | grep Tile | head -1`
#if [ "${firstifdcompression}" = "LZW" ]
#then
#	rm -f "${tmptiffcpoutputfile}"
#	if [ -z "${istiled}" ]
#	then
#		echo "Tiling while decompressing with tiffcp"
#		tiffcp -8 -c none ${tiffcpoptions} -t -w 1024 -l 1024 "${infile}" "${tmptiffcpoutputfile}"
#	else
#		echo "Decompressing with tiffcp"
#		tiffcp -8 -c none ${tiffcpoptions} "${infile}" "${tmptiffcpoutputfile}"
#	fi
#	infiletouse="${tmptiffcpoutputfile}"
#	echo "tiffinfo for ${infiletouse}"
#	tiffinfo "${infiletouse}"
#else
#	# assume already tiled (or SVS)
#	infiletouse="${infile}"
#fi

# some Vanderbilt H&E are stripped not tiled
# so convert to tiled, since (a) that's what we want (b) sometimes too large to allocate as one memory array when strips merged
istiled=`tiffinfo "${infile}" | grep Tile | head -1`
if [ -z "${istiled}" ]
then
	# if they are not very big (e.g., WUSTL float ROI TIFFs) then don't tile them
	# Image Width: 1241 Image Length: 1033
	imagewidthlengthinfo=`tiffinfo "${infile}" | grep 'Image Width' | head -1`
	needstobetiled="yes"
	if [ ! -z "${imagewidthlengthinfo}" ]
	then
		imagewidth=`echo "${imagewidthlengthinfo}" | sed -e 's/^.*Image Width: \([0-9][0-9]*\).*$/\1/'`
		echo "imagewidth=${imagewidth}"
		imagelength=`echo "${imagewidthlengthinfo}" | sed -e 's/^.*Image Length: \([0-9][0-9]*\).*$/\1/'`
		echo "imagelength=${imagelength}"
		if [ ${imagewidth} -le 2048 -a ${imagelength} -le 2048 ]
		then
			needstobetiled="no"
		fi
	else
		echo 2>&1 "Warning: Could not obtain Image Width and Length to determine need for tiling"
	fi

	if [ "${needstobetiled}" = "no" ]
	then
		echo "Small enough to use without tiling"
		infiletouse="${infile}"
	else
		echo "Tiling with tiffcp"
		rm -f "${tmptiffcpoutputfile}"
		tiffcp -8 -c none ${tiffcpoptions} -t -w 1024 -l 1024 "${infile}" "${tmptiffcpoutputfile}"
		infiletouse="${tmptiffcpoutputfile}"
		echo "tiffinfo for ${infiletouse}"
		tiffinfo "${infiletouse}"
	fi
else
	echo "Already tiled"
	infiletouse="${infile}"
fi

# some Vanderbilt H&E are large and not lossy compressed, so detect and losslessly compress with J2K
transfersyntaxargs=""

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

	pixeldatasizeinbytesrel2gb=`echo "scale=0; ${firstifdbitspersample} / 8 * ${firstifdsamplesperpixel} * ${firstifdimagewidth} * ${firstifdimagelength} / 2147483648" | bc -l`
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

thicknessargs=""
if [ -z "${physicalsizez}" -o -z "${physicalsizezunits}" -o "${physicalsizez}" = "Not Reported" -o "${physicalsizez}" = "Not Applicable" ]
then
	echo 1>&2 "Warning: cannot provide thickness - missing PhysicalSizeZ or its units"
elif [ "${physicalsizezunits}" = "¬µm" -o "${physicalsizezunits}" = "µm" ]
then
	#echo 1>&2 "Using PhysicalSizeZ for thickness"
	physicalsizezmm=`echo "scale=6; ${physicalsizez} / 1000" | bc -l`
	thicknessargs="THICKNESSMM ${physicalsizezmm}"
	echo "Using ${thicknessargs}"
else
	echo 1>&2 "Warning: cannot provide thickness - PhysicalSizeZ units not = ¬µm or µm, is ${physicalsizezunits}"
fi

spacingargs=""
if [ -z "${physicalsizex}" -o -z "${physicalsizexunits}" -o -z "${physicalsizey}" -o -z "${physicalsizeyunits}" -o "${physicalsizex}" = "Not Reported" -o "${physicalsizex}" = "Not Applicable" -o "${physicalsizey}" = "Not Reported" -o "${physicalsizey}" = "Not Applicable" ]
then
	echo 1>&2 "Warning: cannot provide spacing - missing PhysicalSizeX,Y or their units"
elif [ "${physicalsizexunits}" = "¬µm" -a "${physicalsizeyunits}" = "¬µm" ]
then
	if [ "${physicalsizex}" != "${physicalsizey}" ]
	then
		echo 1>&2 "Warning: pixels are non-square - PhysicalSizeX ${physicalsizex} PhysicalSizeY ${physicalsizey}"
	fi
	#echo 1>&2 "Using PhysicalSizeX,Y for spacing"
	physicalsizexmm=`echo "scale=8; ${physicalsizex} / 1000" | bc -l`
	physicalsizeymm=`echo "scale=8; ${physicalsizey} / 1000" | bc -l`
	spacingargs="SPACINGCOLROWMM ${physicalsizexmm} ${physicalsizeymm}"
	echo "Using ${spacingargs}"
elif [ "${physicalsizexunits}" = "µm" -a "${physicalsizeyunits}" = "µm" ]
then
	if [ "${physicalsizex}" = "${physicalsizey}" ]
	then
		physicalsizemm=`echo "scale=8; ${physicalsizex} / 1000" | bc -l`
		spacingargs="SPACINGMM ${physicalsizemm}"
	else
		echo 1>&2 "Warning: pixels are non-square - PhysicalSizeX ${physicalsizex} PhysicalSizeY ${physicalsizey}"
		physicalsizexmm=`echo "scale=8; ${physicalsizex} / 1000" | bc -l`
		physicalsizeymm=`echo "scale=8; ${physicalsizey} / 1000" | bc -l`
		spacingargs="SPACINGROWCOLMM ${physicalsizexmm} ${physicalsizeymm}"
	fi
	#echo 1>&2 "Using PhysicalSizeX,Y for spacing"
	echo "Using ${spacingargs}"
else
	echo 1>&2 "Warning: cannot provide spacing - PhysicalSizeX or Y units not = ¬µm or µm, is ${physicalsizexunits} ${physicalsizeyunits}"
fi

sopclass="1.2.840.10008.5.1.4.1.1.77.1.6"

firstifdisfloat=`tiffinfo "${infile}" | grep 'Sample Format: IEEE floating point' | head -1`
echo "firstifdisfloat=${firstifdisfloat}"

if [ ! -z "${firstifdisfloat}" ]
then
	echo "Using Parametric Image Storage SOP Class since float pixel data"
	sopclass="1.2.840.10008.5.1.4.1.1.30"
fi

rm -rf "${outdir}"
mkdir -p "${outdir}"
date
java -cp ${PIXELMEDDIR}/pixelmed.jar:${PATHTOADDITIONAL}/javax.json-1.0.4.jar:${PATHTOADDITIONAL}/jai_imageio.jar \
	-Djava.awt.headless=true \
	-XX:-UseGCOverheadLimit \
	-Xmx8g \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.TIFFToDicom=debug \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.Immunostaining=debug \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.convert.AddTIFFOrOffsetTables=info \
	-Dorg.slf4j.simpleLogger.log.com.pixelmed.dicom.CompressedFrameEncoder=info \
	com.pixelmed.convert.TIFFToDicom \
	"${TMPJSONFILE}" \
	"${infiletouse}" \
	"${outdir}/DCM" \
	SM "${sopclass}" \
	${transfersyntaxargs} \
	ADDTIFF ALWAYSWSI MERGESTRIPS DONOTADDDCMSUFFIX INCLUDEFILENAME DONOTINCLUDEIMAGEDESCRIPTION \
	${spacingargs} \
	${thicknessargs} \
	${channelmetadataargs} \
	#ADDPYRAMID DONOTMERGESTRIPS DONOTUSEBIGTIFF
date
rm "${TMPJSONFILE}"
rm -f "${tmptiffcpoutputfile}"

ls -l "${outdir}"

for i in ${outdir}/DCM*
do
	dccidump -filename "$i"
done

for i in ${outdir}/*
do
	dciodvfy -new -filename "$i" 2>&1 | egrep -v '(Retired Person Name form|SliceThickness.0018,0050..1.> - Value is zero|ImagedVolumeDepth.0048,0003..1.> - Value is zero)'
done

#for i in ${outdir}/*
#do
#	dcfile -filename "$i"
#done

# Not -decimal (which is nice for rows, cols) because fails to display FL and FD values at all ([bugs.dicom3tools] (000554)) :(
(cd "${outdir}"; dctable -describe -recurse -k TransferSyntaxUID -k FrameOfReferenceUID -k LossyImageCompression -k LossyImageCompressionMethod -k LossyImageCompressionRatio -k InstanceNumber -k ImageType -k FrameType -k PhotometricInterpretation -k NumberOfFrames -k Rows -k Columns -k ImagedVolumeWidth -k ImagedVolumeHeight -k ImagedVolumeDepth -k ImageOrientationSlide -k XOffsetInSlideCoordinateSystem -k YOffsetInSlideCoordinateSystem -k PixelSpacing -k SliceThickness -k ObjectiveLensPower -k PrimaryAnatomicStructureSequence -k PrimaryAnatomicStructureModifierSequence -k ClinicalTrialProtocolID -k OpticalPathIdentifier -k OpticalPathDescription DCM*)

echo "dcentvfy ..."
dcentvfy ${outdir}/*

#will not add pyramid files (yet) if created since name not DCM*
(cd "${outdir}"; \
	java -cp ${PIXELMEDDIR}/pixelmed.jar -Djava.awt.headless=true com.pixelmed.dicom.DicomDirectory DICOMDIR DCM*; \
	dciodvfy -new DICOMDIR 2>&1 | egrep -v '(Retired Person Name form|Attribute is not present in standard DICOM IOD|Dicom dataset contains attributes not present in standard DICOM IOD)'; \
	#dcdirdmp -v DICOMDIR \
)
