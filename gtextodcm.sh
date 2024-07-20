#!/bin/sh
#
# Usage: ./gtextodcm.sh folder/filename.svs [outdir]

# #### DEPENDS ON csvtool installed (pip3 install csvtool) and in path (e.g., "~/Library/Python/3.9/bin")

infile="$1"
outdir="$2"

#JAVATMPDIRARG="-Djava.io.tmpdir=/Volumes/Elements5TBNonEncD/tmp"

TMPJSONFILE="/tmp/`basename $0`.$$"

# from "https://www.gtexportal.org/home/histologyPage"
#CSVFILENAMEFORMETADATA="GTExPathologyImages_GTExPortal.csv"
# emailed from investigators ...
CSVFILENAMEFORMETADATA="GTEX_image_meta.final_plus_7_slides.csv"
if [ ! -f "${CSVFILENAMEFORMETADATA}" ]
then
	echo 1>&2 "Error: no metadata CSV file called ${CSVFILENAMEFORMETADATA}"
	exit 1
fi

# these persist across invocations ...
FILEMAPPINGSPECIMENIDTOUID="GTEXspecimenIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTOUID="GTEXstudyIDToUIDMap.csv"
FILEMAPPINGSTUDYIDTODATETIME="GTEXstudyIDToDateTimeMap.csv"

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
dicomclinicaltrialsponsorname="National Institutes of Health"
issuerofdicomclinicalprotocolid="NIH"
dicomclinicalprotocolname="Adult Genotype-Tissue Expression (GTEx)"
dicomclinicalprotocolid="GTEx"

# see "http://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/study.cgi?study_id=phs000424"
#issuerofdicomclinicalprotocolid="dbGaP"
#dicomclinicalprotocolid="phs000424"
#dicomclinicalprotocolname="Common Fund (CF) Genotype-Tissue Expression Project (GTEx)"

dicomclinicaltrialsiteid=""
# use IDC-specific Zenodo DOI
doiclinicalprotocolid="doi:10.5281/zenodo.11099100"

# "source-data-gtex/AdiposeTissue/GTEX-N7MS-0325.svs"

# do not remove suffix '.svs' from filename since need to match what is in CSVFILENAMEFORIMAGING
filename=`basename "${infile}"`
foldername=`dirname "${infile}"`

slide_id=`echo ${filename} | sed -e 's/^\([A-Z0-9-]*\).*$/\1/'`
# slide_id = GTEX-N7MS-0325

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

tissue_fixative=""
tissue_fixative_forshortdescription=""
embedding_medium=""
embedding_medium_forshortdescription=""

if [ -f "${CSVFILENAMEFORMETADATA}" ]
then
	# from GTExPathologyImages_GTExPortal.csv
	# Tissue Sample ID,Tissue,Subject ID,Sex,Age Bracket,Hardy Scale,Pathology Categories,Pathology Notes
	# GTEX-1117F-0126,Skin - Sun Exposed (Lower leg),GTEX-1117F,female,60-69,Slow death,,"6 pieces, minimal fat, squamous epithelium is ~50-70 microns"
	
	# from GTEX_image_meta.final.csv
	# Case ID,Age,Gender,Specimen ID,Tissue Type,Fixative,Autolysis,Pathology Review Comments,Acceptability
	# GTEX-1117F,61-70,Female,GTEX-1117F-0126,"Skin, leg",PAXgene,0,"6 pieces, minimal fat, squamous epithelium is ~50-70 microns",Acceptable

	#csvlineformetadata=`egrep "^${sample_id}," "${CSVFILENAMEFORMETADATA}" | head -1 | sed 's/\r$//'`
	csvlineformetadata=`egrep ",${sample_id}," "${CSVFILENAMEFORMETADATA}" | head -1 | sed 's/\r$//'`
	echo "csvlineformetadata = ${csvlineformetadata}"
fi

