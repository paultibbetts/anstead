#!/bin/bash
shopt -s nullglob

ENVIRONMENTS=( hosts/* )
ENVIRONMENTS=( "${ENVIRONMENTS[@]##*/}" )

show_usage() {
  echo "Usage: rollback.sh <environment> <app name>

<environment> is the environment to deploy to ("staging", "production", etc)
<app name> is the app to deploy (name defined in "laravel_apps")
For now <site name> is automatically set to example.com

Available environments:
`( IFS=$'\n'; echo "${ENVIRONMENTS[*]}" )`

Examples:
  rollback.sh staging example.com
  rollback.sh production example.com
"
}

[[ $# -lt 2 ]] && { show_usage; exit 0; }

for arg
do
  [[ $arg = -h ]] && { show_usage; exit 0; }
done

ENV="$1"; shift
SITE="$1"; shift
ROLLBACK_CMD="ansible-playbook rollback.yml -e env=$1 -e site=$SITE"
HOSTS_FILE="hosts/$ENV"

if [[ ! -e $HOSTS_FILE ]]; then
  echo "Error: $1 is not a valid environment ($HOSTS_FILE does not exist)."
  echo
  echo "Available environments:"
  ( IFS=$'\n'; echo "${ENVIRONMENTS[*]}" )
  exit 0
fi

$ROLLBACK_CMD
