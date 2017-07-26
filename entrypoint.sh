#!/bin/sh

# The purpose of this script is to bootstrap installation from docker container
# Be carefeul when modifying this file, by default it is executed under alpine image which
# is based on busybox (GNU tools are not available).
#

readonly AGENT_SHORT_NAME="Dynatrace"
readonly AGENT_PRODUCT_NAME="${AGENT_SHORT_NAME} OneAgent"

readonly INSTALL_FOLDER=dynatrace/oneagent
readonly INSTALL_BASE=/opt
readonly INSTALL_PATH=${INSTALL_BASE}/${INSTALL_FOLDER}
readonly AGENT_INSTALL_PATH=${INSTALL_PATH}/agent
readonly AGENTCONF_PATH=${AGENT_INSTALL_PATH}/conf
readonly AGENT_BINARIES_JSON_FILE_PATH=${AGENTCONF_PATH}/binaries.json
readonly DOCKER_DEPLOYMENT_CONF_FILE=${AGENTCONF_PATH}/dockerdeployment.conf
readonly AGENT_RUNTIME_DIR=/var/lib/dynatrace/oneagent/agent

#Where to host filesystem should be placed 
DOCKER_HOST_ROOT_PREFIX=/mnt/root
#Log file where bootstrapping logs are stored
DOCKER_LOG_FILE="${DOCKER_HOST_ROOT_PREFIX}/${INSTALL_PATH}/log/installer/installation_docker_$$.log"

EXIT_CODE_ERROR=1
PATH=/usr/sbin:/usr/bin:/sbin:/bin:${PATH}
DOCKER_INSTALLER_SCRIPT_URL="${ONEAGENT_INSTALLER_SCRIPT_URL}"
DOCKER_INSTALLER_SCRIPT_NAME=Dynatrace-OneAgent-Linux.sh
DOCKER_INSTALLER_ROOT_CA_PATH=/tmp/dt-root.cert.pem
DOCKER_INSTALLER_PATH="/tmp/${DOCKER_INSTALLER_SCRIPT_NAME}"
INSTALLER_PATH_ON_HOST="${INSTALL_PATH}/${DOCKER_INSTALLER_SCRIPT_NAME}"
DOCKER_INSTALLER_SKIP_CERT_CHECK="${ONEAGENT_INSTALLER_SKIP_CERT_CHECK}"

readonly AGENT_INIT_SCRIPT="${AGENT_INSTALL_PATH}/initscripts/oneagent"

toLog() {
	echo "$(date -u +"%Y-%m-%d %H:%M:%S") UTC" "$@" >> ${DOCKER_LOG_FILE}
}

onlyToConsole() {
    echo "$(date +"%H:%M:%S")" "$@"
}

toLogInfo() {
	toLog "[INFO] " "$@"
}

toLogWarning() {
	toLog "[WARN] " "$@"
}

toLogError() {
	toLog "[ERROR]" "$@"
}

toConsoleInfo() {
	onlyToConsole "$@"
	toLogInfo "$@"
}

toConsoleWarning() {
	onlyToConsole "$@"
	toLogWarning "$@"
}

toConsoleError() {
	onlyToConsole "$@"
	toLogError "$@"
}

# $1 - directory
# $2 - rights
createDirIfNotExistAndSetRights() {
	if [ ! -d "$1" ]; then
		if ! mkdir -p "$1"; then
			onlyToConsole "Cannot create $1 directory."
		fi		
	fi
	
	if ! chmod "$2" "$1"; then
		onlyToConsole "Cannot change permisions of $1 directory to ${2}."
	fi
}

createLogDirsIfMissing() {
	createDirIfNotExistAndSetRights "${DOCKER_HOST_ROOT_PREFIX}/${INSTALL_PATH}" 755
	createDirIfNotExistAndSetRights "${DOCKER_HOST_ROOT_PREFIX}/${INSTALL_PATH}/log" 777
	createDirIfNotExistAndSetRights "${DOCKER_HOST_ROOT_PREFIX}/${INSTALL_PATH}/log/installer" 755
	createDirIfNotExistAndSetRights "${DOCKER_HOST_ROOT_PREFIX}/${INSTALL_PATH}/log/network" 755
}

