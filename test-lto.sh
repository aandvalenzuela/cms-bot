#!/bin/bash -ex

IB=$1
WF=$2
O2=$3
LOCAL_DATA=$4

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
    cd ..
  fi
}

function create_development_area()
{
  if [ ! -d ${IB} ] ; then
    scram p ${IB}
    cd ${IB}/src
    cmsenv
    git cms-addpkg '*'
    cd ..
    if [[ "X$O2" == "XTrue" ]]; then
	echo "*** USING -O2 OPTIMIZATION ***"
        find config/toolbox/el8_amd64_gcc12/tools/selected/ -type f -name 'gcc-*.xml' -exec sed -i 's/O3/O2/g' {} \;
        for tool in $(find . -type f -name 'gcc-*.xml' | rev | cut -d "/" -f1 | rev | cut -d "." -f1); do
	    scram setup $tool
	done
    else
        echo "*** USING -O3 OPTIMIZATION ***"
    fi
  fi
}

echo "*** INSTALLING RELEASE LOCALLY ***"
create_local_installation
echo "*** CREATING DEVELOPMENT AREA ***"
create_development_area
echo "*** BUILDING CMSSW ***"
cmsenv
scram build -j 16
echo "*** RUNNING WF TO DUMP CONFIG FILES ***"
mkdir relvals && cd relvals
runTheMatrix.py -l $WF -t 4 --ibeos
cp -r ${WF}*/*.py .

if [[ "X$LOCAL_DATA" == "XTrue" ]]; then
  echo "COPYING DATA"
  scp -r cmsbuild@lxplus:/afs/cern.ch/work/c/cmsbuild/store .
fi

echo "*** RUNNING WF STEPS ***"
for x in 0 1 2; do
  echo "--------- NEW RUN ------------"
  for files in $(ls *.py); do
    if [ ${x} -eq 0 ]; then
      echo "[DBG] Modifying number of events to a 100"
      sed -i "s/(10)/(100)/g" $files
      if [[ "X$LOCAL_DATA" == "XTrue" ]]; then
        sed -i "s/\/store/file:store/g" $file
      fi
    fi
    file_name=$(echo $files | cut -d "." -f1)
    echo "--> ${file_name}"
    /usr/bin/time --verbose cmsRun --enablejobreport --jobreport "${WF}-${TYPE}-${file_name}-${x}.xml" $files >> "${WF}-${TYPE}-${file_name}.out" 2>&1
    cat "${WF}-${TYPE}-${file_name}.out" | grep "Elapsed "
  done
  echo "------------------------------"
done
