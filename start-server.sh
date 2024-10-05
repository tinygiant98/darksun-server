#!/bin/sh

# -----------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------
# Do not look at my code, it's a mess.  I'm working on it. It's ugly and doesn't like
# to be looked at.  Avert your eyes.  I'm sorry.  I'm so sorry.
# -----------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------

# Prerequisites
#  - If on a windows operating system, Git Bash must be used to run this script.
#  - If using loophole, you must create an account and log in before running this script.

export NWSYNC_PORT=8089
export NWN_PUBLICSERVER=1
DOCKER_PROFILES="nwserver:stable"
#  Set this variable to the nwnxee/nwserver image that the server will use. To use the
#  most current, use "stable", "preview" or "development".  Otherwise, select a
#  specific tag.  If the selected tag does not exist, the tag will default to
#  stable.
NWSERVER_DEFAULT_TAG="stable"
NWNXEE_DEFAULT_TAG="latest"

REPO_BRANCH_DEFAULT="master"

VERBOSE=false

VERSION=0.1.1

source nwstack/functions.sh

# The entire system relies on running several services in docker (for building images) and 
#  docker-compose (for running the resultant stack).  If docker, or docker desktop (for Windows), 
#  and docker-compose aren't installed, this system will not function correctly.
echo -e "\n${CY}Checking Docker installation...${NC}"

if ! command -v docker > /dev/null 2>&1; then
    echo -e "$ERROR Docker is not installed. Please install docker and try again."
    exit 1
else
    if ! docker info > /dev/null 2>&1; then
        case "$(uname -s)" in
            Linux*)     echo -e "$ERROR Docker is not running. Please start Docker using 'sudo systemctl start docker' or your preferred method, then try again." ;;
            Darwin*)    echo -e "$ERROR Docker is not running. Please start Docker Desktop from your Applications folder, then try again." ;;
            CYGWIN*|MINGW32*|MSYS*|MINGW*)
                        echo -e "$ERROR Docker Desktop is not running. Please start Docker Desktop from the Start menu or system tray, then try again." ;;
            *)          echo -e "$ERROR Docker is not running. Your operating system is not recognized, please start Docker manually, then try again." ;;
        esac
        exit 1
    fi
    echo -e "$SUCCESS Docker is installed and running."
fi

DOCKER_BUILDKIT=1

# Check to see if this stack is already running.  We have a handy-dandy temporary file
#  that stores the environment variables for the stack.  If this file exists, it means
#  the stack is *probably* running.  If the file doesn't exist, we don't have the info
#  necessary to check if the stack is running, so we'll just assume it isn't.
if [ -f "nwstack/nwstack_temp.env" ]; then
    source nwstack/nwstack_temp.env
    if [ -n "$(docker compose $(build_profiles) $services $SERVICES ps -q)" ]; then
        echo -e "$ERROR Docker stack already running."
        echo -e "$HINT Run ${CY}./stop-server.sh${NC} to stop the stack, or"
        echo -e "$HINT Run ${CY}./restart-server.sh${NC} to restart the stack."
        exit 1
    else
        unset $(grep -v '^#' nwstack/nwstack_temp.env | sed -E 's/(.*)=.*/\1/' | xargs)
        rm -f nwstack/nwstack_temp.env
    fi
fi


# TODO This will require lots of cleaning up.  Places after the nwstack_temp check because it
# resets all the values I need!  Dumbass.
export NWSYNC_PORT=8089
DOCKER_PROFILES="nwserver:stable"
NWSERVER_DEFAULT_TAG="stable"
NWNXEE_DEFAULT_TAG="latest"
REPO_BRANCH_DEFAULT="master"
VERBOSE=false

# This function displays the version of the NWStack shell script.  If the user passes
#  -v | --version, the script will display the version and exit, even if other command
#  line options are passed.
display_version() {
    echo "NWStack v$VERSION"
}

