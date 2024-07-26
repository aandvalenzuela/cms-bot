#!/bin/bash -ex

IB=$1
CMSRUN_CMD=$2
WF=$3

function cmsenv()
{
  set +x ; eval `scram run -sh` >/dev/null 2>&1 ; set -x
}

function create_local_installation()
{
  if [ ! -d cmssw ] ; then
    mkdir cmssw && cd cmssw
    wget -O bootstrap.sh http://cmsrep.cern.ch/cmssw/repos/bootstrap.sh
    export SCRAM_ARCH=el8_amd64_gcc12
    sh -x bootstrap.sh setup -path $(pwd) -arch $SCRAM_ARCH >& $(pwd)/bootstrap_$SCRAM_ARCH.log
    common/cmspkg -a $SCRAM_ARCH update
    common/cmspkg -a $SCRAM_ARCH install -y -r cms.week1 cms+cmssw+${IB}
    source cmsset_default.sh
    scram list CMSSW
    cd $PGO_GEN_DIR
  fi
}

function create_development_area()
{
  if [ ! -d ${IB} ] ; then
    scram p ${IB}
    cd ${IB}/src
    cmsenv
    git cms-addpkg '*'
    cd $PGO_GEN_DIR
  fi
}

THISDIR=$(realpath $(dirname $0))
arch="el8_amd64_gcc12"
PGO_GEN_DIR=$(pwd)/gen-${WF}
PGO_USE_DIR=$(pwd)/use-${WF}
PGO_BASE=$(pwd)/PGO-${WF}
export CMSSW_CPU_TYPE=""
rm -rf ${PGO_GEN_DIR} ${PGO_USE_DIR} default ${PGO_BASE}
mkdir -p ${PGO_GEN_DIR} ${PGO_USE_DIR} default ${PGO_BASE}


echo "*** GENERATING PGO PROFILES ***"
#Build Test code with profile-generate
pushd ${PGO_GEN_DIR}
  create_local_installation
  create_development_area
  pushd $IB
    cmsenv
    # CMSSW_PGO_DIRECTORY and CMSSW_CPU_TYPE env are used to generate PGO
    export CMSSW_PGO_DIRECTORY=${PGO_BASE}/GEN
    export CMSSW_CPU_TYPE=""
    mkdir $CMSSW_PGO_DIRECTORY
    scram b generate-pgo
    scram b -v -j 10
    cmsenv
    #Run the test to generate the profile in $CMSSW_BASE/PGO directory
    #PGO are generated under $CMSSW_PGO_DIRECTORY directory
    cmsRun $CMSRUN_CMD
    find $CMSSW_PGO_DIRECTORY -name '*' -type f
  popd
popd

echo "*** USING PGO PROFILES ***"
#Rebuild test code using the already generated profiles
pushd ${PGO_USE_DIR}
  create_development_area
  pushd $IB
    # Rename PGO directory to prove that we can use PGO from a different directory
    mv $CMSSW_PGO_DIRECTORY ${PGO_BASE}/USE
    export CMSSW_PGO_DIRECTORY=${PGO_BASE}/USE
    export CMSSW_CPU_TYPE=""
    cmsenv # Maybe not needed
    scram b use-pgo
    scram b -v -j 10
    cmsenv
    #Run N times to the re-built executable
    mkdir ${PGO_BASE}/${WF}
    for x in 0 1 2 ; do
      /usr/bin/time --verbose cmsRun $CMSRUN_CMD >> ${PGO_BASE}/${WF}-pgo.out 2>&1
    done
  popd
popd

echo "*** RUNNING BASELINE ***"
#For ref: Build and run the test code without PGO
pushd default
  create_development_area
  pushd $IB
    scram b -v -j 10 >/dev/null 2>&1
    cmsenv
    for x in 0 1 2 ; do
      /usr/bin/time --verbose cmsRun $CMSRUN_CMD >> ${PGO_BASE}/${WF}-wo-pgo.out 2>&1
    done
  popd
popd
