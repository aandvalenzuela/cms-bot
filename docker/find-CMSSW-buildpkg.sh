release="CMSSW_13_2_X"
cmsos=$(echo $SCRAM_ARCH | awk -F'[_]' '{print $1"_"$2}')

base_dir=$(pwd)
workspace_dir="${base_dir}/workspace"
mkdir $workspace_dir && cd $workspace_dir

git clone -b CMSSW_13_2_X-docker https://github.com/aandvalenzuela/cmsdist.git
git clone -b force-rebuild-pkgs https://github.com/aandvalenzuela/pkgtools.git
git clone https://github.com/aandvalenzuela/cmssw-driver-files.git

wget cmsrep.cern.ch/cmssw/bootstrap.sh

bootstrap_dir="${workspace_dir}/BUILD"
logfile_dir="${base_dir}/logs/${SCRAM_ARCH}"
main_log="${base_dir}/${SCRAM_ARCH}_main.log"
mkdir -p $logfile_dir
touch $main_log

driver_file="${base_dir}/${SCRAM_ARCH}_generated-driver.txt"
cp $workspace_dir/cmssw-driver-files/el8_amd64_gcc11-perl.txt $driver_file
mkdir -p $bootstrap_dir

logging() {
  message=$1
  logfile=$2

  content="[$(date +"%H:%M:%S")]: $message"
  echo $content && echo $content >> $logfile
}

bootstrap_reseed() {
  driver_file=$1
  SCRAM_ARCH=$2
  workspace_dir=$3
  log_file=$4

  sh bootstrap.sh -y -driver $driver_file -a $SCRAM_ARCH -p $workspace_dir setup > $log_file 2>&1
  exit_code=$(echo $?)
}

#find_provides_from_log() {
#  log=$1
#  main_log=$2
#  string_element=""
#  logging "Analyzing log $1..." "${main_log}"
#  for provide in $(cat $log | grep ".* is needed by" | cut -d " " -f1)
#  do
#        pkg=$(rpm -q --whatprovides $provide --qf "%{NAME}\n" | tail -1)
#        noprovide=$(echo $pkg | grep "no package provides")
#        if [ -n "$noprovide" ]
#        then
#          continue
#        fi
#        package=$(echo $string_element | grep $pkg)
#        if [ -z "$package" ]
#        then
#           string_element+=" $pkg"
#           logging "Adding $pkg that provides $provide ..." $main_log
#        fi
#    done
#}

find_provides_from_log() {
  log=$1
  main_log=$2
  scram_string_element=""
  rpm_string_element=""
  fakesystem_string_element=""
  for provide in $(cat $log | grep ".* is needed by" | awk '{printf "%s*%s\n", $1, $NF}')
  do
        logging "--> New find: $provide" $main_log
	dependency=$(echo $provide | cut -d '*' -f1)
	dependent_pkg=$(echo $provide | cut -d '*' -f2)
	scram_flag=$(echo $dependent_pkg | grep "SCRAM")
	if [ -n "$scram_flag" ]
	then
	  pkg=$(rpm -q --whatprovides $dependency --qf "%{NAME}\n" | tail -1)
	  noprovide=$(echo $pkg | grep "no package provides")
	  if [ -z "$noprovide" ]
          then
	    package=$(echo $scram_string_element | grep $pkg)
	    if [ -z "$package" ]
            then
	      scram_string_element+=" $pkg"
	      logging "[SCRAM] Adding $pkg that provides $dependent_pkg ..." $main_log
            fi
	  fi
        else
          pkg=$(rpm -q --whatprovides $dependency --qf "%{NAME}\n" | tail -1)
	  fakesystem_flag=$(echo -n $pkg | grep "fakesystem")
	  if [ -n "$fakesystem_flag" ]
	  then
	    package=$(echo $fakesystem_string_element | grep $pkg)
            if [ -z "$package" ]
            then
              fakesystem_string_element+=" $pkg"
              logging "[FAKESYSTEM] Adding $pkg that provides $dependent_pkg ..." $main_log
            fi
          else
	    pkg=$(rpm -q --whatprovides $dependency --qf "%{NAME}\n" | tail -1)
            noprovide=$(echo $pkg | grep "no package provides")
            if [ -z "$noprovide" ]
            then
              package=$(echo $rpm_string_element | grep $pkg)
              if [ -z "$package" ]
              then
                rpm_string_element+=" $pkg"
               logging "[RPM] Adding $pkg that provides $dependent_pkg ..." $main_log
              fi
	    else
              # Nothing on system
	      package=$(echo $fakesystem_string_element | grep $pkg)
              if [ -z "$package" ]
	      then
                fakesystem_string_element+=" $dependency"
                logging "[FAKESYSTEM] Adding $dependency itself that provides $dependent_pkg ..." $main_log
	      fi
	    fi
	  fi
	fi
    done
}

# Bootstrap with driver file from the installation
sh -ex bootstrap.sh -debug -driver $driver_file -a $SCRAM_ARCH -p $bootstrap_dir setup > "$logfile_dir/${release}_bootstrap_setup.log" 2>&1
# Symlink rpm-env.sh to avoid bootstrapping during the build process
ln -sf $workspace_dir/BUILD/el8_amd64_gcc11/external/rpm/*/etc/profile.d/init.sh $workspace_dir/BUILD/el8_amd64_gcc11/rpm-env.sh

logging "Starting CMSSW build for $SCRAM_ARCH..." "${main_log}"

logging "Building CMSSW release $release ..." "${main_log}"

count=0
build_exit_code=1

while [ $build_exit_code -ne 0 ]
  do
    logging " --- ITERATION $count --- " "${main_log}"
    ./pkgtools/cmsBuild --debug -a $SCRAM_ARCH -j 16 -c cmsdist -i BUILD --builders 3 build cmssw-tool-conf > "$logfile_dir/${release}_build_${count}.log" 2>&1
    build_exit_code=$(echo $?)
    if [ $build_exit_code -ne 0 ]
    then
      find_provides_from_log "$logfile_dir/${release}_build_${count}.log" "${main_log}"
      if [ -n "$rpm_string_element" ]
      then
        echo "${cmsos}_platformSeeds+=\"$rpm_string_element\"" >> $driver_file
      fi
      if [ -n "$scram_string_element" ]
      then
        echo "platformSeeds+=\"$scram_string_element\"" >> $driver_file
      fi
      if [ -n "$fakesystem_string_element" ]
      then
        echo "additionalProvides+=\"$fakesystem_string_element\"" >> $driver_file
      fi
      # Bootstrap again with reseed
      # rm -rf $bootstrap_dir && mkdir $bootstrap_dir
      #bootstrap_reseed $driver_file $SCRAM_ARCH $bootstrap_dir "$logfile_dir/${release}_bootstrap_${count}.log"
      logging " ---> Bootstrapping again! New driver file:\n $(cat $driver_file)" "${main_log}"
      sh -ex bootstrap.sh -debug -driver $driver_file -a $SCRAM_ARCH -p $bootstrap_dir -seed-type "build" reseed > "$logfile_dir/${release}_bootstrap_${count}.log" 2>&1
      # ln -sf $workspace_dir/BUILD/el8_amd64_gcc11/external/rpm/*/etc/profile.d/init.sh $workspace_dir/BUILD/el8_amd64_gcc11/rpm-env.sh
      let count++
    else
      logging " ---> Successful build for $release! Final driver file:\n $(cat $driver_file)" "${main_log}"
    fi
      logging "Exit code from build operation: $build_exit_code" "${main_log}"
  done
