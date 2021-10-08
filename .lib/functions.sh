#!/bin/sh

# Open a new terminal
function term () {
	# If macos then use open command
	if [[ $(uname -s) =~ "Darwin" ]]; then
		open -a Terminal .
	# If gnome then use gnome command
	elif [[ ${XDG_CURRENT_DESKTOP} =~ "GNOME" ]]; then
		gnome-terminal
	fi
}

# Open the graphical files explorer 
function open-files {
    dir=$1
    [[ -z $dir ]] && dir='.'

    # If it's macOS
	if [[ $(uname -s) =~ "Darwin" ]]; then
		open $dir
    # If it's gnome
	elif [[ ${XDG_CURRENT_DESKTOP} =~ "GNOME" ]]; then
		xdg-open $dir
	fi
	unset dir;
}

# Ping tcp ports 
function ping-tcp {
    # $1 = host, $2 = port
    echo > /dev/tcp/$1/$2 && echo "$1:$2 is open."
}

# Ping udp ports
function ping-udp {
    # $1 = host, $2 = port
    echo > /dev/udp/$1/$2 && echo "$1:$2 is open."
}

# Create a new python project using scaffolding templates
function scaffold-python-project {
	python3 ${HOME}/.bin/python_scaffolding.py
}

# A simple watch command replacement. It runs in the current shell 
# so all the aliases and sourced scripts are available.
function sw {
    local __usage="sw -n <interval-in-sec> command"

    # If there is no argument provided, show usage and return
    if [[ $# -le 1 ]]; then
        echo $__usage
        return
    fi

    # Load the command line parameters into variables                               
    while [ $# -gt 1 ]; do
        case $1 in
            -n)
                shift
                local __watch_interval=$1
                shift
           	    ;;
            *)
                break
                ;;
      esac
    done

    # If the command is empty show usage and return
    if [[ -z $1 ]]; then
        echo $__usage
        return 
    fi

    # Run the given command in indefinite loop until user stops the process
    while true; do
        clear
        echo -e "$(date)\tRunning every ${__watch_interval} seconds."
        echo "---"
        eval "$@"
        sleep ${__watch_interval}
    done
}

#################################
# AWS related functions.
#################################

# Get credentials for MFA enabled authentication
function aws-sts-session-token {
    # Validate the input variables
    mfa_serial_number=$1 #"arn:aws:iam::account_id:mfa/user_name"
    [[ -z "$mfa_serial_number" ]] && echo "mfa_serial_number is missing" \
        && return

    # Reset the environment variables
    export AWS_ACCESS_KEY_ID=
    export AWS_SECRET_ACCESS_KEY=
    export AWS_SESSION_TOKEN=

    # Get the session duration and convert it to seconds
    printf "Enter the session duration in hours [default is 1]: "; read duration
    [ -z "$duration" ] && duration=1
    duration_seconds=$(($duration*3600))

    # Get the code and sts token
    printf "Enter the MFA code: "; read token_code

    # Get the credential
    credentials=$(aws sts get-session-token \
        --duration-seconds ${duration_seconds} \
        --serial-number ${mfa_serial_number} \
        --token-code ${token_code} \
        --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
        --output text \
    )

    # Replace tabs (if there is any) to space, and then split the string by spaces.
    export AWS_ACCESS_KEY_ID=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f1)
    export AWS_SECRET_ACCESS_KEY=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f2)
    export AWS_SESSION_TOKEN=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f3)

    unset credentials mfa_serial_number token_code duration duration_seconds
}

# Assume the given role and return credentials
function aws-sts-assume-role {
	# Input variables
	role_arn=$1 #"arn:aws:iam::trusting_account_id:role/role_name"
	mfa_serial_number=$2 #"arn:aws:iam::trusted_account_id:mfa/myuser"

	[[ -z $role_arn ]] && echo "role arn is missing" && return
	[[ -n $mfa_serial_number ]] && __mfa_enabled=true

	# Reset the environment variables
	export AWS_ACCESS_KEY_ID=
	export AWS_SECRET_ACCESS_KEY=
	export AWS_SESSION_TOKEN=
	export AWS_ACCOUNT_ID=

	# Get the caller identity before assume role
	aws sts get-caller-identity

	# Get the session duration and convert it to seconds
	printf "Enter the session duration in hours [default is 1]: "; read duration
	[ -z "$duration" ] && duration=1
	duration_seconds=$(($duration*3600))

	# Get the code and sts token
	if [[ ${__mfa_enabled} ]]; then
		printf "Enter the MFA code: "; read token_code
	fi

	# Get the credential
	if [[ ${__mfa_enabled} ]]; then
		credentials=$(aws sts assume-role \
		--role-arn ${role_arn} \
		--role-session-name $(date '+%Y%m%d%H%M%S%3N') \
		--duration-seconds ${duration_seconds} \
		--serial-number ${mfa_serial_number} \
		--query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
		--output text \
		--token-code ${token_code} \
		)
	else
		credentials=$(aws sts assume-role \
		--role-arn ${role_arn} \
		--role-session-name $(date '+%Y%m%d%H%M%S%3N') \
		--duration-seconds ${duration_seconds} \
		--query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
		--output text \
		)
	fi

	# Replace tabs (if there is any) to space, and then split the string by spaces.
	export AWS_ACCESS_KEY_ID=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f1)
	export AWS_SECRET_ACCESS_KEY=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f2)
	export AWS_SESSION_TOKEN=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f3)
	export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)

	# get caller identity after the assume role
	aws sts get-caller-identity

	unset credentials
	unset mfa_serial_number
	unset role_arn
	unset __mfa_enabled
	unset token_code
	unset duration
	unset duration_seconds
}