# This function displays helpful usage information if the user is unfamiliar with
#  this shell script.  It will display usage information if the user passes
#  -h | --help, or if the user starts the shell script without any parameters.
display_help() {
    echo "Minimum Requirements:"
    echo "  - config/nwserver.env must exist and contain environmental variables required for"
    echo "    the nwserver or nwnxee image to run.  The following environment variables may"
    echo "    optionally be included in nwserver.env:"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help                  Show usage message"
    echo "      --nwserver [tag]        Run the nwserver image with the specified tag. Cannot"
    echo "                              be used in conjuction with --nwnxee. [default: stable]"
    echo
    echo "      --nwnxee [tag]          Run the nwnx:ee image with the specified tag.  Cannot"
    echo "                              be used in conjuction with --nwserver. [default: latest]"
    echo
    echo "  -m, --module [file]         Specify the module file to use.  If not specified, the"
    echo "                              script will attempt to find the module file specified"
    echo "                              in the NWN_MODULE environmental variable in the"
    echo "                              config/nwserver.env file. [default: -]"
    echo
    echo "      --nwsync                Include an NGINX-based NWSYC server in the Docker stack"
    echo "      --loophole              Include a Loophole reverse proxy manager in the Docker stack"
    echo "      --profiling             Include a Grafana/InfluxDB stack for server profiling in the Docker stack"
    echo "      --db                    Include a database server in the Docker stack"
    echo "      --website               Include an NGINX-based website server in the Docker stack"
    echo "      --redis                 Include a Redis server in the Docker stack"
    echo "      --services [file...]    Include additional services as defined in custom docker-compose files."
    echo "                              [file] must be the full filename of a docker-compose file.  This file"
    echo "                              must be located in the config folder.  Multiple files should be separated"
    echo "                              by a space.  The file extension is optional, but if included, must be .yaml."
    echo "                              Services defined in these files will be added to the Docker stack"
    echo "                              and will take precedence over the default services. [default: -]"         
    echo
    echo "  -n, --updateNwsync          Prune/update or create the latest NWSYNC manifest"
    echo "      --manifest [sha1]       Specify the NWSYNC manifest hash to use [default: latest]"
    echo
    echo "  -d, --repoDir [dir]         Specify the directory containing the module repo [default: -]"
    echo "  -u, --repoUrl [url]         Specify the URL of the module repo.  This should be either full URL or"
    echo "                              the username/repo format.  If the URL is in the username/repo format,"
    echo "                              the script will assume the repo is located on github."
    echo
    echo "  -b, --repoBranch [branch]   Specify the branch of the module repo to use [default: master]"
    echo "  -t, --targets [target...]   Specify the nasher target(s) to build.  Multiple targets should be separated"
    echo "                              by a space. [default: all]"
    echo
    echo "      --verbose               Display detailed output during the build process"
    echo "  -v, --version               Display the NWStack version"
}

# This function allows the user to add, remove, or replace profiles in the DOCKER_PROFILES,
#  which is a comma-separated list of keys or key:value pairs that are used to build the docker stack.
modify_profiles() {
    local action=$1
    local item=$2
    local replace=$3
    local list=$DOCKER_PROFILES

    case $action in
        add)
            [[ $list =~ (^|,)$item(,|$) ]] || list+="${list:+,}$item"
            ;;
        remove)
            list=$(echo "$list" | sed -r "s/(^|,)$item(,|$)/\1/; s/,$//")
            ;;
        replace)
            local pattern="(^|,)$item(:[^,]*)?(,|$)"
            list=$(echo "$list" | sed -E "s/$pattern/\1$replace\3/g")
            if ! [[ "$list" =~ (^|,)$replace(,|$) ]]; then
                list+="${list:+,}$replace"
            fi
            ;;
        *)
            echo "Unknown action: $action"
            return 1
            ;;
    esac

    list=$(echo "$list" | sed 's/^,//;s/,$//')
    DOCKER_PROFILES=$list
}

# This function checks if a profile exists in the DOCKER_PROFILES list as a key or key:value pair.
has_profile() {
    local find=$1
    IFS=',' read -ra profiles <<< "$DOCKER_PROFILES"
    for p in "${profiles[@]}"; do
        IFS=':' read -r profile _ <<< "$p"
        if [[ "$profile" == "$find" ]]; then
            return 0
        fi
    done
    return 1
}

# This function returns the tag associated with a profile in the DOCKER_PROFILES list.  The tag is
#  the value in a key:value pair.
profile_tag() {
    local profile_list="$DOCKER_PROFILES"
    local search_profile=$1
    local IFS=','

    for item in $profile_list; do
        IFS=':' read -r profile tag <<< "$item"

        if [[ "$profile" == "$search_profile" ]]; then
            echo "$tag"
            return
        fi
    done
}

# This function stores an environment variable in a temporary file that can be sourced
#  later.  The environment variables stored in this file will be used by the start,
#  restart and stop scripts to determine the state of the stack and the options used.
#  This file should not be manually created, edited or deleted.
store_env() {
    local file="nwstack/nwstack_temp.env"
    local name="$1"
    local value="${!name}"

    if [ -z "$value" ]; then
        return
    fi

    if [ ! -f "$file" ]; then
        touch "$file"
    fi

    sed -i "/^export $name=/d" "$file"
    if [[ $value =~ ^[0-9]+$ ]]; then
        echo "export $name=$value" >> "$file"
    else
        echo "export $name=\"$value\"" >> "$file"
    fi
}

# These functions display a mostly unhelpful message about an error that occurred
#  during one of the command runs.  Its real purpose is to keep the shell screen open
#  long enough for the user to identify the error, which should be listed by the
#  process that caused the error.  This function will attempt to narrow down the
#  line number the error occurred on.
error_message() {
    local line=$1
    echo
    echo -e "${RD}A build error has occurred; see info above.${NC}"
    echo -e "$HINT Error occurred near line ${CY}$line${NC} in ${CY}$0${NC}"
    if [ "$VERBOSE" != true ]; then
        echo -e "$HINT Use the ${CY}--verbose${NC} flag to see more detailed output."
    fi
    echo -ne "${CY}Press Enter to exit the build process.${NC}"
    read
    exit 1
}

trap_error() {
    local line=$1
    error_message $line
}

trap 'error_message $LINENO' ERR

# If running in a windows environment, check that that user is utilizing Git Bash
#  to run this script to prevent unreported errors with some of the commands.
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    if [[ ! "$SHELL" =~ "bash" ]]; then
        echo -e "${YL}Please run this script using Git Bash on Windows.${NC}"
        exit 1
    fi
