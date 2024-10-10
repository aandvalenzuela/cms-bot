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
    common/cmspkg -a $SCRAM_ARCH install -y -r cms.${REPO_WEEK} cms+cmssw+${IB}
    cd ..
  fi
  source cmssw/cmsset_default.sh
  scram list CMSSW
}

function create_development_area()
{
  if [ ! -d ${IB} ] ; then
    scram p ${IB}
    cd ${IB}/src
    cmsenv
    git cms-addpkg '*'
    cd ..
    if [[ "X$O2" == "Xtrue" ]]; then
	echo "*** USING -O2 OPTIMIZATION ***"
        find config/toolbox/el8_amd64_gcc12/tools/selected/ -type f -name 'gcc-*.xml' -exec sed -i 's/O3/O2/g' {} \;
        for tool in $(find . -type f -name 'gcc-*.xml' | rev | cut -d "/" -f1 | rev | cut -d "." -f1); do
	    scram setup $tool
	done
	find config/toolbox/el8_amd64_gcc12/tools/selected/ -type f -name 'cuda.xml' -exec sed -i 's/O3/O2/g' {} \; && scram setup cuda
    else
        echo "*** USING -O3 OPTIMIZATION ***"
    fi
  cd ..
  fi
}

echo "*** INSTALLING RELEASE LOCALLY ***"
REPO_WEEK=$(python3 cms-bot/get_ib_week.py ${IB})
create_local_installation
echo "*** CREATING DEVELOPMENT AREA ***"
create_development_area
echo "*** BUILDING CMSSW ***"
cd ${IB} && cmsenv
scram build -j 16
echo "*** RUNNING WF TO DUMP CONFIG FILES ***"
mkdir relvals && mkdir data && cd data
runTheMatrix.py -l $WF -t 4 --ibeos
cp -r ${WF}*/*.py ../relvals
cd ${WF}*

if [[ "X$LOCAL_DATA" == "XTrue" ]]; then
  echo "COPYING DATA"
  # Parse logs to get the data
  for logfiles in $(ls *.log); do
    for file in $(grep "Successfully opened file" $logfiles | grep -o 'root://[^ ]*'); do
      echo "--> ${file}"
      local_path=$(echo ${file} | sed 's/.*\(store\/.*\)/\1/')
      mkdir -p $(dirname ${local_path})
      xrdcopy ${file} ${local_path} || true
    done
  done
  # Parse config files to get the data
  for configfiles in $(ls *.py); do
    datafiles=$(grep "process.mix.input.fileNames" $configfiles | cut -d "[" -f2 | cut -d "]" -f1 | tr -d "'")
    xrootdprefix="root://eoscms.cern.ch//eos/cms/store/user/cmsbuild/"
    for file in ${datafiles//,/ }; do
      echo "--> $file"
      local_path=$(echo ${file} | sed 's/.*\(store\/.*\)/\1/')
      mkdir -p $(dirname ${local_path})
      xrootdfile=$(echo $file | cut -d : -f2)
      xrdcopy ${xrootdprefix}${xrootdfile} ${local_path} || true
    done
  done
  mv store ../../relvals
fi

cd ../../relvals

echo "*** RUNNING WF STEPS ***"
for x in 1 2 3 4 5; do
  echo "--------- NEW RUN ------------"
  for files in $(ls *.py); do
    if [ ${x} -eq 0 ]; then
      echo "[DBG] Modifying number of events to a 100"
      sed -i "s/(10)/(100)/g" $files
      if [[ "X$LOCAL_DATA" == "XTrue" ]]; then
        sed -i "s/\/store/file:store/g" $files
      fi
    fi
    file_name=$(echo $files | cut -d "." -f1)
    echo "--> ${file_name}"
    /usr/bin/time --verbose cmsRun --enablejobreport --jobreport "${WF}-${TYPE}-${file_name}-${x}.xml" $files >> "${WF}-${TYPE}-${file_name}.out" 2>&1
    cat "${WF}-${TYPE}-${file_name}.out" | grep "Elapsed "
  done
  echo "------------------------------"
done
