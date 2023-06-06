#!/bin/bash -ex
#/cvmfs/cms.cern.ch/common/cmssw-el8  --command-to-run ./install-CMSSW.sh


# Required variables
export SCRAM_ARCH=el8_amd64_gcc11
echo "Running for $SCRAM_ARCH"

/cvmfs/cms.cern.ch/common/cmssw-el8  --command-to-run ./build-cmssw.sh
