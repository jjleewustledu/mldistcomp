#!/bin/sh
# This wrapper script is intended to be submitted to PBS to support
# communicating jobs.
#
# This script uses the following environment variables set by the submit MATLAB code:
# MDCE_CMR            - the value of ClusterMatlabRoot (may be empty)
# MDCE_MATLAB_EXE     - the MATLAB executable to use
# MDCE_MATLAB_ARGS    - the MATLAB args to use
#
# The following environment variables are forwarded through mpiexec:
# MDCE_DECODE_FUNCTION     - the decode function to use
# MDCE_STORAGE_LOCATION    - used by decode function 
# MDCE_STORAGE_CONSTRUCTOR - used by decode function 
# MDCE_JOB_LOCATION        - used by decode function 

# Copyright 2006-2011 The MathWorks, Inc.

# Create full paths to mw_smpd/mw_mpiexec if needed
FULL_SMPD=${MDCE_CMR:+${MDCE_CMR}/bin/}mw_smpd
# We'll use our own PBS-aware mpiexec which uses Intel's MPI
FULL_MPIEXEC=/export/src/mpiexec-0.84/mpiexec
SMPD_LAUNCHED_HOSTS=""
MPIEXEC_CODE=0
###################################
## CUSTOMIZATION MAY BE REQUIRED ##
###################################
# This script assumes that SSH is set up to work without passwords between
# all nodes on the cluster.
# You may wish to modify SSH_COMMAND to include any additional ssh options that
# you require.
SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Work out how many processes to launch - set MACHINE_ARG
chooseMachineArg() {
    MACHINE_ARG="-n ${MDCE_TOTAL_TASKS} -machinefile ${PBS_NODEFILE}"
}

# Now that we have launched the SMPDs, we must install a trap to ensure that
# they are closed either in the case of normal exit, or job cancellation:
# Default value of the return code
cleanupAndExit() {
    echo ""
    echo "Stopping SMPD on ${SMPD_LAUNCHED_HOSTS} ..."
    for host in ${SMPD_LAUNCHED_HOSTS}
    do
        echo ${SSH_COMMAND} $host \"${FULL_SMPD}\" -shutdown -phrase MATLAB -port ${SMPD_PORT}
        ${SSH_COMMAND} $host \"${FULL_SMPD}\" -shutdown -phrase MATLAB -port ${SMPD_PORT}
    done
    echo "Exiting with code: ${MPIEXEC_CODE}"
    exit ${MPIEXEC_CODE}
}

runMpiexec() {

    echo "export I_MPI_PMI_EXTENSIONS=on"
    eval "export I_MPI_PMI_EXTENSIONS=on"

    # As a debug stage: echo the command line...

    echo \"${FULL_MPIEXEC}\" -comm=mpich2-pmi \
    \"${MDCE_MATLAB_EXE}\" ${MDCE_MATLAB_ARGS} 
    
    # ...and then execute it
    eval \"${FULL_MPIEXEC}\" -comm=mpich2-pmi \
    \"${MDCE_MATLAB_EXE}\" ${MDCE_MATLAB_ARGS}

    MPIEXEC_CODE=${?}
}

# Define the order in which we execute the stages defined above
MAIN() {
    trap "cleanupAndExit" 0 1 2 15
    chooseMachineArg
    runMpiexec
    exit ${MPIEXEC_CODE}
}

# Call the MAIN loop
MAIN
