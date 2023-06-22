export SCRAM_ARCH=el8_amd64_gcc11
cd /tmp
mkdir workspace && cd workspace
git clone -b CMSSW_13_2_X-docker https://github.com/aandvalenzuela/cmsdist.git
git clone -b force-rebuild-pkgs https://github.com/aandvalenzuela/pkgtools.git
git clone https://github.com/aandvalenzuela/cmssw-driver-files.git

mkdir BUILD
curl cmsrep.cern.ch/cmssw/bootstrap.sh >> bootstrap.sh
sh bootstrap.sh -y -driver cmssw-driver-files/el8_amd64_gcc11.txt -a $SCRAM_ARCH -p BUILD setup
ln -sf $(pwd)/BUILD/el8_amd64_gcc11/external/rpm/*/etc/profile.d/init.sh $(pwd)/BUILD/el8_amd64_gcc11/rpm-env.sh
./pkgtools/cmsBuild --debug -a $SCRAM_ARCH -j 16 -c cmsdist -i BUILD --builders 3 build cmssw-tool-conf
exit