fi

# Now it's time to get into the real work.  We'll start by parsing the command line
#  options and parameters to determine how the user wants to build the stack.  This
#  section will provide some verification of user input as well as process message
#  to keep the user informed of the progress of the script.

echo -e "\n${CY}Checking command line options and parameters...${NC}"

if [ $# -eq 0 ]; then
    echo -e "$INFO No command line options passed."
    #echo -e "$HINT Usage information is displayed as a convenience; no error has occurred."
    #display_help
else
    while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            display_help
            exit 0 
            ;;
        --nwserver)
            shift
            if [[ "$1" =~ ^[^-]+ ]]; then
                TAG="$1"
                shift
            else
                TAG="stable"
            fi

            if [[ -n "$TAG" ]]; then
                IMAGE="urothis/nwserver"
                if ! docker images "$IMAGE" | awk '{print $2}' | grep -q "^$TAG$"; then
                    echo -e "$FAILURE ${CY}$IMAGE:$TAG${NC} not found locally."
                    if ! curl -s "https://hub.docker.com/v2/repositories/${IMAGE}/tags/${TAG}/" | grep -q '"name":'; then
                        echo -e "$FAILURE ${CY}$IMAGE:$TAG${NC} not found on dockerhub."
                        TAG="stable"
                    else
                        echo -e "$SUCCESS ${CY}$IMAGE:$TAG${NC} found on dockerhub."
                    fi
                else
                    echo -e "$SUCCESS ${CY}$IMAGE:$TAG${NC} found locally."
                fi
            fi

            echo -e "$INFO Setting nwserver image to ${CY}$IMAGE:$TAG${NC}"
            modify_profiles replace "nwnxee" "nwserver:$TAG"
            ;;
        --nwnxee)
            shift
            if [[ "$1" =~ ^[^-]+ ]]; then
                TAG="$1"
                shift
            else
                TAG="latest"
            fi

            if [[ -n "$TAG" ]]; then
                IMAGE="nwnxee/unified"
                if ! docker images "$IMAGE" | awk '{print $2}' | grep -q "^$TAG$"; then
                    echo -e "$FAILURE ${CY}$IMAGE:$TAG${NC} not found locally."
                    if ! curl -s "https://hub.docker.com/v2/repositories/${IMAGE}/tags/${TAG}/" | grep -q '"name":'; then
                        echo -e "$FAILURE ${CY}$IMAGE:$TAG${NC} not found on dockerhub."
                        TAG="stable"
                    else
                        echo -e "$SUCCESS ${CY}$IMAGE:$TAG${NC} found on dockerhub."
                    fi
                else
                    echo -e "$SUCCESS ${CY}$IMAGE:$TAG${NC} found locally."
                fi
            fi

            echo -e "$INFO Setting nwnxee image to ${CY}$IMAGE:$TAG${NC}"
            modify_profiles replace "nwserver" "nwnxee:$TAG"
            ;;
        -m|--module)
            if [[ -n "$2" && "$2" != -* ]]; then
                MODULE_FILENAME=$(basename "$2")
                shift 2
            fi ;;
        --nwsync|--loophole|--profiling|--db|--website|--redis)
            modify_profiles add "${1#--}"
            shift ;;
        --skipNwsync|--skipLoophole|--skipProfiling|--skipDb|--skipWebsite|--skipRedis)
            modify_profiles remove $(echo "${1#--skip}" | tr '[:upper:]' '[:lower:]')
            shift ;;
        -n|--updateNwsync)
            echo -e "$INFO NWSYNC manifest will be pruned and updated."
            modify_profiles add "nwsync"
            NWSYNC_UPDATE=true
            shift ;;
        -a|--buildAll)
            echo -e "$INFO All dockers images will be built from source."
            LOOPHOLE_BUILD=true
            TOOLS_BUILD=true
            SERVER_BUILD=true
            shift ;;
        -l|--buildLoophole)
            echo -e "$INFO Loophole reverse proxy manager will be built from source."
            LOOPHOLE_BUILD=true
            shift ;;
        -t|--buildTools)
            echo -e "$INFO Nasher and Neverwinter tools will be built from source."
            TOOLS_BUILD=true
            shift ;;
        -s|--buildServer)
            echo -e "$INFO NWNX:EE image will be built from source."
            SERVER_BUILD=true
            shift ;;
        -d|--repoDir)
            if [[ -n "$2" && "$2" != -* ]]; then
                REPO_DIR="$2"
                MODULE_BUILD=true
                shift 2
            fi ;;
        -u|--repoUrl)
            if [[ -n "$2" && "$2" != -* ]]; then
                REPO_URL="$2"

                if [[ "$REPO_URL" =~ ^[^/]+/[^/]+$ ]]; then
                    REPO_URL="https://github.com/$REPO_URL"
                fi

                if ! curl --output /dev/null --silent --head --fail "$REPO_URL"; then
                    echo -e "$ERROR Specified URL ${CY}$REPO_URL${NC} could not be found."
                    echo -e "$HINT Check that the URL is correct and accessible or remove the ${CY}--repoUrl${NC} option."
                    exit 1
                fi
       
                MODULE_BUILD=true
                shift 2
            fi ;;
        -b|--repoBranch)
            if [[ -n "$2" && "$2" != -* ]]; then
                REPO_BRANCH="$2"
                shift 2
            fi ;;
        --targets|--nasherTargets)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "$ERROR No targets specified for ${CY}$1${NC} option."
                echo -e "$HINT Include target names from nasher.cfg or ${CY}$1 all${NC} to build all targets."
                exit 1
            else
                TARGETS=""
                while [[ -n "$2" && "$2" != -* ]]; do
                    TARGETS="$TARGETS$2 "
                    shift
                done
                TARGETS="${TARGETS% }"
                echo -e "$INFO Nasher targets set to: ${CY}$TARGETS${NC}"
                shift
            fi ;;
        --services)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "$ERROR No files specified for ${CY}$1${NC} option."
                echo -e "$HINT Include the full filename of a docker-compose file without the extension."
                echo -e "$INFO The ${CY}$1${NC} option will be ignored for this build."
                shift
            else
                echo -e "$INFO Checking additional services files..."
                SERVICES=""
                while [[ -n "$2" && "$2" != -* ]]; do
                    FILE=${2%.yaml}yaml

                    if [ -f "config/$FILE" ]; then
                        if docker compose -f "config/$FILE" config >/dev/null 2>&1; then
                            if [[ ! "$SERVICES" =~ "$FILE" ]]; then
                                echo -e "$INFO Found and validated ${CY}$FILE${NC}"
                                SERVICES="$SERVICES -f $FILE "
                            else
                                echo -e "$INFO ${CY}$FILE${NC} already included in services list; skipping."
                            fi
                        else
                            echo -e "$ERROR File ${CY}$2${NC} is not a valid docker-compose file."
                            echo -e "$HINT Check that the file is a valid docker-compose file and try again."
                            if [ "$VERBOSE" != true ]; then
                                echo -e "$HINT Use the ${CY}--verbose${NC} flag to see more detailed output."
                            fi
                            exit 1
                        fi
                    else
                        echo -e "$ERROR File ${CY}$2${NC} not found in the ${CY}config${NC} folder."
                        echo -e "$HINT Check that the file exists in the ${CY}config${NC} folder and try again."
                        exit 1
                    fi

                    shift
                done
                SERVICES="${SERVICES% }"
                shift
            fi ;;
        --verbose)
            VERBOSE=true
            shift ;;
        --version)
            display_version; exit 1;;
        *) echo "Unknown parameter: $1"; display_help; exit 1 ;;
    esac
    
    unset TAG IMAGE FILE
    done