if [ -z "${csvlineformetadata}" ]
then
	#echo 1>&2 "Warning: cannot find metadata CSV file entry for sample_id ${sample_id}"
	# Per the README file:
	# 
	# "Also, the sample data in the GTEx portal may be identified like so:
	# GTEX-1RAZQ-1326
	# --------------^
	# While we have
	# GTEX-1RAZQ-1325
	# --------------^
	# 
	# Those are identical aliquots of the same tissue from the same individual taken at the same time and sent to two different places.
	# One for imaging (after paraffin embedding) and one for molecular analysis. For all intents and purposes, they can be treated as identical."
	
	sibling_sample_id=`echo "${sample_id}" | sed -e 's/5$/6/'`
	if [ "${sibling_sample_id}" = "${sample_id}" ]
	then
		# try the other direction ...
		sibling_sample_id=`echo "${sample_id}" | sed -e 's/6$/5/'`
	fi
	csvlineformetadata=`egrep ",${sibling_sample_id}," "${CSVFILENAMEFORMETADATA}" | head -1 | sed 's/\r$//'`
	echo "csvlineformetadata from sibling_sample_id = ${csvlineformetadata}"
	if [ -z "${csvlineformetadata}" ]
	then
		echo 1>&2 "Warning: cannot find metadata CSV file entry for sibling_sample_id ${sibling_sample_id}"
		#slide_id = GTEX-1117F-0126
		#subject_id = GTEX-1117F
		tissue=`basename "${foldername}"`
		subject_id=`echo "${slide_id}" | sed -e 's/^\(GTEX-[0-9A-Z]*\)-[0-9-]*$/\1/'`
		# even though the slide may not be in the metadata, the subject may be, so extract what we can that is not specimen-specific ...
		csvlineforsubject=`egrep "^${subject_id}," "${CSVFILENAMEFORMETADATA}" | head -1 | sed 's/\r$//'`
		if [ -z "${csvlineforsubject}" ]
		then
			echo 1>&2 "Warning: cannot find metadata CSV file entry for subject_id ${subject_id}"
		else
			gender=`echo "${csvlineforsubject}" | csvtool -c 3 | tr -d '"'`
			agebracket=`echo "${csvlineforsubject}" | csvtool -c 2 | tr -d '"'`
		fi
	fi
fi
if [ ! -z "${csvlineformetadata}" ]
then
	# from GTExPathologyImages_GTExPortal.csv
	#tissue=`echo "${csvlineformetadata}" | csvtool -c 2 | tr -d '"'`
	#subject_id=`echo "${csvlineformetadata}" | csvtool -c 3 | tr -d '"'`
	#gender=`echo "${csvlineformetadata}" | csvtool -c 4 | tr -d '"'`
	#agebracket=`echo "${csvlineformetadata}" | csvtool -c 5 | tr -d '"'`
	#pathologynotes=`echo "${csvlineformetadata}" | csvtool -c 8 | tr -d '"'`
	
	# from GTEX_image_meta.final.csv
	# Case ID,Age,Gender,Specimen ID,Tissue Type,Fixative,Autolysis,Pathology Review Comments,Acceptability
	tissue=`echo "${csvlineformetadata}" | csvtool -c 5 | tr -d '"'`
	subject_id=`echo "${csvlineformetadata}" | csvtool -c 1 | tr -d '"'`
	gender=`echo "${csvlineformetadata}" | csvtool -c 3 | tr -d '"'`
	agebracket=`echo "${csvlineformetadata}" | csvtool -c 2 | tr -d '"'`
	pathologynotes=`echo "${csvlineformetadata}" | csvtool -c 8 | tr -d '"'`
	
	tissue_fixative=`echo "${csvlineformetadata}" | csvtool -c 6 | tr -d '"'`
	if [ "${tissue_fixative}" = "PAXgene" ]
	then
		tissue_fixative_forshortdescription="PG"
		embedding_medium="Paraffin"
		embedding_medium_forshortdescription="PE"
	elif [ "${tissue_fixative}" = "Dry Ice" ]
	then
		tissue_fixative_forshortdescription="FZ"
	fi
fi

echo "subject_id = ${subject_id}"

dicomclinicaltrialsubjectid="${subject_id}"
echo "dicomclinicaltrialsubjectid = ${dicomclinicaltrialsubjectid}"

echo "tissue = ${tissue}"
echo "gender = ${gender}"
echo "agebracket = $agebracket"
echo "pathologynotes = ${pathologynotes}"

echo "outdir = ${outdir}"

dicompatientid="${subject_id}"
dicompatientname="${dicompatientid}"

dicomspecimenidentifier="${specimen_id}"

dicomstudyid="${subject_id}"
dicomaccessionnumber="${subject_id}"

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
if [ ! -z "${agebracket}" ]
then
	agelower=`echo "${agebracket}" | sed -e 's/^\([0-9]*\)-[0-9]*$/\1/'`
	if [ "${agebracket}" != "${agelower}" ]
	then
		age=`expr $agelower + 5`
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
	fi
fi
echo "dicomage = ${dicomage}"

