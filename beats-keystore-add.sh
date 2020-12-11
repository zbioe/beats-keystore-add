#!/bin/bash

set -o nounset
set -o errexit

usage() {
  cat <<EOF
Usage:
  $0 [OPTION]...

Options:
  -h, --help                Show this message
  -b, --beat <beatname>     Chose beats who will append the pass in keystore (Default metricbeat)
  -f, --env-file <filename> Source envs from shell file and store them in chosed beats (Default .beatpass)
  -v, --verbose             Verbose mode
  -d, --debug               Debug mode

By Env:
  You can pass parameters as env for script
  BEATS    - space separated list of beats
  ENV_FILE - path of env file


Examples:-
  $0 --help
  $0 --debug -v -b metricbeat 
  $0 --beat metricbeat --beat filebeat --env-file all_envs.sh
  BEATS="journalbeat auditbeat" ENV_FILE="all_pass.sh" $0

Beats:
  metricbeat
  filebeat
  heartbeat
  packetbeat
  auditbeat
  journalbeat

EnvFile:
  sh or bash format

EOF
}

err() {
  echo "Err: "$1
  usage
  exit ${2:-1}
}

all_beats=(
  metricbeat
  filebeat
  heartbeat
  packetbeat
  auditbeat
  journalbeat
)

is_valid_beat(){
  beatname=$1
  (
    IFS=$'\001'
    [[ "$IFS${all_beats[*]}$IFS" =~ "${IFS}$beatname${IFS}" ]]
  )
}

log() {
  $verbose && echo $(date +%Y-%m-%dT%H-%M-%S): $@
}

verbose=false
declare -a beats

while [ $# -gt 0 ] ; do
  nSkip=2
  case $1 in
    "-h"|"--help")
      usage
      exit 0
      ;;
    "--beat"|"-b")
      is_valid_beat $2 || err "invalid beatname: "$2
      beats+=($2)
      ;;
    "--env-file"|"-f")
      env_file=$2
      ;;
    "--verbose"|"-v")
      verbose=true
      nSkip=1
      ;;
    "--debug"|"-d")
      set -x
      nSkip=1
      ;;
    *)
      err "invalid option"
      ;;
  esac
  shift $nSkip
done

default_env_file=.beatkeys
default_beats=${all_beats[@]}
env_file=${env_file:-$default_env_file}

ENV_FILE=${ENV_FILE:-$env_file}
! [ -z "${BEATS:-}" ] && IFS=' ' read -r -a beats <<< "${BEATS:-}"
[[ -z ${beats[@]+"${beats[@]}"} ]] && beats=${default_beats[@]}

for beat in ${beats[@]+${beats[@]}}
do
  is_valid_beat $beat || err "invalid beatname: "$beat
done

BEATS=${beats[@]}

[ -f $ENV_FILE ] || err "invalid env-file: "$ENV_FILE

keystore_add(){
  key=$1
  value=$2
  service=$3
  user=${4:-root}
  log key=$key value=$value service=$service user=$user
  sudopref="sudo -u $user"
  cmdpref="$sudopref $service keystore"
  $sudopref [ -f /var/lib/$service/$service.keystore ] || $cmdpref create
  echo $value | $cmdpref add --stdin --force $key
}

list_envs() {
  env_file=$1
  (
    VARS="`set -o posix ; set`"
    . $env_file
    grep -vFe "$VARS" <<<"$(set -o posix ; set)" | grep -v '^VARS=\|^SHLVL='
    unset VARS
  )
}

add_env(){
  k=$1
  v=$2
  beat=$3
  keystore_add $k $v $beat
}

add_envs() {
  env_file=$1
  beats=$2
  envs=$(list_envs $env_file)
  . $env_file
  for beat in ${beats[@]}; do
    for kv in $envs; do
      IFS="=" read -r k v <<< $kv
      keystore_add $k $v $beat
    done
  done
}

add_envs $ENV_FILE $BEATS
