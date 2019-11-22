#!/usr/bin/env bash

######### FUNCTIONAL 01 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func_in=$1
# folders
fdir=$2
# PEpolar
pepl=${5:-none}
brev=${6:-none}
bfor=${7:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

## 01. PEpolar
# If there isn't an estimated field, make it.
if [[ "${pepl}" == "none" ]]
then
	pepl=${func}_topup

	mkdir ${pepl}
	fslmerge -t ${pepl}/mgdmap ${brev} ${bfor}

	cd ${pepl}
	echo "Computing PEPOLAR map for ${func}"
	topup --imain=mgdmap --datain=${cwd}/acqparam.txt --out=outtp --verbose
	cd ..
fi

# 03.2. Applying the warping to the functional volume
echo "Applying PEPOLAR map on ${func}"
applytopup --imain=${func_in} --datain=${cwd}/acqparam.txt --inindex=1 \
--topup=${pepl}/outtp --out=${func}_tpp --verbose --method=jac

cd ${cwd}