dicomethnicgroup=""
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

echo "tissue = ${tissue}"
if [ ! -z "${tissue}" ]
then
	tissue=`echo "${tissue}" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z]/ /g' | sed -e 's/[ ][ ]*/ /g' | sed -e 's/^[ ][ ]*//g' | sed -e 's/[ ][ ]*$//g'`
	echo "normalized tissue = \"${tissue}\""
	if [ "${tissue}" = "adipose subcutaneous" ]
	then
		anatomycodevalue="67769002"
		anatomycsd="SCT"
		anatomycodemeaning="Subcutaneous adipose tissue"
	elif [ "${tissue}" = "adipose tissue" -o "${tissue}" = "adiposetissue" ]
	then
		anatomycodevalue="55603005"
		anatomycsd="SCT"
		anatomycodemeaning="Adipose tissue"
	elif [ "${tissue}" = "adipose visceral omentum" ]
	then
		anatomycodevalue="725273006"
		anatomycsd="SCT"
		anatomycodemeaning="Adipose tissue of abdomen"
	elif [ "${tissue}" = "adrenal gland" -o "${tissue}" = "adrenal glands" -o "${tissue}" = "adrenalglands" ]
	then
		anatomycodevalue="23451007"
		anatomycsd="SCT"
		anatomycodemeaning="Adrenal gland"
	elif [ "${tissue}" = "artery aorta" -o "${tissue}" = "aorta" ]
	then
		anatomycodevalue="15825003"
		anatomycsd="SCT"
		anatomycodemeaning="Aorta"
	elif [ "${tissue}" = "artery coronary" -o "${tissue}" = "coronary artery" -o "${tissue}" = "coronaryartery" ]
	then
		anatomycodevalue="41801008"
		anatomycsd="SCT"
		anatomycodemeaning="Coronary artery"
	elif [ "${tissue}" = "artery tibial" -o "${tissue}" = "tibial artery" -o "${tissue}" = "tibialartery" ]
	then
		anatomycodevalue="181351007"
		anatomycsd="SCT"
		anatomycodemeaning="Tibial artery"
	elif [ "${tissue}" = "bladder" -o "${tissue}" = "urinary bladder" -o "${tissue}" = "urinarybladder" ]
	then
		anatomycodevalue="89837001"
		anatomycsd="SCT"
		anatomycodemeaning="Urinary bladder"
	elif [ "${tissue}" = "brain cerebellum" -o "${tissue}" = "braincerebellum" ]
	then
		anatomycodevalue="113305005"
		anatomycsd="SCT"
		anatomycodemeaning="Cerebellum"
	elif [ "${tissue}" = "brain cortex" -o "${tissue}" = "braincortex" ]
	then
		anatomycodevalue="40146001"
		anatomycsd="SCT"
		anatomycodemeaning="Cerebral cortex"
	elif [ "${tissue}" = "breast mammary tissue" -o "${tissue}" = "mammary tissue breast" -o "${tissue}" = "mammarytissuebreast" ]
	then
		anatomycodevalue="76752008"
		anatomycsd="SCT"
		anatomycodemeaning="Breast"
	elif [ "${tissue}" = "cervix ectocervix" -o "${tissue}" = "ectocervix" ]
	then
		anatomycodevalue="28349006"
		anatomycsd="SCT"
		anatomycodemeaning="Exocervix"
	elif [ "${tissue}" = "cervix endocervix" -o "${tissue}" = "endocervix" ]
	then
		anatomycodevalue="36973007"
		anatomycsd="SCT"
		anatomycodemeaning="Endocervix"
	elif [ "${tissue}" = "colon sigmoid" -o "${tissue}" = "sigmoid colon" -o  "${tissue}" = "sigmoidcolon" ]
	then
		anatomycodevalue="60184004"
		anatomycsd="SCT"
		anatomycodemeaning="Sigmoid colon"
	elif [ "${tissue}" = "colon" ]
	then
		anatomycodevalue="71854001"
		anatomycsd="SCT"
		anatomycodemeaning="Colon"
	elif [ "${tissue}" = "colon transverse" ]
	then
		anatomycodevalue="485005"
		anatomycsd="SCT"
		anatomycodemeaning="Transverse colon"
	elif [ "${tissue}" = "esophagus gastroesophageal junction" -o "${tissue}" = "gastroesophageal junction" -o "${tissue}" = "gastroesophagealjunction" ]
	then
		anatomycodevalue="25271004"
		anatomycsd="SCT"
		anatomycodemeaning="Gastroesophageal junction"
	elif [ "${tissue}" = "esophagus mucosa" -o "${tissue}" = "esophagusmucosa" ]
	then
		anatomycodevalue="82082004"
		anatomycsd="SCT"
		anatomycodemeaning="Esophageal mucous membrane"
	elif [ "${tissue}" = "esophagus muscularis" -o "${tissue}" = "esophagusmuscularis" ]
	then
		anatomycodevalue="360961009"
		anatomycsd="SCT"
		anatomycodemeaning="Esophageal muscle"
	elif [ "${tissue}" = "fallopian tube" -o "${tissue}" = "fallopiantube" ]
	then
		anatomycodevalue="31435000"
		anatomycsd="SCT"
		anatomycodemeaning="Fallopian tube"
	elif [ "${tissue}" = "heart" ]
	then
		anatomycodevalue="80891009"
		anatomycsd="SCT"
		anatomycodemeaning="Heart"
	elif [ "${tissue}" = "heart atrial appendage" -o "${tissue}" = "atrial appendage" -o "${tissue}" = "atrialappendage" ]
	then
		anatomycodevalue="68786006"
		anatomycsd="SCT"
		anatomycodemeaning="Auricular appendage"
	elif [ "${tissue}" = "heart left ventricle" ]
	then
		anatomycodevalue="87878005"
		anatomycsd="SCT"
		anatomycodemeaning="Left ventricle"
	elif [ "${tissue}" = "ileum" ]
	then
		anatomycodevalue="34516001"
		anatomycsd="SCT"
		anatomycodemeaning="Ileum"
	elif [ "${tissue}" = "kidney cortex" -o "${tissue}" = "kidneycortex" ]
	then
		anatomycodevalue="50403003"
		anatomycsd="SCT"
		anatomycodemeaning="Renal cortex"
	elif [ "${tissue}" = "kidney medulla" -o "${tissue}" = "kidneymedulla" ]
	then
		anatomycodevalue="30737000"
		anatomycsd="SCT"
		anatomycodemeaning="Renal medulla"
	elif [ "${tissue}" = "liver" ]
	then
		anatomycodevalue="10200004"
		anatomycsd="SCT"
		anatomycodemeaning="Liver"
	elif [ "${tissue}" = "lung" ]
	then
		anatomycodevalue="39607008"
		anatomycsd="SCT"
		anatomycodemeaning="Lung"
	elif [ "${tissue}" = "minor salivary gland" -o "${tissue}" = "minor salivary glands" -o "${tissue}" = "minorsalivarygland" -o "${tissue}" = "minorsalivaryglands" ]
	then
		anatomycodevalue="87626005"
		anatomycsd="SCT"
		anatomycodemeaning="Minor salivary gland"
	elif [ "${tissue}" = "muscle skeletal" -o "${tissue}" = "skeletal muscle" -o "${tissue}" = "skeletalmuscle" ]
	then
		anatomycodevalue="127954009"
		anatomycsd="SCT"
		anatomycodemeaning="Skeletal muscle"
	elif [ "${tissue}" = "nerve tibial" -o "${tissue}" = "tibial nerve" -o "${tissue}" = "tibialnerve" ]
	then
		anatomycodevalue="45684006"
		anatomycsd="SCT"
		anatomycodemeaning="Tibial nerve"
	elif [ "${tissue}" = "omentum" ]
	then
		anatomycodevalue="27398004"
		anatomycsd="SCT"
		anatomycodemeaning="Omentum"
	elif [ "${tissue}" = "ovary" ]
	then
		anatomycodevalue="15497006"
		anatomycsd="SCT"
		anatomycodemeaning="Ovary"
	elif [ "${tissue}" = "pancreas" ]
	then
		anatomycodevalue="15776009"
		anatomycsd="SCT"
		anatomycodemeaning="Pancreas"
	elif [ "${tissue}" = "pituitary" -o "${tissue}" = "pituitary gland" -o "${tissue}" = "pituitarygland" ]
	then
		anatomycodevalue="56329008"
		anatomycsd="SCT"
		anatomycodemeaning="Pituitary"
	elif [ "${tissue}" = "prostate" ]
	then
		anatomycodevalue="41216001"
		anatomycsd="SCT"
		anatomycodemeaning="Prostate"
	elif [ "${tissue}" = "skin" ]
	then
		anatomycodevalue="39937001"
		anatomycsd="SCT"
		anatomycodemeaning="Skin"
	elif [ "${tissue}" = "skin not sun exposed suprapubic"  -o "${tissue}" = "skin suprapubic"  -o "${tissue}" = "suprapubic skin" -o "${tissue}" = "suprapubicskin" ]
	then
		anatomycodevalue="367578008"
		anatomycsd="SCT"
		anatomycodemeaning="Skin of suprapubic region"
	elif [ "${tissue}" = "skin sun exposed lower leg" -o "${tissue}" = "skin leg" ]
	then
		anatomycodevalue="75144006"
		anatomycsd="SCT"
		anatomycodemeaning="Skin of lower leg"
	elif [ "${tissue}" = "small intestine terminal ileum" ]
	then
		anatomycodevalue="85774003"
		anatomycsd="SCT"
		anatomycodemeaning="Terminal ileum"
	elif [ "${tissue}" = "spleen" ]
	then
		anatomycodevalue="78961009"
		anatomycsd="SCT"
		anatomycodemeaning="Spleen"
	elif [ "${tissue}" = "stomach" ]
	then
		anatomycodevalue="69695003"
		anatomycsd="SCT"
		anatomycodemeaning="Stomach"
	elif [ "${tissue}" = "testis" ]
	then
		anatomycodevalue="40689003"
		anatomycsd="SCT"
		anatomycodemeaning="Testis"
	elif [ "${tissue}" = "thyroid" -o "${tissue}" = "thyroid gland" -o "${tissue}" = "thyroidgland" ]
	then
		anatomycodevalue="69748006"
		anatomycsd="SCT"
		anatomycodemeaning="Thyroid"
	elif [ "${tissue}" = "uterus" ]
	then
		anatomycodevalue="35039007"
		anatomycsd="SCT"
		anatomycodemeaning="Uterus"
	elif [ "${tissue}" = "vagina" ]
	then
		anatomycodevalue="76784001"
		anatomycsd="SCT"
		anatomycodemeaning="Vagina"
	else
		echo 1>&2 "Warning: unrecognized tissue \"${tissue}\" for sample_id ${sample_id}"
	fi
