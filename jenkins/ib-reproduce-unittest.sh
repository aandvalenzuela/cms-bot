source /cvmfs/cms.cern.ch/cmsset_default.sh
scram -a $SCRAM_ARCH project $RELEASE_FORMAT
cd $RELEASE_FORMAT/src
eval `scram run -sh`
git cms-addpkg $CMSSW_MODULE
scram build -j 4
scram build use-ibeos runtests_$UNIT_TEST || exit 1
exit 0
