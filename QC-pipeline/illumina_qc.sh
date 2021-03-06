#!/bin/sh -e
#
# QC pipeline script for Illumina data
#
# Usage: illumina_qc.sh <fastq>
#
function usage() {
    echo "Usage: illumina_qc.sh <fastq>"
    echo ""
    echo "Run QC pipeline for Illumina data:"
    echo ""
    echo "* check for contamination using fastq_screen"
    echo "* generate QC metrics using FASTQC"
    echo ""
    echo "<fastq> can be either fastq or fastq.gz file"
}
function import_functions() {
    if [ -z "$1" ] ; then
	echo ERROR no filename supplied to import_functions >2
    else
	if [ -f $1 ] ; then
	    # Import local copy
	    echo Sourcing `pwd`/$1
	    . $1
	else
	    # Import version in share
	    echo Sourcing `dirname $0`/../share/$1
	    . `dirname $0`/../share/$1
	fi
    fi
}
#
#===========================================================================
# Import function libraries
#===========================================================================
#
# General shell functions
import_functions functions.sh
#
# NGS-specific functions
import_functions ngs_utils.sh
#
# Program version functions
import_functions versions.sh
#
#===========================================================================
# Main script
#===========================================================================
#
# Check command line
if [ $# -ne 1 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
    usage
    exit
fi
#
# Set umask to allow group read-write on all new files etc
umask 0002
#
# Get the input fastq file
FASTQ=$(abs_path $1)
if [ ! -f "$FASTQ" ] ; then
    echo "fastq file not found"
    exit 1
fi
#
# Get the data directory i.e. location of the input file
datadir=`dirname $FASTQ`
#
# Report
echo ========================================================
echo ILLUMINA QC pipeline
echo ========================================================
echo Started   : `date`
echo Running in: `pwd`
echo data dir  : $datadir
echo fastq     : `basename $FASTQ`
echo hostname  : $HOSTNAME
echo job id    : $JOB_ID
#
# Set up environment
QC_SETUP=`dirname $0`/qc.setup
if [ -f "${QC_SETUP}" ] ; then
    echo Sourcing qc.setup to set up environment
    . ${QC_SETUP}
else
    echo WARNING qc.setup not found in `dirname $0`
fi
#
# Working directory
WORKING_DIR=`pwd`
#
# Set the programs
# Override these defaults by setting them in qc.setup
: ${FASTQ_SCREEN:=fastq_screen}
: ${FASTQ_SCREEN_CONF_DIR:=}
: ${FASTQC:=fastqc}
#
# Base name for script
qc=$(baserootname $0)
#
# Base name for fastq files etc
fastq_base=`basename ${FASTQ%%.fastq*}`
#
# Create 'qc' subdirectory
if [ ! -d "qc" ] ; then
    mkdir qc
fi
#
#############################################
# Report program paths and versions
#############################################
#
program_info=qc/$fastq_base.$qc.programs
echo "# Program versions and paths used for $fastq_base:" > $program_info
report_program_info $FASTQ_SCREEN >> $program_info
report_program_info $FASTQC >> $program_info
#
# Echo to log
echo "--------------------------------------------------------"
cat $program_info
echo "--------------------------------------------------------"
#
#############################################
# FASTQ MANIPULATIONS
#############################################
#
# Unpack gzipped fastq file
ext=$(getextension $FASTQ)
if [ "$ext" == "gz" ] ; then
    uncompressed_fastq=$(baserootname $FASTQ)
    if [ ! -f $uncompressed_fastq ] ; then
	echo Input FASTQ is gzipped, making ungzipped version
	gzip -dc $FASTQ > $uncompressed_fastq.part
	mv $uncompressed_fastq.part $uncompressed_fastq
    else
	echo Ungzipped version of input FASTQ found
    fi
fi
#
#############################################
# QC
#############################################
#
# Run fastq_screen
run_fastq_screen $FASTQ
#
# Run FASTQC
if [ ! -d qc/${fastq_base}_fastqc ] || [ ! -f qc/${fastq_base}_fastqc.zip ] ; then
    echo "Running FastQC command: ${FASTQC} --nogroup"
    echo ${FASTQC} version $(get_version $FASTQC)
    ${FASTQC} --outdir qc --nogroup $FASTQ
else
    echo "FastQC output already exists: qc/${fastq_base}_fastqc(.zip)"
fi
#
# Update permissions and group (if specified)
set_permissions_and_group "$SET_PERMISSIONS" "$SET_GROUP"
#
echo ILLUMINA QC pipeline completed: `date`
exit
##
#
