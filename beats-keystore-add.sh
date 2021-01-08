#!/bin/bash

set -o nounset
set -o errexit

usage() {
  cat <<EOF
Usage:
  $0 [OPTION]...

Options:
  -h, --help                 Show this message
  -b, --beat <beatname>      Chose beats who will append the pass in keystore (Default metricbeat)
  -f, --keys-file <filename> use the file as input to create keys in keystore (Default .beatkeys)
  -q, --quiet, --silent      Silent mode
  -d, --debug                Debug mode

By Env:
  For pass parameters as Env
  BEATS    - space separated list of beats
  KEYS_FILE - path of keys file

Examples:
  $0 --help
  $0 --debug -v -b metricbeat 
  $0 --beat metricbeat --beat filebeat --keys-file all_keys
  BEATS="journalbeat auditbeat" KEYS_FILE="awesome_keys.kv" $0 -d

Beats:
  metricbeat
  filebeat
  heartbeat
  packetbeat
  auditbeat
  journalbeat

KeysFile:
  file in format of key=value
  Format:
    key=value

  Example:
    # Cool Service
    SERVICE_NAME=coolname
    SERVICE_PASS=Str0ngP455

    # Another
    ANOTHER_CS=connection_string://0.0.0.0:88

    # STRANGE
    STRANGE_KEY=nice pass very long, with spaces and :=ç =ll.2\/d103d 1 0~;/ af "'ç

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
  $quiet || echo $(date +%Y-%m-%dT%H-%M-%S): $@
}

quiet=false
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
    "--keys-file"|"-f")
      keys_file=$2
      ;;
    "--quiet"|"-q"|"--silent")
      quiet=true
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

default_keys_file=.beatkeys.json
default_beats=${all_beats[@]}
keys_file=${keys_file:-$default_keys_file}

KEYS_FILE=${KEY_FILE:-$keys_file}
! [ -z "${BEATS:-}" ] && IFS=' ' read -r -a beats <<< "${BEATS:-}"
[[ -z ${beats[@]+"${beats[@]}"} ]] && beats=${default_beats[@]}

for beat in ${beats[@]+${beats[@]}}
do
  is_valid_beat $beat || err "invalid beatname: "$beat
done

BEATS=${beats[@]}

[ -f $KEYS_FILE ] || err "missing keys-file: "$KEYS_FILE

keystore_add(){
  key=$1
  value=$2
  service=$3
  user=${4:-root}
  log key=$key value=$value service=$service user=$user
  sudopref="sudo -u $user"
  cmdpref="$sudopref $service keystore"
  $sudopref [ -f /var/lib/$service/$service.keystore ] || $cmdpref create
  echo "$value" | $cmdpref add --stdin --force $key
}

list_keys() {
  keys_file=$1
  grep -Ev '^(#|$| )' $keys_file | grep -E '^[[:alnum:]]*=*'
}

add_keys() {
  keys_file=$1
  beats=$2
  keys=$(list_keys $keys_file)
  ok=false
  for beat in ${beats[@]}; do
    for kv in $keys; do
      k=$(cut -f1 -d= <<< $kv)
      v=$(cut -f2- -d= <<< $kv)
      keystore_add "$k" "$v" "$beat"
      ok=true
    done
  done
  $ok || err "missing envs"
}

add_keys $KEYS_FILE $BEATS