initializeLog() {
	toConsoleInfo "Started agent deployment as docker image, PID $$."
	toLogInfo "System version: $(uname -a)"
	toLogInfo "Path: ${PATH}"
	toConsoleInfo "Container version: $(getContainerVersion)"
	toLogInfo "Host version: $(getHostVersion)"
}

addEmptyLineToLog() {
	echo " " >> "${DOCKER_LOG_FILE}"
}

finishWithExitCode() {
	toLogInfo "Docker entrypoint script finished, PID $$."
	addEmptyLineToLog
	exit "${1}"
}

runCommandWithTimeout() {
	local commandTimeout=5
	local commandInterval=1
	local commandDelay=1
	local resultFile="/tmp/ruxit_commandResult_$$"
	local errorFile="/tmp/ruxit_commandError_$$"
	local loopErrorsFile="/tmp/ruxit_loopErrors_$$"
	local loopErrors=
	toLogInfo "Executing $* with timeout $commandTimeout seconds"
	("$@" > ${resultFile} 2>${errorFile} & child=$!
		local waitTime
		waitTime=${commandTimeout}
		
		while [ ${waitTime} -gt 0 ]; do
			toLogInfo "Time left: ${waitTime} pid: ${child} command: $*"
			sleep ${commandInterval}
			kill -0 "$child" || exit 0
			waitTime=$((waitTime - commandInterval))
		done

		# Be nice, post SIGTERM first.
		# The 'exit 0' below will be executed if any preceeding command fails.
		toLogInfo  "Killing child: ${child} with SIGTERM"
		kill -s 15 "${child}" && kill -0 "${child}" || exit 0
		sleep $commandDelay
		toLogWarning "Killing child: ${child} with SIGKILL"
		kill -s 9 "${child}"
		
	) 2> "${loopErrorsFile}"
	
	errorOutput=$(cat ${errorFile})
	commandOutput=$(cat ${resultFile})
	
	if [ -f "${errorFile}" ]; then
		rm "${errorFile}" >  /dev/null
	fi
	
	if [ -f "${resultFile}" ]; then
		rm "${resultFile}" > /dev/null
	fi
	
	if [ -n "${errorOutput}" ]; then
		toLogInfo "Failed to execute $*, error output ${errorOutput}"
		loopErrors=$(cat "${loopErrorsFile}")
		toLogInfo "Loop errors: ${loopErrors}"
		rm "${loopErrorsFile}" 2> /dev/null
		echo ""
		return 1
	else
		toLogInfo "$* executed successfully, output: ${commandOutput}"
		rm "${loopErrorsFile}" 2> /dev/null
		echo "${commandOutput}"
		return 0
	fi
}

isProcessRunningInContainer() {
	if [ ! -f "/proc/${1}/cgroup" ]; then
		return 1
	fi
	
	if grep "docker" "/proc/${1}/cgroup" -q; then
		return 0
	fi

	if ! chroot ${DOCKER_HOST_ROOT_PREFIX} which docker >/dev/null 2>&1; then
		return 1
	fi
	
	local containerIDs
	containerIDs="$(runCommandWithTimeout "chroot" "${DOCKER_HOST_ROOT_PREFIX}" "docker" "ps" "--no-trunc" "-q")"
	if [ $? -ne 0 ]; then
		onlyToConsole "docker ps returned: ${containerIDs}"
		return 1
	fi
	
	for id in ${containerIDs}; do
		if grep -q "${id}" "/proc/${1}/cgroup"; then
			return 0
		fi
	done

	return 1
}

getContainerVersion() {
	local delimiter="#################ENDOFSCRIPTMARK############"
	local scriptEnd=$(awk '/^'"${delimiter}"'/ { print NR; exit }' ${DOCKER_INSTALLER_PATH})
	head -n ${scriptEnd} "${DOCKER_INSTALLER_PATH}" | grep 'AGENT_INSTALLER_VERSION=' | cut -d = -f 2
}

