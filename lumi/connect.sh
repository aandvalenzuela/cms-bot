LUMI_USER="andbocci"
LUMI_SUMBITTER_SYSTEM="lumi.csc.fi 'sattach 7186516.0'"
SSH_OPTS="-q -o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=60"
#LUMI_JOB_ID=$(squeue --user=andbocci --format %A | tail -1)
LUMI_JOB_ID="7186516.0"
NODE_NAME="lumi${LUMI_JOB_ID}"

WORK_DIR="/users/andbocci"
CMS_BOT_DIR="/build/workspace/cache/cms-bot"

cp ${CMS_BOT_DIR}/lumi/node.xml node.xml
sed -i -e "s|@WORK_DIR@|$WORK_DIR|g;s|@CMS_BOT_DIR@|$CMS_BOT_DIR|" node.xml
sed -i -e "s|@LABELS@|$LABELS lumiid-${LUMI_JOB_ID}|g;s|@NODE_NAME@|$NODE_NAME|g" node.xml
sed -i -e "s|@LUMI_USER@|$LUMI_USER|g;s|@LUMI_SUMBITTER_SYSTEM@|$LUMI_SUMBITTER_SYSTEM|g" node.xml

echo "node definition"
cat node.xml
echo "=========="
cat node.xml | ${JENKINS_CLI_CMD} create-node ${NODE_NAME}

echo "Starting Node: ${NODE_NAME}"
echo "JENKINS_CLI_CMD: ${JENKINS_CLI_CMD}"
#if ! ${JENKINS_CLI_CMD} connect-node ${NODE_NAME} ; then
#  sleep 60
#  ${JENKINS_CLI_CMD} connect-node ${NODE_NAME}
#fi
