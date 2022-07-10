#!/bin/sh

# Keychain functions
function _get_password_from_keychain {
    local value
    local item_name

    item_name=$1
    [[ -z $item_name ]] && echo "Keychain item name is missing" && return 1

    value=$(security find-generic-password -w -s $item_name | xxd -p -r \
           | xmllint --xpath '//dict/string/text()' -)
    echo $value
}