getHostVersion() {
	if [ -f "${DOCKER_HOST_ROOT_PREFIX}/${AGENT_BINARIES_JSON_FILE_PATH}" ]; then
		jq -c -r '.os.main["linux-x86-64"]["installer-version"]' "${DOCKER_HOST_ROOT_PREFIX}/${AGENT_BINARIES_JSON_FILE_PATH}"
	else
		echo "0"
	fi
}

validateCommandExists() {
	"$@" > /dev/null 2>&1

	if [ $? -eq 127 ]; then
		return 1
	fi

	return 0
}

# Unmounts directories injected by PA
# If the agent is already running on the host machine then process agent will inject several directories
# into the docker container in which we are running, thus we unmount them to prevent any unexpected behaviours
# which might have been caused by this in the future
unmountInjectedDirectories() {
	local directoryMounted
	for directory in ${INSTALL_PATH} ${AGENT_RUNTIME_DIR}/config/container.conf ${AGENT_RUNTIME_DIR}/config
	do
		directoryMounted=$(mount | grep "${directory}")
		if [ ! -z "${directoryMounted}" ]; then
 			toLogInfo "Unmounting injected directory: ${directory}" 
			umount "${directory}"
		fi
	done
}

copyInstallerFileToHost() {
	local hostScriptPath="${DOCKER_HOST_ROOT_PREFIX}/${INSTALLER_PATH_ON_HOST}"
	createDirIfNotExistAndSetRights "${DOCKER_HOST_ROOT_PREFIX}/${INSTALL_PATH}" 755
	toLogInfo "Executing: cp ${DOCKER_INSTALLER_PATH} ${hostScriptPath}"
	
	if ! cp "${DOCKER_INSTALLER_PATH}" "${hostScriptPath}"; then
		toLogError "Cannot copy installer file to host"
		finishWithExitCode "${EXIT_CODE_ERROR}"
	fi
	
	if ! chmod +x "${hostScriptPath}"; then
		toLogError "Cannot set executable bit on installer: ${hostScriptPath}"
	fi
}

# Returns 1 if os agent is running 0 in other case
checkAgentRunning() {
	if [ ! -f "${DOCKER_HOST_ROOT_PREFIX}/${AGENT_INIT_SCRIPT}" ]; then
		toLogInfo "File ${DOCKER_HOST_ROOT_PREFIX}/${AGENT_INIT_SCRIPT} does not exists, OsAgent not running"
		echo 0
	else 
		toLogInfo "Executing: chroot ${DOCKER_HOST_ROOT_PREFIX} ${AGENT_INIT_SCRIPT} status"
		
		#TODO: We shouldn't grep the output here and instead use a more reliable method
		local statusOutput="$(chroot ${DOCKER_HOST_ROOT_PREFIX} ${AGENT_INIT_SCRIPT} status)"
		toLogInfo "Result: ${statusOutput}"
		local osAgentRunning="$(echo "${statusOutput}" | grep "not running")"
		if [ -z "${osAgentRunning}" ]; then
			echo 1
		else
			echo 0
		fi
	fi
}

runAgents() {
	if [ ! -f "${DOCKER_HOST_ROOT_PREFIX}/${INSTALLER_PATH_ON_HOST}" ]; then
		copyInstallerFileToHost
	fi

	if [ "$(checkAgentRunning)" -eq 0 ]; then
		toLogInfo "Excuting: chroot ${DOCKER_HOST_ROOT_PREFIX} ${INSTALLER_PATH_ON_HOST} MERGE_CONFIG=1 $*"
		chroot ${DOCKER_HOST_ROOT_PREFIX} ${INSTALLER_PATH_ON_HOST} MERGE_CONFIG=1 "$@"
	else
		toLogInfo "Not merging configuration because OsAgent is running"
	fi
	toConsoleInfo "Starting agents..."
	exec chroot ${DOCKER_HOST_ROOT_PREFIX} ${AGENT_INIT_SCRIPT} exec
	toConsoleError "Failed to start agents"
	finishWithExitCode "${EXIT_CODE_ERROR}"
}

