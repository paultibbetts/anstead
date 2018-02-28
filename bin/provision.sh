#!/bin/bash
shopt -s nullglob

ENVIRONMENTS=( hosts/* )
ENVIRONMENTS=( "${ENVIRONMENTS[@]##*/}" )
HOSTS_FILE="hosts/$1"
NUM_ARGS=1

show_usage() {
  echo "Usage: provision <environment>

<environment> is the environment to provision ("staging", "production", etc)

Available environments:
`( IFS=$'\n'; echo "${ENVIRONMENTS[*]}" )`

Examples:
  provision staging
  provision production
"
}

[[ $# -ne $NUM_ARGS || $1 = -h ]] && { show_usage; exit 0; }

PROVISION_CMD="ansible-playbook provision.yml -e env=$1"
# if root is not allowed to login, switch the provision command for the below
# PROVISION_CMD="ansible-playbook provision.yml -e env=$1 --ask-become-pass"

if [[ ! -e $HOSTS_FILE ]]; then
  echo "Error: $1 is not a valid environment ($HOSTS_FILE does not exist)."
  echo
  echo "Available environments:"
  ( IFS=$'\n'; echo "${ENVIRONMENTS[*]}" )
  exit 0
fi

$PROVISION_CMD
