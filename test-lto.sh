#!/bin/bash -ex

IB=$1
STEP=$2
WF=$3
O2=$4
LOCAL_DATA=$5
RUNS=$6
EVENTS=$7
THREADS=$8

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
    #common/cmspkg -a $SCRAM_ARCH install -y -r cms.${REPO_WEEK} cms+cmssw+${IB}
    common/cmspkg -a $SCRAM_ARCH install -y -r cms.lto cms+cmssw+${IB}
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
        TYPE="${TYPE}-O2"
        find config/toolbox/el8_amd64_gcc12/tools/selected/ -type f -name 'gcc-*.xml' -exec sed -i 's/O3/O2/g' {} \;
        for tool in $(find . -type f -name 'gcc-*.xml' | rev | cut -d "/" -f1 | rev | cut -d "." -f1); do
	    scram setup $tool
	done
	find config/toolbox/el8_amd64_gcc12/tools/selected/ -type f -name 'cuda.xml' -exec sed -i 's/O3/O2/g' {} \; && scram setup cuda
    else
        echo "*** USING -O3 OPTIMIZATION ***"
        TYPE="${TYPE}-O3"
    fi
    cd ..
  fi
}

function create_development_area_for_release()
{
  if [ ! -d ${IB} ] ; then
    scram p ${IB}
    cd ${IB}/src
    cmsenv
    cd ..
  fi
}

echo "*** INSTALLING RELEASE LOCALLY ***"
#REPO_WEEK=$(python3 cms-bot/get_ib_week.py ${IB})
#TYPE="LTO"
#if [[ "${IB}" == *"NONLTO"* ]]; then
#  TYPE="NONLTO"
#fi

TYPE="LTO"
if [[ "${IB}" == *"NONLTO"* ]]; then
  TYPE="NONLTO"
fi
if [[ "${IB}" == *"O2"* ]]; then
  TYPE="O2${TYPE}"
else
  TYPE="O3${TYPE}"
fi

create_local_installation
export SITECONFIG_PATH=/cvmfs/cms.cern.ch/SITECONF/T2_CH_CERN
echo "*** CREATING DEVELOPMENT AREA ***"
create_development_area_for_release
echo "*** BUILDING CMSSW FOR ${TYPE}***"
#cd ${IB} && cmsenv
#scram build -j 16
echo "*** RUNNING WF TO DUMP CONFIG FILES ***"
mkdir relvals && mkdir data && cd data
# step 1 (simulation)

# step 2 (HLT) and step 3 (reconstruction)
if [[ "${STEP}" == *"step3"* ]]; then
  runTheMatrix.py -l $WF -t ${THREADS} --maxSteps 3 --ibeos -i all --job-reports --command "  --customise Validation/Performance/TimeMemorySummary.customiseWithTimeMemorySummary"
fi
#runTheMatrix.py -l $WF -t ${THREADS} --maxSteps 3 --ibeos --job-reports  --command "  --customise Validation/Performance/TimeMemorySummary.customiseWithTimeMemorySummary"

exit 0
cp -r ${WF}*/*.py ../relvals
cd ${WF}*

if [[ "X$LOCAL_DATA" == "Xtrue" ]]; then
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
for x in 1 2 3; do
  echo "--------- NEW RUN ------------"
  step=0
  for files in $(ls *.py); do
    #step=step+1
    step=$((step+1))
    if [ ${x} -eq 1 ]; then
      echo "[DBG] Modifying number of events to a 100"
      sed -i "s/(10)/(${EVENTS})/g" $files
      if [[ "X$LOCAL_DATA" == "Xtrue" ]]; then
	sed -i "s/\/store/file:store/g" $files
      fi
      cat $files | grep "file:store" || true
      cat $files | grep "(100)" || true
    fi
    file_name=$(echo $files | cut -d "." -f1)
    echo "--> ${file_name}"
    SHORT_WF=$(echo $WF | cut -d "." -f1)
    /usr/bin/time --verbose cmsRun --numThreads ${THREADS} $files >> "step${step}_${SHORT_WF}_${TYPE}_${file_name}.logfile" 2>&1
    cat "step${step}_${SHORT_WF}_${TYPE}_${file_name}.logfile" | grep "Elapsed "
    cat "step${step}_${SHORT_WF}_${TYPE}_${file_name}.logfile" | grep "Event Throughput"
  done
  echo "------------------------------"
done

echo "--- RESULTS ---"
for files in $(ls *.logfile); do
  cat ${files} | grep "Elapsed " || true
  cat ${files} | grep "Event Throughput" || true
done

echo "--- TIME SUMMARY ---"
for files in $(ls *.logfile); do
  file_name=$(echo $files | cut -d "." -f1-2 | cut -d "_" -f1-3)
  result=$(cat ${files} | grep "Elapsed " | awk '{print $8}' | paste -sd,)
  echo "${file_name}_time = [$result]"
done

echo "--- EVENT THROUGHPUT SUMMARY ---"
for files in $(ls *.logfile); do
  file_name=$(echo $files | cut -d "." -f1-2 | cut -d "_" -f1-3)
  result=$(cat ${files} | grep "Event Throughput" | awk '{print $3}' | paste -sd,)
  echo "${file_name}_tp = [$result]"
done
