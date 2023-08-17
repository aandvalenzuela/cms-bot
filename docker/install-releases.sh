#!/bin/bash

cmsos=$(echo $SCRAM_ARCH | awk -F'[_]' '{print $1"_"$2}')
# seeds=("rpm_version" "platformSeeds" "unsupportedSeeds" $cmsos"_platformSeeds" "requiredSeeds" "requiredBuildSeeds" $cmsos"_platformBuildSeeds" $cmsos"_packagesWithProvides" $cmsos_"packagesWithBuildProvides" "packageList" "additionalProvides" "defaultPkgs")

base_dir=$(pwd)
bootstrap_dir="${base_dir}/bootstrap-workspace"
workspace_dir="${base_dir}/workspace"
logfile_dir="${base_dir}/logs/${SCRAM_ARCH}"
main_log="${base_dir}/${SCRAM_ARCH}_main.log"
mkdir -p $logfile_dir
touch $main_log

bootstrap_log="${bootstrap_dir}/bootstrapx.log"
# driver_file="${base_dir}/${SCRAM_ARCH}_generated-driver.txt"
# rm -rf $driver_file && touch $driver_file

# Create empty workspace for bootstrap
# rm -rf $bootstrap_dir
# mkdir $bootstrap_dir && cd $bootstrap_dir

# Get bootstrap script. TODO: Maybe get driver directly with curl
wget cmsrep.cern.ch/cmssw/bootstrap.sh
chmod +x bootstrap.sh
mv bootstrap.sh $base_dir && cd ${base_dir} 

# NO NEED OF PRE-BOOTSTRAP!!
# echo "Running pre-bootstrap"
# Run bootstrap to get the required seeds
# extra seeds: ["missingSeeds", "selSeeds"]
# extra driver elements: rpm_version= el8_amd64_packagesWithProvides= el8_amd64_packagesWithBuildProvides= packageList= additionalProvides= defaultPkgs=
bash -x bootstrap.sh -a $SCRAM_ARCH -p $workspace_dir setup > $bootstrap_log 2>&1

# for seed_type in ${seeds[@]};
# do
#  seed_list=$(cat $bootstrap_log | grep -e "++ $seed_type=" | tail -1 || true)
#  seed_type=$(echo $seed_list | cut -d'=' -f1 | sed "s/++ //g")
#  package_list=$(echo $seed_list | cut -d'=' -f2 | sed "s/'//g")

  # Write driver file
  # seed_element=$(echo $seed_type | grep -e "Seed")
  # if [ -n "$seed_type" ]
  # then
    # if [ -n "$seed_element" ]
    # then
      # echo "$seed_type=\"\"" >> $driver_file
    #else
      # Add only cms-common as default package
      # if [ "$seed_type" == "defaultPkgs" ]
      # then
        # echo "defaultPkgs=\"cms+cms-common+1.0\"" >> $driver_file
      # else
        # echo "$seed_type=\"$package_list\"" >> $driver_file
      # fi
    # fi
  # fi
# done
# Packages bash and tcsh are needed for installing cms-common
# echo "${cmsos}_platformSeeds+=\"bash tcsh\"" >> $driver_file

# Remove bootstrap products
# mkdir $workspace_dir && rm -rf $bootstrap_dir

logging() {
  message=$1
  logfile=$2

  content="[$(date +"%H:%M:%S")]: $message"
  echo $content && echo $content >> $logfile
}


# bootstrap() {
#  driver_file=$1
#  SCRAM_ARCH=$2
#  workspace_dir=$3
#  log_file=$4

#  ./bootstrap.sh -y -driver $driver_file -a $SCRAM_ARCH -p $workspace_dir setup > $log_file 2>&1
#  exit_code=$(echo $?)
#}


find_provides_from_log() {
  log=$1
  main_log=$2
  string_element=""
  for provide in $(cat $log | grep ".* is needed by" | cut -d " " -f1)
  do
        pkg=$(rpm -q --whatprovides $provide --qf "%{NAME}\n" | tail -1)
        noprovide=$(echo $pkg | grep "no package provides")
        if [ -n "$noprovide" ]
        then
          continue
        fi
        package=$(echo $string_element | grep $pkg)
        if [ -z "$package" ]
        then
           string_element+=" $pkg"
           logging "Adding $pkg that provides $provide ..." $main_log
        fi
    done
}

echo "Starting bootstrap"



# Iterate until successful bootstrap
# logging "Starting bootstrap with empty driver file:\n $(cat $driver_file)\n" "${main_log}"
# count=0
# exit_code=1
# while [ $exit_code -ne 0 ]
# do
  # rm -rf $workspace_dir && mkdir $workspace_dir
  # logging " --- ITERATION $count --- " "${main_log}"
  # bootstrap $driver_file $SCRAM_ARCH $workspace_dir "$logfile_dir/bootstrap_${count}.log"  # bootstrap() resets exit_code
  # if [ $exit_code -ne 0 ]
  # then
    # string_element=$(find_provides_from_log "$logfile_dir/bootstrap_${count}.log" "${main_log}")
    # if [ -n "$string_element" ]
    # then
      # echo "${cmsos}_platformSeeds+=\"$string_element\"" >> $driver_file
    # fi
    # let count++
  # fi
  # logging " ---> Successful bootstrap! Final driver file:\n $(cat $driver_file)" "${main_log}"
# done

echo "Starting installation"

logging "Starting CMSSW installation ..." "${main_log}"
# Search for CMSSW
for release in $(bash ${workspace_dir}/common/cmspkg -a $SCRAM_ARCH search cmssw | grep -o cms+cmssw+CMSSW.*- | cut -d' ' -f1);
do
  count=0
  install_exit_code=1
  logging "Installing CMSSW release $release ..." "${main_log}"
  # while [ $install_exit_code -ne 0 ]
  # do
  # logging " --- ITERATION $count --- " "${main_log}"
  # Install all release cycles
  bash ${workspace_dir}/common/cmspkg -a $SCRAM_ARCH install -y $release > "$logfile_dir/${release}_install_${count}.log" 2>&1
  install_exit_code=$(echo $?)
  if [ $install_exit_code -ne 0 ]
  then
    find_provides_from_log "$logfile_dir/${release}_install_${count}.log" "${main_log}"
    if [ -n "$string_element" ]
    then
      echo "---> [MISSING] $string_element\""
    fi
      # Bootstrap again
      # rm -rf $workspace_dir && mkdir $workspace_dir
      # bootstrap $driver_file $SCRAM_ARCH $workspace_dir "$logfile_dir/${release}_bootstrap_${count}.log"
      # bash -x bootstrap.sh -a $SCRAM_ARCH -p $workspace_dir setup > "$logfile_dir/${release}_bootstrap_${count}.log" 2>&1
      # let count++
  else
    logging " ---> Successful installation for $release!"
    #rm -rf $workspace_dir && mkdir $workspace_dir
      # bootstrap $driver_file $SCRAM_ARCH $workspace_dir "$logfile_dir/${release}_bootstrap_newcycle.log"
      #bash -x bootstrap.sh -a $SCRAM_ARCH -p $workspace_dir setup > "$logfile_dir/${release}_bootstrap_newcycle.log" 2>&1
  fi
    logging "Exit code from installation: $install_exit_code" "${main_log}"
    rm -rf $workspace_dir && mkdir $workspace_dir
    bash -x bootstrap.sh -a $SCRAM_ARCH -p $workspace_dir setup > $bootstrap_log 2>&1
  # done
done

echo "END" && exit 0
