#!/bin/bash

source nwstack/functions.sh

#RD='\033[0;31m'
#GN='\033[0;32m'
#YL='\033[0;33m'
#BL='\033[0;34m'
#CY='\033[0;36m'
#PR='\033[0;35m'
#NC='\033[0m'
#
#INFO="${BL}     INFO:${NC}"
#SUCCESS="${GN}  SUCCESS:${NC}"
#FAILURE="${RD}  FAILURE:${NC}"
#ERROR="${RD}    ERROR:${NC}"
#HINT="${YL}     HINT:${NC}"
#PROMPT="${PR}   PROMPT:${NC}"
#
#exec_cmd() {
#    [ "$VERBOSE" = true ] && "$@" || "$@" > /dev/null 2>&1; 
#}
#
#build_profiles() {
#    local profile_list=""
#
#    IFS=',' read -ra profiles <<< "$DOCKER_PROFILES"
#    for profile in "${profiles[@]}"; do
#        profile_list="$profile_list --profile $profile"
#    done
#
#    echo "$profile_list"
#}

# If running in a windows environment, check that that user is utilizing Git Bash
#  to run this script to prevent unreported errors with some of the commands.
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    if [[ ! "$SHELL" =~ "bash" ]]; then
        echo "Please run this script using Git Bash on Windows."
        exit 1
    fi
fi

# TODO chekc for docker, not docker-compose!
#if ! command -v docker-compose &> /dev/null
#then
#	echo "docker-compose could not be found. Please install it and try again."
#	exit 1
#fi
#
#if [ ! -f "./docker-compose.yaml" ]; then
#	echo "docker-compose.yaml file does not exist in the current directory."
#	exit 1
#fi

# The docker stack requires several environmental variables to successfully run
#  the stack.  Some of these variables are contained within config/nwserver.env
#  and others are saved in the temporary file nwstack/nwstack_temp.env.  If
#  either of these files do not exist, this script is useless and will exit early.
if [ -f "config/nwserver.env" ]; then
    source config/nwserver.env
else
    echo "$ERROR Required file ${CY}config/nwserver.env${NC} does not exist."
    echo "$HINT You must manually remove the containers and networks created by the server."
    exit 1
fi

if [ -f "nwstack/nwstack_temp.env" ]; then
    source nwstack/nwstack_temp.env
else
    echo "$ERROR Required file ${CY}nwstack/nwstack_temp.env${NC} does not exist."
    echo "$HINT You must manually remove the containers and networks created by the server."
    exit 1
fi

# Time to take the stack down.  After running docker-compose down, we'll run a ps
#  command to check if any of the containers are still running.  If they are,
#  the user will have to manually stop the processes.
echo -e "\n${CY}Attempting to take down docker stack...${NC}"
exec_cmd docker compose $(build_profiles) $services $SERVICES down -v

if [ -z "$(docker compose $(build_profiles) $services $SERVICES ps -q)" ]; then
    echo -e "$SUCCESS Docker stack has stopped."
    echo -e "$HINT Run ${CY}./start-server.sh${NC} to start the stack."
else
    echo -e "$FAILURE Docker stack failed to stop."
    exit 1
fi

# The nwstack/nwstack_temp.env file is only required while the docker stack is
#  running, so time to get rid of that file.  If the file is not removed, there
#  are no negative side effects, but this will help keep the directory clean.
# If the docker stack failed to stop, the user can optionally manually delete
#  nwstack/nwstack_temp.env, but it not required to do so.
echo -e "\n${CY}Attempting to remove temporary environment file...${NC}"

rm -f nwstack/nwstack_temp.env

if [ ! -f "nwstack/nwstack_temp.env" ]; then
    echo -e "$SUCCESS Temporary environment file has been removed."
else
    echo -e "$FAILURE Failed to remove temporary environment file."
fi
