#!/bin/bash -x
set -x -e

# ------------------------------------------------
# HARP-ICV ASHS pipeline 
# Version 02.09.2018
# PICSL - Virginie Piskin
# ------------------------------------------------
echo "MY HOSTNAME is $(hostname)"

#PATH=/home/xnat/vpiskin/test_pipeline/bin:$PATH
PATH=/data/XNAT/pipeline/catalog/AshsHarpIcv/bin:$PATH

# Print usage by default
if [[ $# -lt 1 || $1 == "h" || $1 == "-help" || $1 == "--help" ]] ; then
  cat << USAGETEXT

	run_pipeline.sh: Script to run the whole pipline. It sends a ticket for the
                         HARP-ICV segmentation service and generates a pdf report 
    	                 out of the results.
    	usage: 
      		run_pipeline.sh [options]
   	options:
		-p  <str>         : Project's name
		-s  <str>         : MR session ID number
      		-n  <str>         : Scan ID number
		-a  <years>       : Patient's age

USAGETEXT
  exit 0
fi 

# Read the options
while getopts "p:s:n:a:" opt; do
    #echo "getopts found option $opt"
	case $opt in
	
        	p)
			project=$OPTARG
			echo "$project"
			;;
		s)
			session_id=$OPTARG
			echo "$session_id"
        		;;
		n)
			scan_id=$OPTARG
			echo "$scan_id"
			;;
		a)
			age=$OPTARG
			echo "$age"
			;;

		\?) echo "Unknown option $OPTARG"; exit 2;;

		:) echo "Option $OPTARG requires an argument"; exit 2;;
	esac
done

# Convert the DICOM image series in a NIFTI image
SOURCEDIR=/data/XNAT/archive/$project/arc001/$session_id/SCANS/$scan_id
full_id=${session_id}_${scan_id}
TMPDIR=/data/XNAT/pipeline/catalog/AshsHarpIcv/work/$project/$full_id
native_image=${full_id}_native_mri.nii.gz
input_image=${full_id}_mri.nii.gz
if [ ! -d $TMPDIR ] ; then mkdir -p $TMPDIR ; fi

series_id=$(c3d -dicom-series-list $SOURCEDIR/DICOM | grep 2 | awk '{ print $NF }')
c3d -dicom-series-read $SOURCEDIR/DICOM $series_id -o $TMPDIR/$native_image

trim_script=/data/XNAT/pipeline/catalog/AshsHarpIcv/scripts/trim_neck.sh
MASKDIR=$TMPDIR/mask
INTERDIR=$TMPDIR/inter
if [ ! -d $MASKDIR ] ; then mkdir -p $MASKDIR ; fi  
if [ ! -d $INTERDIR ] ; then mkdir -p $INTERDIR ; fi
$trim_script -m $MASKDIR -w $INTERDIR $TMPDIR/$native_image $TMPDIR/$input_image

# Create input workspace
input_workspace=${full_id}_input.itksnap
itksnap-wt -laa $TMPDIR/$input_image -ta T1 -psn "MRI" -ll -o $TMPDIR/$input_workspace

# Create ticket with the HARP-ICV service number
service=ASHS-HarP
ticket_create_out=$TMPDIR/${full_id}_ticket_info.txt

if [ -f $ticket_create_out ] ; then rm $ticket_create_out ; fi
touch $ticket_create_out
chmod 755 $ticket_create_out

itksnap-wt -i $TMPDIR/$input_workspace -dss-tickets-create $service > $ticket_create_out
ticket_number=$(cat $ticket_create_out | grep "^2> " | awk '{print $2}')
ticket_code=$(printf %08d $ticket_number)

# Check the processing of the ticket
sleep 30s
itksnap-wt -dss-tickets-wait $ticket_number 7200
sleep 30s

# Rename result files
itksnap-wt -dss-tickets-download $ticket_number $TMPDIR 
ticket_workspace=$TMPDIR/ticket_${ticket_code}_results.itksnap
xnat_workspace=$TMPDIR/${full_id}_results.itksnap

mri_layer=$(itksnap-wt -i $ticket_workspace -ll | grep MRI | awk '{print $2}')
icv_layer=$(itksnap-wt -i $ticket_workspace -ll | grep ICV | awk '{print $2}')
harp_layer=$(itksnap-wt -i $ticket_workspace -ll | grep HARP | awk '{print $2}')

itksnap-wt -i $ticket_workspace \
	        -layers-pick $mri_layer -props-rename-file $TMPDIR/${full_id}_mri.nii.gz \
                -layers-pick $icv_layer -props-rename-file $TMPDIR/${full_id}_icv.nii.gz \
	        -layers-pick $harp_layer -props-rename-file $TMPDIR/${full_id}_harp.nii.gz \
		-o $xnat_workspace

# Make the pdf report
REPORTDIR=/data/XNAT/pipeline/catalog/AshsHarpIcv/report/

# Use C3D to generate the volumes
$REPORTDIR/make_report.sh -s $session_id \
			  -n $scan_id \
			  -a $age \
			  -t $ticket_code \
			  -w $TMPDIR 
