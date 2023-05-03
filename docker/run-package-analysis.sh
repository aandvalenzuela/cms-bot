#!/bin/bash -ex
#/cvmfs/cms.cern.ch/common/cmssw-el8  --command-to-run ./install-CMSSW.sh


# Required variables
export SCRAM_ARCH=slc7_amd64_gcc10
echo "Running for $SCRAM_ARCH"

/cvmfs/cms.cern.ch/common/cmssw-cc7  --command-to-run ./find-CMSSWinstall-packages.sh