downloadAndVerifyAgentInstaller() {
	local SRC="${DOCKER_INSTALLER_SCRIPT_URL}"
	local DST="${DOCKER_INSTALLER_PATH}"
	local SKIP_CERT=""
	
	echo "${SRC}" | grep -e '^https://' > /dev/null
	if [ ! $? -eq 0 ]; then
		toConsoleError "Setup won't continue. Agent installer can be downloaded only from secure location. Your installer URL should start with 'https' ${SRC}"
		finishWithExitCode "${EXIT_CODE_ERROR}"
	fi
	
	echo "${DOCKER_INSTALLER_SKIP_CERT_CHECK}" | grep -i -e '^true$' > /dev/null
	if [ $? -eq 0 ]; then
		SKIP_CERT="--no-check-certificate"
	fi
	
	toConsoleInfo "Deploying agent to ${DST} via ${SRC}"
	toLogInfo "Executing: wget ${SKIP_CERT} -O ${DST} ${SRC}"
	wget ${SKIP_CERT} -O "${DST}" "${SRC}"
	if [ ! $? -eq 0 ]; then
		if [ $? -eq 5 ]; then
			toConsoleError "Failed to verify SSL certificate: ${SRC}. Setup won't continue."
		else
			toConsoleError "Cannot execute: wget "${SKIP_CERT}" -O ${DST} ${SRC}. Setup won't continue."
		fi

		finishWithExitCode "${EXIT_CODE_ERROR}"
	fi

	toConsoleInfo "Validating agent installer in ${DST}"
	toLogInfo "Executing: ( echo 'Content-Type: multipart/signed; protocol=\"application/x-pkcs7-signature\"; micalg=\"sha-256\"; boundary=\"--SIGNED-INSTALLER\"'; echo ; echo ; echo '----SIGNED-INSTALLER' ; cat ${DST} ) | openssl cms -verify -CAfile ${DOCKER_INSTALLER_ROOT_CA_PATH} > /dev/null"
	( echo 'Content-Type: multipart/signed; protocol="application/x-pkcs7-signature"; micalg="sha-256"; boundary="--SIGNED-INSTALLER"'; echo ; echo ; echo '----SIGNED-INSTALLER' ; cat "${DST}" ) | openssl cms -verify -CAfile "${DOCKER_INSTALLER_ROOT_CA_PATH}" > /dev/null
	if [ ! $? -eq 0 ]; then
		if [ $? -eq 4 ]; then
			toConsoleError "Failed to validate integrity of agent installer in ${DST}. Setup won't continue."
		else
			toConsoleError "Cannot execute: ( echo 'Content-Type: multipart/signed; protocol=\"application/x-pkcs7-signature\"; micalg=\"sha-256\"; boundary=\"--SIGNED-INSTALLER\"'; echo ; echo ; echo '----SIGNED-INSTALLER' ; cat ${DST} ) | openssl cms -verify -CAfile ${DOCKER_INSTALLER_ROOT_CA_PATH} > /dev/null. Setup won't continue."
		fi

		finishWithExitCode "${EXIT_CODE_ERROR}"
	fi
}

deployAgentToHost() {
	toConsoleInfo "Deploying to: ${DOCKER_HOST_ROOT_PREFIX}"
	copyInstallerFileToHost

	toLogInfo "Creating ${DOCKER_HOST_ROOT_PREFIX}/${DOCKER_DEPLOYMENT_CONF_FILE}"
	createDirIfNotExistAndSetRights "${DOCKER_HOST_ROOT_PREFIX}/${AGENTCONF_PATH}" 755
	echo "DeployedInsideDockerContainer=true" >"${DOCKER_HOST_ROOT_PREFIX}/${DOCKER_DEPLOYMENT_CONF_FILE}"

	toLogInfo "Executing: exec chroot ${DOCKER_HOST_ROOT_PREFIX} ${INSTALLER_PATH_ON_HOST} $* DOCKER_ENABLED=1 PROCESSHOOKING=0"
	exec chroot "${DOCKER_HOST_ROOT_PREFIX}" "${INSTALLER_PATH_ON_HOST}" "$@" DOCKER_ENABLED=1 PROCESSHOOKING=0
	toConsoleError "Cannot execute: exec chroot ${DOCKER_HOST_ROOT_PREFIX} ${INSTALLER_PATH_ON_HOST} $* DOCKER_DEPLOY_TO_HOST=1. Setup won't continue."
	finishWithExitCode "${EXIT_CODE_ERROR}"
}