fi

echo "anatomycodemeaning = ${anatomycodemeaning}"
echo "lateralitycodemeaning = ${lateralitycodemeaning}"
echo "anatomymodifiercodemeaning = ${anatomymodifiercodemeaning}"

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

staining_method="Hematoxylin and Eosin"
staining_method_forshortdescription="HE"

dicomspecimenshortdescription="${tissue_fixative_forshortdescription} ${embedding_medium_forshortdescription} ${staining_method_forshortdescription}"
echo "dicomspecimenshortdescription = ${dicomspecimenshortdescription}"

dicomspecimendetaileddescription="${tissue_fixative} ${embedding_medium} ${staining_method}; ${pathologynotes}"
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
	echo >>"${TMPJSONFILE}" "			\"SpecimenShortDescription\" : \"${dicomspecimenshortdescription}\","
fi
if [ ! -z "${dicomspecimendetaileddescription}" ]
then
	echo >>"${TMPJSONFILE}" "			\"SpecimenDetailedDescription\" : \"${dicomspecimendetaileddescription}\","
fi
echo >>"${TMPJSONFILE}" "		    \"SpecimenPreparationSequence\" : ["
if [ "${tissue_fixative}" = "Formalin" -o "${tissue_fixative}" = "PAXgene" -o "${tissue_fixative}" = "Dry Ice" ]
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
	elif [ "${tissue_fixative}" = "PAXgene" ]
	then
		echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"C185113\", \"csd\" : \"NCIt\", \"cm\" : \"PAXgene Tissue System\" }"
	elif [ "${tissue_fixative}" = "Dry Ice" ]
	then
		echo >>"${TMPJSONFILE}" "					\"ConceptCodeSequence\" :     { \"cv\" : \"433469005\", \"csd\" : \"SCT\", \"cm\" : \"Tissue freezing medium\" }"
	fi
	echo >>"${TMPJSONFILE}" "			      }"
	echo >>"${TMPJSONFILE}" "			    ]"
	echo >>"${TMPJSONFILE}" "		      }"
elif [ ! -z "${tissue_fixative}" ]
then
	echo 1>&2 "Warning: ignoring unrecognized tissue_fixative ${tissue_fixative}"
fi
if [ "${embedding_medium}" = "Paraffin" ]
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
if [ "${staining_method}" = "Hematoxylin and Eosin" ]
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
	if [ "${staining_method}" = "Hematoxylin and Eosin" ]
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
