#!/bin/bash
####################################################################################################
####################################################################################################
# Program name: Launcher                                                                           #
####################################################################################################
#                                                                                                  #
#                                                                                                  #
####################################################################################################
# Defining the environment variables                                                               #
####################################################################################################

# load environment variables
variables_env="$(dirname "$0")/env/variables.env"
constants_env="$(dirname "$0")/env/constants.env"
config_sh="$(dirname "$0")/env/config.sh"
phase_worker_sh="$(dirname "$0")/env/phase_worker.sh"


#Path to key pair
mkdir -p $(dirname "$0")/env/keys/
KEY_PATH="$(dirname "$0")/env/keys/"

# Log files
mkdir -p $(dirname "$0")/logs/
EXECUTION_LOG="$(dirname "$0")/logs/execution.log"
RESPONSE_LOG="$(dirname "$0")/logs/response.log"
VARIABLES_LOG="$(dirname "$0")/logs/created_resourses.log"

#Data files
USER_DATA_FILE_V1="$(dirname "$0")/basic_ack_test/scripts/user_data.sh"

# Phase scripts
PHASE_1_SCRIPT="$(dirname "$0")/env/phase1.sh"
PHASE_2_SCRIPT="$(dirname "$0")/env/phase2.sh"

####################################################################################################
# Loader
####################################################################################################
source "$(dirname "$0")/env/root.sh"
####################################################################################################
# End of Program Launcher
####################################################################################################