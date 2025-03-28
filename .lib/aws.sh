#######################################
# Add awscli completion
#######################################
# If both complete and aws_completer commands exist, then add them.
if type complete &> /dev/null && type aws_completer &> /dev/null; then
    complete -C $(which aws_completer) aws
fi;


#######################################
# aliases
#######################################
alias aws-whoami="aws::current_user_arn"


#######################################
# functions
#######################################
# Get credentials for MFA enabled authentication
function aws::sts_session_token() {
    local credentials
    local mfa_serial_number
    local token_code
    local duration_seconds

    # Parse parameters
    while [[ -n "$1" ]]; do
        case $1 in
            -d | --duration)
                shift
                duration_seconds=$1
                ;;
            -s | --serial)
                shift
                mfa_serial_number=$1
        esac
        (( $# > 0 )) && shift
    done

    # If duration is not provided, default it to 900 seconds.
    [[ -z $duration_seconds ]] && duration_seconds=900
    if [[ -z $mfa_serial_number ]]; then
        # Get the current user's mfa serial number
        mfa_serial_number=$(aws::current_mfa_serial_number $1) || return 1
    fi

    echo Getting session token using mfa: $mfa_serial_number for duration: $duration_seconds seconds.
    # Get the mfa token code
    printf "Enter the MFA code: "; read token_code

    # Get the credential
    credentials=$(aws sts get-session-token \
        --duration-seconds ${duration_seconds} \
        --serial-number ${mfa_serial_number} \
        --token-code ${token_code} \
        --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
        --output text \
    )

    # Return if the previous command executed with error
    if (( $? != 0 )); then
        __err "Unable to get session token"
        return 1
    fi

    # Replace tabs (if there is any) to space, and then split the string by spaces.
    export AWS_ACCESS_KEY_ID=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f1)
    export AWS_SECRET_ACCESS_KEY=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f2)
    export AWS_SESSION_TOKEN=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f3)
}

# Assume the given role and return credentials
function aws::sts_assume_role() {
    local credentials
    local mfa_serial_number
    local role_arn
    local token_code
    local duration_seconds

    # Parse parameters
    while [[ -n "$1" ]]; do
        case $1 in
            -r | --role-arn)
                shift
                role_arn=$1
                ;;
            -d | --duration)
                shift
                duration_seconds=$1
                ;;
            -s | --serial)
                shift
                mfa_serial_number=$1
        esac
        (( $# > 0 )) && shift
    done

    [[ -z $role_arn ]] && __err "role arn is missing" && return 1

    # If duration is not provided, default it to 900 seconds.
    [[ -z $duration_seconds ]] && duration_seconds=900

    # Print the caller identity before assume role
    aws sts get-caller-identity

    echo Assuming role: $role_arn using mfa: $mfa_serial_number for duration: $duration_seconds seconds.

    # Get the credential
    if [[ -n $mfa_serial_number ]]; then
        # If mfa_serial_number is provided, then get the token code
        printf "Enter the MFA code: "; read token_code

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

    # Return if the previous command executed with error
    if (( $? != 0 )); then
        __err "Unable to get session token"
        return 1
    fi

    # Replace tabs (if there is any) to space, and then split the string by spaces.
    export AWS_ACCESS_KEY_ID=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f1)
    export AWS_SECRET_ACCESS_KEY=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f2)
    export AWS_SESSION_TOKEN=$(echo $credentials | tr -s '\t' ' ' | cut -d' ' -f3)
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)

    # Print caller identity after the assume role
    aws sts get-caller-identity

}

# Get aws mfa serial number. If it's not set as an env variable, it gets it
# from the aws sts get-caller-identity
function aws::current_mfa_serial_number() {
    local mfa_serial_number

    [[ -n "${mfa_serial_number:=$AWS_MFA_SERIAL_NUMBER}" ]] \
    || mfa_serial_number=$(aws sts get-caller-identity \
                        | grep Arn \
                        | cut -d'"' -f 4 \
                        | sed 's/:user/:mfa/g')

    # If mfa serial number is empty, return with error
    if [[ -z "$mfa_serial_number" ]]; then
        __err "Cannot retrieve the mfa serial number"
        return 1
    fi

    echo $mfa_serial_number
}

# Get current aws user arn
function aws::current_user_arn() {
    aws sts get-caller-identity | grep Arn | cut -d'"' -f4

    (( PIPESTATUS[0] != 0 )) && return 1
}

# Get current aws user in format of AccountNo/Username
function aws::current_user() {
    local __user_arn

    [[ -n "${__user_arn:=$1}" ]] \
        || __user_arn=$(aws::current_user_arn)

    if [[ -z "$__user_arn" ]]; then
        __err "User arn is empty"
        return 1
    fi

    echo $(echo $__user_arn | cut -d: -f5)/$(echo $__user_arn | cut -d/ -f2)
}

# Load original aws env variables
function aws::load_original_env_variables() {
    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_ORIGINAL
    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_ORIGINAL
    export AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN_ORIGINAL
}

# Set the current aws env variables to orginal variables
function aws::set_original_env_variables() {
    [[ -n $AWS_ACCESS_KEY_ID ]] \
        && export AWS_ACCESS_KEY_ID_ORIGINAL=$AWS_ACCESS_KEY_ID
    [[ -n $AWS_SECRET_ACCESS_KEY ]] \
        && export AWS_SECRET_ACCESS_KEY_ORIGINAL=$AWS_SECRET_ACCESS_KEY
    [[ -n $AWS_SESSION_TOKEN ]] \
        && export AWS_SESSION_TOKEN_ORIGINAL=$AWS_SESSION_TOKEN

    return 0
}

# Print the current aws env variables to the console
function aws::print_env_variables() {
    echo "export AWS_REGION=$AWS_REGION"
    echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
    echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
    echo "export AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN"
}

# AWS SSM functions
# Put (upsert) a secure string into the Parameter Store.
function aws::ssm_put_param() {
    local __param_name
    local __param_val
    local __param_label

    # Parse parameters
    while [[ -n "$1" ]]; do
        case $1 in
            -n | --name)
                shift
                __param_name=$1
                ;;
            -l | --label)
                shift
                __param_label=$1
                ;;
            -v | --value)
                shift
                __param_val=$1
         esac
         (( $# > 0 )) && shift
    done

    aws ssm put-parameter --name $__param_name \
        --value $__param_val \
        --type SecureString \
        --overwrite

    # If previous command exited without error and label is provided,
    # then set the label to the current version.
    if [[ $? == 0 && -n $__param_label ]]; then
        aws ssm label-parameter-version --name $__param_name \
            --labels $__param_label
    fi
}

# Get a secure string value from the Parameter Store.
function aws::ssm_get_param() {
    local __param_name
    local __param_label

    # Parse parameters
    while [[ -n "$1" ]]; do
        case $1 in
            -n | --name)
                shift
                __param_name=$1
                ;;
            -l | --label)
                shift
                __param_label=$1
        esac
        (( $# > 0 )) && shift
    done

    # If label is provided, add it to the name.
    if [[ -n $__param_label ]]; then
        __param_name=$__param_name:$__param_label
    fi

    aws ssm get-parameter --name $__param_name \
        --with-decryption \
        --query 'Parameter.Value' \
        --output text
}
