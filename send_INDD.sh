#!/bin/bash -x

# ------------------------------------------------
# HARP-ICV ASHS pipeline
# Version 02.09.2018
# PICSL - Virginie Piskin
# ------------------------------------------------

# Usage by default
if [[ $# -lt 1 || $1 == "h" || $1 == "-help" || $1 == "--help" ]] ; then
  cat << USAGETEXT

        send_INDD.sh: Script to send the result of the pipeline to the INDD
		      server. It logs in the X2Go server to be able to use
		      the SMB2 protocol with the smbclient command.
        usage:
                send_INDD.sh [options] 
	options:
                -f  <str>  : Path of the file to be sent to the INDD server
		-s  <str>  : MR session ID number

USAGETEXT
  exit 0
fi

# Read the options
while getopts "f:s:" opt; do
    #echo "getopts found option $opt"
        case $opt in

                f)
                        file=$OPTARG
			echo "file"
                        ;;
		s) 
			session_id=$OPTARG
			echo "file"
			;;

                \?) echo "Unknown option $OPTARG"; exit 2;;

                :) echo "Option $OPTARG requires an argument"; exit 2;;
        esac
done

X2Go=xnat@170.212.169.217
auth=auth.txt
target=$(echo "\\\\\\\\cndr-indd.uphs.pennhealth.prv\\\\mrireport")

new_file=${session_id}.pdf
scp $file $X2Go:/home/xnat/AshsHarpIcv_pipeline/${new_file}

ssh $X2Go "bash -s" << EOF 
	cd /home/xnat/AshsHarpIcv_pipeline/; 
	pwd;
	smbclient $target -m SMB2 -A $auth -c "put $new_file";
EOF