function aws-sts-session-token-current-user {
    aws-sts-session-token ${AWS_MFA_SERIAL_NUMBER}
}

function aws-user-elevate-to-poweruser {
    aws iam add-user-to-group --user-name $1 --group-name PowerUsers
}

function aws-user-elevate-to-readonly {
    aws iam add-user-to-group --user-name $1 --group-name ReadOnlyUsers
}

function aws-user-elevate-to-admin {
    aws iam add-user-to-group --user-name $1 --group-name Admins
}

function aws-list-env-variables {
    echo AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
	echo AWS_REGION=$AWS_REGION
	echo AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
    echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
    echo AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN
}


# sync workspace directory to the workspace bucket in s3
function s3-upload-ws {
    aws s3 sync ${WORKSPACE} s3://${S3_WS_BUCKET}/ \
        --exclude '*.git/*' \
        --exclude '*.env/*' \
		--exclude '.DS_Store' \
        --delete
}

function s3-upload {
	aws s3 cp $1 s3://${S3_WS_BUCKET}
}

function s3-ls {
	aws s3 ls s3://${S3_WS_BUCKET}
}

function s3-download {
	[[ -z $1 || -z $2 ]] \
		&& echo "Usage: s3-download <source> <destination>" \
		&& return

	aws s3 sync s3://${S3_WS_BUCKET}/$1 $2
}


#################################
# git related functions
#################################

# Creates patch files from the current git repository and save them into an S3
# bucket. It can download, upload and delete patches from the bucket.
function git-patch {
    # Validations
    if [[ -z $1 ]]; then
        echo "Usage: git-patch <save|load|clean>" && return
    fi

    declare -a __actions=(save load clean)
    for __available_action in "${__actions[@]}"; do
        [[ "$__available_action" == "$1" ]] && __action=$1
    done

    [[ -z ${__action} ]] && echo "action is not provided or valid" && return
    [[ -z ${S3_PATCHES_BUCKET} ]] && echo "S3_PATCHES_BUCKET is not set" \
        && return

    # Set the repo_name based on the origin url
    __repo_name=$(git config --get remote.origin.url | sed -e "s/:/_/g" | sed -e "s/\//_/g")
    __patch_prefix=${__repo_name}

    if [[ $__action == "save" ]]; then
        __patch_file=$(date +"%y%m%d_%H%M")

        # Compare the commit id of origin and local head, if they don't match
        # apply the soft reset to make the local committed-changes visible in
        # the staged state.

        # Find the commit number which remote origin is pointing to
        __origin_repo=origin/$(git branch --show-current)
        __origin_head=$(git log --oneline ${__origin_repo} | awk 'NR==1 {print $1}')

        # Find the commit number of the local head
        __local_head=$(git log --oneline | awk 'NR==1 {print $1}')

        if [[ ${__origin_head} == ${__local_head} ]]; then
            echo "Remote ${__origin_repo} and local head are the same"
        else
            # if local head is different, then local repo has local commits
            # Do the soft reset to get the all changes between local and remote
            echo -e "\e[32mRemote origin and local heads are different." \
                 "Soft reseting...\e[0m"
            git reset --soft ${__origin_head}
        fi

        # if there is any staged changes, save them to a file
        if [[ -n $(git diff --staged) ]]; then
            git diff --staged > ${__patch_file}.patch \
            && echo "patched to ${__patch_file}.patch"
        fi

        # If there is any file which is in the unstaged mode, pick them up too
        if [[ -n $(git diff) ]]; then
            git diff > ${__patch_file}_unstaged.patch \
            && echo "patched to ${__patch_file}_unstaged.patch"
        fi
    fi

    # Based on the action, upload, download or delete files from the S3 bucket
    case $__action in
        save)
            aws s3 cp . s3://${S3_PATCHES_BUCKET}/${__patch_prefix}/ \
                --recursive --exclude "*" --include "${__patch_file}*.patch"
            rm ${__patch_file}*.patch
            ;;
        load)
            aws s3 cp s3://${S3_PATCHES_BUCKET}/${__patch_prefix}/ . \
                --recursive
            ;;
        clean)
            aws s3 rm s3://${S3_PATCHES_BUCKET}/${__patch_prefix}/ \
                --recursive
            ;;
        *)
            echo "ERROR: unkown action"
            return
            ;;
    esac

    unset __repo_name __actions __action __available_action __patch_file \
         __patch_prefix __origin_head __local_head __origin_repo
}