fi

# Default values are sourced from config/nwserver.env to limit the number of
#  locations builders need to edit values.  If this file doesn't exist, we'll have
#  multiple issues, so exit the script if it doesn't exist.
if [ -f "config/nwserver.env" ]; then
    source config/nwserver.env
else
    echo "$ERROR Required file ${CY}config/nwserver.env${NC} does not exist."
    exit 1
fi

# The module file doesn't have to exist, we just need to know what it is, or what it will be.
#  We don't check for existence because nasher might be building it.  If the user passed a module
#  filename via the --module flag, use that, otherwise, use the NWN_MODULE variable from the
#  nwserver.env file.  If the module doesn't exist when it comes time to run the server, the
#  process will exit without starting the server.
if [ -z "$MODULE_FILENAME" ]; then
    MODULE_FILENAME=$(basename "${NWN_MODULE%.*}")
    if [ -z "$MODULE_FILENAME" ]; then
        echo -e "$ERROR Could not determine module filename."
        echo -e "$HINT Check that the ${CY}NWN_MODULE${NC} variable is set in the ${CY}nwserver.env${NC} file, or"
        echo -e "$HINT pass module file via the ${CY}-m${NC} or ${CY}--module${NC} options."
        exit 1
    fi
fi

# This system uses a custom resource called dockerfile-tools to build an image that contains
#  the tools necessary to build a module from a git repository, including git, nasher and
#  neverwinter.  The user can optionally force building or rebuilding the image.  If the
#  images does not exist when it is needed, it will be built automatically.
TOOLS_IMAGE="nwstack/tools"
TOOLS_TAG=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${TOOLS_IMAGE}:" | awk -F: '{print $2}')
TOOLS_VERSION=$(docker run --rm "$TOOLS_IMAGE:${TOOLS_TAG:-0.0.0}" --version 2>/dev/null | awk '{print $2}')

if [ "$TOOLS_BUILD" = true ] || ([ "$MODULE_BUILD" = true ] && [ -z "$TOOLS_TAG" ]); then
    echo -e "$INFO Building Nasher and Neverwinter tools.  This could take a few minutes..."
    exec_cmd docker build \
        --build-arg NWSERVER_TAG="$NWSERVER_DEFAULT_TAG" \
        --build-arg GIT_USERNAME="$(git config --global user.name)" \
        --build-arg GIT_EMAIL="$(git config --global user.email)" \
        -t "$TOOLS_IMAGE:latest" -f nwstack/dockerfile-tools ./ > /dev/null #2>&1
    TOOLS_TAG="latest"
    echo -e "$SUCCESS Nasher and Neverwinter tools built."
    echo -e "$INFO Nasher and Neverwinter tools tag is ${CY}$TOOLS_TAG${NC}"
fi

