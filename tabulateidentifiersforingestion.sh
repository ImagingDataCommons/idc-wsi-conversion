#!/bin/sh
#
# Usage: ./tabulateidentifiersforingestion.sh 2>&1 >identifiers.txt
#

dctable -k ClinicalTrialProtocolID -k PatientID -k StudyInstanceUID -k SeriesInstanceUID -k SOPInstanceUID -describe
find "$1" -follow -name 'DCM_*' -exec dctable -k ClinicalTrialProtocolID -k PatientID -k StudyInstanceUID -k SeriesInstanceUID -k SOPInstanceUID '{}' ';'