# This is only executed when Ruxit is distributed as docker image
# If host version is the same as container version it starts agent from host
# If version is different it runs installer on host
startOrDeployAgentOnHost() {
	local versionNumber="$(getHostVersion | cut -d. -f2)"
	local minimalVersionForCheckingDockerDeployment=119
	local forceAgentUpgrade="no"
	if [ "${versionNumber}" -ge ${minimalVersionForCheckingDockerDeployment} ]; then
		local deploymentConf="${DOCKER_HOST_ROOT_PREFIX}/${DOCKER_DEPLOYMENT_CONF_FILE}"
		local binariesJSON="${DOCKER_HOST_ROOT_PREFIX}/${AGENT_BINARIES_JSON_FILE_PATH}"
		if [ -f "${binariesJSON}" ] && ! grep -q "DeployedInsideDockerContainer=true" "${deploymentConf}" 2>/dev/null; then
			toConsoleError "Agent was installed directly on the host and must be uninstalled before proceeding."
			toConsoleError "For further information please visit: https://help.dynatrace.com/get-started/installation/how-do-i-uninstall-dynatrace-agent/"
			finishWithExitCode "${EXIT_CODE_ERROR}"
		fi
	else
		toLogInfo "Skipping ${DOCKER_DEPLOYMENT_CONF_FILE} check because agent version is lower than ${minimalVersionForCheckingDockerDeployment}"
		forceAgentUpgrade="yes"
	fi

	if [ "$(getContainerVersion)" != "$(getHostVersion)" ] || [ ${forceAgentUpgrade} = "yes" ]; then
		deployAgentToHost "$@"
	else	
		runAgents "$@"
	fi
}

# Writing anything to log when the host root was not mounted correctly (-v option for docker run was not specified by the user) is pointless
# Furthermore, this function is executed at the very beggining of the script, before log directories are even created
# that's why whole output should be directed to the console only with the sole purpose of informing the user of his mistake
performInitialChecks() {
	if ! isProcessRunningInContainer self; then
		onlyToConsole "This script can be only executed when ${AGENT_PRODUCT_NAME} is deployed as docker container"
		exit "${EXIT_CODE_ERROR}"
	fi

	if [ -z "${ONEAGENT_INSTALLER_SCRIPT_URL+x}" ]; then
		onlyToConsole "The ONEAGENT_INSTALLER_SCRIPT_URL environment variable must be initialized with your cluster's agent download location (to be obtained via \"Deploy Dynatrace\" in the Dynatrace UI). Example: https://abc123.live.dynatrace.com/installer/oneagent/unix/latest/AbCdEfGhIjKlMnOp."
		onlyToConsole "If you are not sure how to launch the container please visit: https://help.dynatrace.com/infrastructure-monitoring/containers/how-do-i-monitor-openshift-container-platform/"
		exit "${EXIT_CODE_ERROR}"
	fi

	if [ ! -d "${DOCKER_HOST_ROOT_PREFIX}" ]; then
		onlyToConsole "We have detected that ${AGENT_PRODUCT_NAME} was started inside a docker container but ${DOCKER_HOST_ROOT_PREFIX} does not exist."
		onlyToConsole "If you are not sure how to launch the container please visit: https://help.dynatrace.com/monitor-cloud-virtualization-and-hosts/hosts/how-do-i-deploy-dynatrace-as-docker-container/"
		exit "${EXIT_CODE_ERROR}"
	fi
}

performPreDeploymentChecks() {
	if [ "$(checkAgentRunning)" -eq 1 ]; then
		toConsoleError "OsAgent running, please stop it before starting the container"
		finishWithExitCode "${EXIT_CODE_ERROR}"
	fi
}

################################################################################
#
# Script start
#
################################################################################
main() {
	performInitialChecks
	createLogDirsIfMissing
	downloadAndVerifyAgentInstaller
	initializeLog
	unmountInjectedDirectories
	performPreDeploymentChecks
	startOrDeployAgentOnHost "$@"
}

main "$@"