# This system can build a module from a git repository if the repository is a nasher project.
#  If the user has opted not to build the module, we only check to see if the module file exists
#  and make no attempt to build it.  If the user opts to build the module, we run a ridiculous
#  number of checks to ensure the module can be built, including checking for the existence of
#  the module file, the repository directory, the repository URL, and the repository branch, if
#  those values were specified by the user.  To build a module, either a repository directory or
#  a repository URL must be specified.
if [ "$MODULE_BUILD" != true ]; then
    echo -e "$INFO Attempting to find module file..."
    if [ -f "modules/$MODULE_FILENAME.mod" ]; then
        echo -e "$SUCCESS Module file ${CY}$MODULE_FILENAME.mod${NC} found."
    else
        echo -e "$ERROR Module file ${CY}$MODULE_FILENAME.mod${NC} not found."
        echo -e "$HINT Check that the module file exists in the ${CY}modules${NC} folder, or"
        echo -e "$HINT Specify the repo dir with the ${CY}--repoDir${NC} option, or"
        echo -e "$HINT Specify the repo URL with the ${CY}--repoUrl${NC} option."
        exit 1
    fi
else
    echo -e "$INFO Attempting to build module file..."

    # Determine the folder the repo either currently exists in, should exist in, or will be
    #  cloned into.
    REPO_DIR=${REPO_DIR:-$(echo ${REPO_URL##*/})}
    REPO_DIR=$(readlink -f "$REPO_DIR")
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        REPO_DIR=$(cygpath -w "$REPO_DIR")
    fi

    # If the user has specified a repo URL, we need to know the branch to check out.  Generally
    #  this will be master, but the user can specify a different branch.
    if [ -n "$REPO_URL" ]; then
        REPO_BRANCH=${REPO_BRANCH:-$REPO_BRANCH_DEFAULT}
    fi

    if [ -n "$REPO_DIR" ]; then
        REPO_ECHO=${CY}"$(echo $REPO_DIR | sed 's/\\/\//g')"${NC}
        echo -e "$INFO Repo directory is $REPO_ECHO"
    else
        echo -e "$INFO Repo directory not specified."
    fi

    if [ -n "$REPO_URL" ]; then
        echo -e "$INFO Repo URL is ${CY}$REPO_URL${NC}"
        echo -e "$INFO Repo branch is ${CY}$REPO_BRANCH${NC}"
    else
        echo -e "$INFO Repo URL not specified."
    fi

    # First, we check if the specified repo directory exists.  If it doesn't, or the user didn't
    #  pass a repo directory, then we check if the user provided a repo URL.  If that wasn't provided,
    #  we probably shouldn't even be in the part of the code, but just in case, we'll attempt to
    #  revert to simply finding an already-existing module file.
    if { [[ -n "$REPO_DIR" && ! -d "$REPO_DIR" ]] || [ -z "$REPO_DIR" ]; }; then
        if [ -z "$REPO_URL" ]; then
            echo -e "$ERROR Repo directory ${CY}$REPO_DIR${NC} not found and repo url not specified."
            if [ -f "modules/$MODULE_FILENAME.mod" ]; then
                echo -e "$INFO Using existing module file ${CY}$MODULE_FILENAME.mod${NC}"
            else
                echo -e "$ERROR Module file ${CY}$MODULE_FILENAME.mod${NC} not found."
                echo -e "$HINT Check that the module file exists in the ${CY}modules${NC} folder, or"
                echo -e "$HINT Specify the repo directory with the ${CY}--repoDir${NC} option, or"
                echo -e "$HINT Specify the repo URL with the ${CY}--repoUrl${NC} option."
                exit 1
            fi
        elif [ -n "$REPO_URL" ]; then
            echo -e "$INFO Cloning repo from ${CY}$REPO_URL${NC} into ${CY}$REPO_DIR${NC}..."
            exec_cmd docker run --entrypoint sh --rm \
                -v "$REPO_DIR:/nasher" \
                $TOOLS_IMAGE:$TOOLS_TAG -c "git clone -b $REPO_BRANCH $REPO_URL $REPO_DIR"
            BUILD=true
        fi
    # Next, if the repo directory already exists, we check if it is a nasher project and
    #  attempt to build it if we have all the required resources.
    elif [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ]; then
        if [ -f "$REPO_DIR/nasher.cfg" ]; then
            echo -e "$INFO Found a nasher project at $REPO_ECHO"
            REMOTE=$(exec_cmd docker run --entrypoint sh --rm \
                -v "$REPO_DIR:/nasher" \
                $TOOLS_IMAGE:$TOOLS_TAG -c "git remote get-url origin")
            # If the repo directory is a git repo, and the remote matches the specified repo URL,
            #  it's probably a good assumption that we're in the right place, so pull any updates
            #  from the remote and check out the specified branch.
            if [ -d "$REPO_DIR/.git" ] && [ -n "$REPO_URL" ]; then
                if [ "$REMOTE" = "$REPO_URL" ]; then
                    echo -e "$INFO Updating module repo from remote..."
                    exec_cmd docker run --entrypoint sh --rm \
                        -v "$REPO_DIR:/nasher" \
                        $TOOLS_IMAGE:$TOOLS_TAG -c "git pull origin $REPO_BRANCH && git checkout $REPO_BRANCH"
                    echo -e "$SUCCESS Module repo updated; ${CY}$REPO_BRANCH${NC} checked out."
                    BUILD=true
                # If the remote doesn't match the specified URL, give the user the option to replace
                #  the existing repo with the specified repo.
                else
                    echo -e "$INFO Project repo's remote ($REMOTE) does not match specified repo URL ($REPO_URL)."
                    echo -e "$INFO You can delete the exising repo and clone the new one.  All files in $REPO_ECHO will be deleted."
                    echo -ne "$PROMPT Do you want to replace the project in $REPO_ECHO with the repo at ${CY}$REPO_URL${NC}? (y/n) [y]: "
                    read USER_INPUT
                    if [ "${USER_INPUT:-y}" = "y" ]; then
                        rm -rf "$REPO_DIR/*"
                        echo -e "$INFO Cloning repo from ${CY}$REPO_URL${NC} into $REPO_ECHO..."
                        exec_cmd docker run --entrypoint sh --rm \
                            -v "$REPO_DIR:/nasher" \
                            $TOOLS_IMAGE:$TOOLS_TAG -c "git clone -b $REPO_BRANCH $REPO_URL $REPO_DIR"
                        BUILD=true
                    fi
                fi
            # If we're here, then the repo directory is a nasher project, but the user didn't specify
            #  a repo URL, so we'll update the repo from the existing remote and check out the specified
            #  branch.
            elif [ -z "$REPO_URL" ]; then
                echo -e "$INFO Nasher project found at $REPO_ECHO with remote at ${CY}$REMOTE${NC}"
                echo -ne "$PROMPT Do you want to update (git pull) this repo from remote? (y/n) [y]: "
                read USER_INPUT
                if [ "${USER_INPUT:-y}" = "y" ]; then
                    echo -e "$INFO Updating module repo from remote..."
                    exec_cmd docker run --entrypoint sh --rm \
                        -v "$REPO_DIR:/nasher" \
                        $TOOLS_IMAGE:$TOOLS_TAG -c "git pull origin $REPO_BRANCH && git checkout $REPO_BRANCH"
                    echo -e "$SUCCESS Module repo updated; ${CY}$REPO_BRANCH${NC} checked out."
                    BUILD=true
                else
                    BUILD=true
                fi
            # If we're here, then the repo directory is a nasher project, and the user did specify
            #  a repo URL
            # TODO is this right, should this just be build what it finds here instead of cloning?
            # TODO or maybe this should be an option to clone, or to use current?
            elif [ -n "$REPO_URL" ]; then
                echo -e "$INFO No git repo found in $REPO_ECHO; cloning repo from ${CY}$REPO_URL${NC}..."
                exec_cmd docker run --entrypoint sh --rm \
                    -v "$REPO_DIR:/nasher" \
                    $TOOLS_IMAGE:$TOOLS_TAG -c "git clone -b $REPO_BRANCH $REPO_URL $REPO_DIR"
                BUILD=true
            else
                BUILD=true
            fi
        fi
    fi

    # After all that, build the module if we found the correct nasher project.
    if [ "$BUILD" = true ]; then
        TARGETS=${TARGETS:-all}
        exec_cmd docker run --entrypoint sh --rm \
            -v "/$(pwd):/nasher" \
            $TOOLS_IMAGE:$TOOLS_TAG -c "cd /nasher/$(basename "$REPO_DIR") && nasher pack $TARGETS --yes --clean"
         
        if [ -f "modules/$MODULE_FILENAME.mod" ]; then
            echo -e "$SUCCESS Module file ${CY}$MODULE_FILENAME.mod${NC} exists."
        else
            echo -e "$ERROR Module file ${CY}$MODULE_FILENAME.mod${NC} could not be found."
            exit 1
        fi
    fi
    unset USER_INPUT
fi

# One of the primary purposes this project exists is to easily integrate NWSYNC into a docker
#  stack running on the same machine as the game server.  If the user has opted to run NWSYNC
#  in the stack, this section will ensure a usable manifest exists and optionally prune and
#  update the manifest.
if has_profile "nwsync"; then 
    echo -e "\n${CY}Checking NWSYNC tools and manifest...${NC}"

    if [[ "$NWSYNC_UPDATE" == true ]]; then
        echo -e "$INFO Pruning latest NWSYNC manifest..."
        exec_cmd docker run --entrypoint nwn_nwsync_prune --rm \
            -v "/$(pwd)/nwsync:/nwsync" $TOOLS_IMAGE:$TOOLS_TAG ./nwsync
        echo -e "$SUCCESS NWSYNC manifest pruning complete."

        echo -e "$INFO Updating latest NWSYNC manifest..."
        MSYS_NO_PATHCONV=1 exec_cmd docker run --entrypoint nwn_nwsync_write --rm \
            -v "/$(pwd)/nwsync:/nwsync" \
            -v "/$(pwd)/modules:/nasher/install/modules" \
            -v "/$(pwd)/hak:/nasher/install/hak" \
            -v "/$(pwd)/tlk:/nasher/install/tlk" \
            --user root \
            --workdir / \
            $TOOLS_IMAGE:$TOOLS_TAG ./nwsync "/nasher/install/modules/$MODULE_FILENAME.mod" \
            -p "/nasher/install/hak" \
            -p "/nasher/install/tlk"
        echo -e "$SUCCESS NWSYNC manifest updated."
    fi

    if [ -f "nwsync/latest" ]; then
        export NWN_NWSYNCHASH=$(cat nwsync/latest) && store_env "NWN_NWSYNCHASH"
        echo -e "$INFO Latest NWSYNC manifest is ${CY}${NWN_NWSYNCHASH}${NC}"
    else
        echo -e "$FAILURE ${YL}Latest NWSYNC manifest not found; nwsync will not be started.${NC}"
        echo -e "$INFO NWSYNC will not be available in the Docker stack."
        echo -e "$HINT Run the script with the ${CY}--updateNwsync${NC} flag to update the manifest."
        echo -e "$HINT Players may not be able to login if hak files are required."
        modify_profiles remove "nwsync"
    fi
fi

# One of the challenges that exists when running docker on a Windows-based server, or, really,
#  any home-based server that might sit behind a firewall or router, is exposing the server to
#  the internet.  This is where Loophole comes in.  Loophole is a reverse proxy utility that
#  allows local resources to be exposed to the internet securely.  Additionally, the service
#  can optionally provide customized domain names, which will route directly to the exposed
#  resource when called.  This tool makes setting up and exposing nwserver and nwsync servers
#  exceptionally easy.
if has_profile "loophole"; then
    echo -e "\n${CY}Checking Loophole reverse proxy manager...${NC}"

    case "$(uname -s)" in
        Linux* | Darwin*) HOME_PATH="$HOME";;
        CYGWIN* | MINGW* | MSYS*) HOME_PATH=$(echo $USERPROFILE);;
        *) echo -e "$ERROR Unable to determine operating system; exiting"; exit 1;;
    esac

    export LOOPHOLE_IMAGE="nwstack/loophole" && store_env "LOOPHOLE_IMAGE"
    export LOOPHOLE_TAG=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${LOOPHOLE_IMAGE}:" | awk -F: '{print $2}') \
        && store_env "LOOPHOLE_TAG"

    if [ -z "$LOOPHOLE_TAG" ] || [ "$LOOPHOLE_BUILD" = true ]; then
        echo -e "$INFO Building Loophole reverse proxy manager..."
        exec_cmd docker build -t "$LOOPHOLE_IMAGE:latest" -f ./nwstack/dockerfile-loophole ./
        LOOPHOLE_TAG="latest"
        echo -e "$SUCCESS Loophole reverse proxy manager built."
    fi

    echo -e "$INFO Loophole reverse proxy manager tag is ${CY}$LOOPHOLE_TAG${NC}"

    if MSYS_NO_PATHCONV=1 docker run --rm \
        -v ${HOME_PATH}/.loophole:/root/.loophole \
        "$LOOPHOLE_IMAGE:$LOOPHOLE_TAG" account login 2>&1 | grep -q "Already logged in"; then
        echo -e "$INFO Logged in to Loophole account."
    else
        echo -e "$ERROR Not logged in to Loophole account."
        echo -e "$HINT Must be logged into Loophole account to continue"
        if [ "$VERBOSE" = true ]; then
            echo -e "$HINT To log in, follow instructions below."
            docker run --rm "$LOOPHOLE_IMAGE":"$LOOPHOLE_TAG" account login
            read -p "Press Enter to continue..."
        fi
        exit 1
    fi
