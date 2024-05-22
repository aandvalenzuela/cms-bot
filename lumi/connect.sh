LUMI_JOB_ID=$(squeue --user=andbocci --format %A | tail -1)
NODE_NAME="lumi${CONDOR_JOB_ID}"
