##################################################################################################################
# Root Script for the Launcher
##################################################################################################################

# load environment variables
source $variables_env

# load constants
source $constants_env

# load settings
source $config_sh

# Load phase worker
source $phase_worker_sh

# Setting the region
aws configure set region "$REGION"

echo -e "\n\n\n"

##################################################################################################################
# Main loop
##################################################################################################################

# This script continuously loops to execute all phases until manually stopped
main_launcher() {
    while true; do
        echo "############################################################################################################"
        echo "# Prompts to Execute Phases 1-5"
        echo "############################################################################################################"

        # Execute each phase
        execute_phase 1 "$PHASE_1_SCRIPT" "1st Instance Deployment" || continue
        log "$EXECUTION_LOG" "All phases have been processed."

        # Ask if the script should run again
        echo "############################################################################################################"
        echo "#                                        Clean Resources?                                                  #"
        echo "############################################################################################################"
        echo "# Type 'y' to proceed to Phase 2"
        echo "# Type 'n' to exit"
        echo "# [Press Enter to skip]"
        read -r -p "# User Input: " repeat
        echo "############################################################################################################"
        repeat="${repeat,,}"

        if [[ "$repeat" == "y" ]]; then
            execute_phase 2 "$PHASE_2_SCRIPT" "Resource Deletion"
            return 0
            read -r -p "# Press [Enter] to continue back to phase #1, or Type 'n' to exit the script" repeat           
            if [[ "$repeat" == "n" ]]; then
                log "$EXECUTION_LOG" "# Exiting the script." 
                break
            elif [[ -z "$repeat" ]]; then
                log "$EXECUTION_LOG" "# returning to phase 1."
            else
                echo "Invalid input. returning to phase 1."
            fi
        elif [[ "$repeat" == "n" ]]; then
            log "$EXECUTION_LOG" "# Exiting the script."
            break
        else
            echo "# Invalid input. Please enter 'y' or 'n' or press [Enter] to skip."
        fi
    done
}

# Run the main launcher
main_launcher
##################################################################################################################
# End of launcher.sh
##################################################################################################################