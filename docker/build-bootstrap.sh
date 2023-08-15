cd /tmp
git clone https://github.com/cms-sw/cmsdist.git
git clone https://github.com/cms-sw/pkgtools.git

export SCRAM_ARCH=el8_amd64_gcc11

./pkgtools/cmsBuild --no-bootstrap -a $SCRAM_ARCH -j 16 -c cmsdist -i BUILD build bootstrap-driver