fi

# We're at the point where we can setup either nwserver or nwnxee, depending on the user's
#  preference.  This function allows either nwserver or nwnxee to be setup as the primary method to
#  run the server.  If will check that the required or specified image exists and, if not, pull the
#  image from dockerhub.
setup_server() {
    local profile=$1
    local image=$2
    local default=$3

    echo -e "\n${CY}Checking $profile image...${NC}"

    local current=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${image}:" | awk -F: '{print $2}' | head -n 1)
    local desired=$(profile_tag "$profile")
    local latest=$(curl -s "https://api.github.com/repos/$image/releases/latest" | grep '"tag_name":' | head -1 | cut -d '"' -f 4)
    
    if { [ -z "$current" ] && { [ -n "$latest" ] || [ -n "$desired" ]; }; } || [ "$SERVER_BUILD" = true ]; then
        echo -e "$INFO Pulling $profile docker image..."
        current="${desired:-$latest}"
        exec_cmd docker pull "$image:$current"
        echo -e "$SUCCESS $profile docker image pulled."
    elif [ "$latest" != "$current" ] && [ -n "$latest" ] && [ -z "$desired" ]; then
        echo -e "$INFO $profile docker image update available: ${CY}$current${NC} -> ${CY}$latest${NC}"
        echo -ne "$PROMPT Do you want to update $image? (y/n) [y]: "
        read USER_INPUT
        if [ "${USER_INPUT:-y}" = "y" ]; then
            echo -e "$INFO Updating $profile to $latest..."
            exec_cmd docker pull "$image:$latest"
            current=$latest
            echo -e "$SUCCESS NWServer update complete."
        fi
        unset USER_INPUT
    fi

    echo -e "$INFO $image tag is ${CY}$current${NC}"
}

if has_profile "nwnxee"; then
    SERVER_BUILD=$NWNXEE_BUILD
    setup_server "nwnxee" "nwnxee/unified" "latest"
elif has_profile "nwserver"; then
    SERVER_BUILD=$NWSERVER_BUILD
    setup_server "nwserver" "urothis/nwserver" "stable"
else
    echo -e "\n${YL}Skipping NWNX:EE and nwserver images.${NC}"
    echo -e "$INFO NWNX:EE and nwserver Docker containers will not be started."
    echo -e "$INFO PROFILES = ${CY}$DOCKER_PROFILES${NC}"
    exit 1
fi

# Finally, we can start the docker stack.  We need to deconstruct the DOCKER_PROFILES variable to
#  determine what services and images the user wants to run.  The environmental variables will be
#  stored for later use in restarting or stopping the stack.  
IFS=',' read -ra kvps <<< "$DOCKER_PROFILES"
services="-f docker-compose.yaml"
for kvp in "${kvps[@]}"; do
    if [[ "$kvp" == *":"* ]]; then
        key="${kvp%%:*}"
        value="${kvp##*:}"
    else
        key="$kvp"
    fi
    
    FAIL=false
    case "$key" in
        nwserver)
            export NWSERVER_IMAGE="urothis/nwserver" && store_env "NWSERVER_IMAGE"
            export NWSERVER_TAG="$value" && store_env "NWSERVER_TAG"
            modify_profiles replace "nwserver" "nwserver"
            ;;
        nwnxee)
            export NWSERVER_IMAGE="nwnxee/unified" && store_env "NWSERVER_IMAGE"
            export NWSERVER_TAG="$value" && store_env "NWSERVER_TAG"
            modify_profiles replace "nwnxee" "nwnxee"
            ;;
        nwsync)
            if [ -z "$NWN_NWSYNCHASH" ] || [ -z "$NWN_NWSYNCHOST" ] || [ -z "$NWSYNC_PORT" ]; then
                echo -e "${CY}NWSYNC profile issues:${NC}"
                if [ -z "$NWN_NWSYNCHASH" ]; then
                    echo -e "$ERROR NWSYNC does not have a manifest."
                    echo -e "$HINT Run the script with the ${CY}--updateNwsync${NC} flag to update the manifest, or"
                    echo -e "$HINT Set the ${CY}NWN_NWSYNCHASH${NC} variable in the ${CY}nwserver.env${NC} file."
                fi

                if [ -z "$NWN_NWSYNCHOST" ]; then
                    echo -e "$ERROR NWSYNC host domain has not been set."
                    echo -e "$HINT Set the ${CY}NWN_NWSYNCHOST${NC} Fvariable in the ${CY}nwserver.env${NC} file."
                fi

                if [ -z "$NWSYNC_PORT" ]; then
                    echo -e "$ERROR NWSYNC port has not been set."
                    echo -e "$HINT Internal Error."
                fi

                FAIL=true
            else
                services="$services -f nwstack/docker-compose."$key".yaml "
                export NWN_NWSYNCHASH && store_env "NWN_NWSYNCHASH"
                export NWN_NWSYNCHOST && store_env "NWN_NWSYNCHOST"
                export NWSYNC_PORT && store_env "NWSYNC_PORT"
            fi
            ;;
        loophole)
            if [ -z "$NWN_NWSYNCHOST" ] || [ -z "$NWSYNC_PORT" ]; then
                echo -e "${CY}Loophole profile issues:${NC}"
                if [ -z "$NWN_NWSYNCHOST" ]; then
                    echo -e "$ERROR NWSYNC host domain has not been set."
                    echo -e "$HINT Set the ${CY}NWN_NWSYNCHOST${NC} variable in the ${CY}nwserver.env${NC} file."
                fi

                if [ -z "$NWSYNC_PORT" ]; then
                    echo -e "$ERROR NWSYNC port has not been set."
                    echo -e "$HINT Internal Error."
                fi

                FAIL=true
            else
                services="$services -f nwstack/docker-compose.$(echo "$key" | sed 's/\.*$//').yaml "
                export NWN_NWSYNCHOST && store_env "NWN_NWSYNCHOST"
                export NWSYNC_PORT && store_env "NWSYNC_PORT"
                export NWN_NWSYNCURL="https://${NWN_NWSYNCHOST}.loophole.site" && store_env "NWN_NWSYNCURL"
            fi
            ;;
        db|profiling|redis|website)
            services="$services -f nwstack/docker-compose.$key.yaml "
            ;;
        *)
            echo -e "$ERROR Unknown profile: $profile"
            exit 1
            ;;
    esac

    # This is our last chance to exit the script before starting the stack.
    [ "$FAIL" = true ] && exit 1
    services="${services% }"
done

store_env "services"
store_env "DOCKER_PROFILES"
store_env "SERVICES"
store_env "VERBOSE"

echo -e "\n${CY}All prerequisites met, let's play!${NC}"
echo -e "$INFO Starting Docker stack..."
exec_cmd docker compose $(build_profiles) $services $SERVICES up -d

if [ -n "$(docker compose $(build_profiles) $services $SERVICES ps -q)" ]; then
    echo -e "$SUCCESS Docker stack started."
else
    echo -e "$ERROR Docker stack failed to start."
fi
