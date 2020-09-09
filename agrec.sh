#!/bin/bash

set -u

readonly SCRIPT_PATH="$(readlink -e $0)"
readonly SCRIPT_DIR="$(dirname $SCRIPT_PATH)"
readonly SOURCES_PATH="${SCRIPT_DIR%/}/sources"
readonly SOURCE_PATH="${SCRIPT_DIR%/}/source"

usage(){
  cat <<EOF
Usage:
  $0 -h
  $0 -c check
  $0 duration outpath
    duration - 録画時間[秒]
    outpath  - output filepath

Description:
  超A&G+ で配信中の動画を 保存するスクリプト。
  動画付きの番組の場合、始めの数秒が荒れるので、録画したい時間の少し前から開始したほうが良い。

  超A&G+
  http://www.agqr.jp/

Options:
  -h help
EOF
}

show_requirements(){
  cat <<EOF
Requirements:
  - rtmpdump
EOF
}

# record <length> <out>
record(){
  local len="$1"
  local out="$2"

  local url="$(cat "${SOURCE_PATH}")"

  if [[ -z $url ]]; then
    echo "Please execute \`${0##*/} -c\`" >&2
    return 1
  fi
  
  # create output directory
  local outDir=$(dirname "${out}")
  if [[ ! -e "${outDir}" ]]; then
    mkdir -p "${outDir}"
  fi
  
  # recording
  local log=$(mktemp -p . agrec.log.XXXXXX)
  rtmpdump --rtmp $url --live --stop $len -o "$out" >$log 2>&1 \
  || {
    cat $log >&2

    rm $log
    return 1
  } \
  && {
    rm $log
  }
  
  # filesize & fullpath
  local msg=$(cd "$outDir"; du -b "$(pwd)/${out##*/}")
  msg=$(echo $msg) # tab --> space
  
  # if file is empty, exit with error
  local filesize=${msg%% *}
  if [[ "$filesize" = 0 ]]; then
    {
      echo 'ERROR: no data is captured.'
      echo "$msg"
    } >&2
    return 1
  fi
  
  # result
  echo "$msg"
  
}

check(){
  local tmp="/tmp/agrec-check.mp4"
  local len=1

  if [[ -e "$SOURCE_PATH" ]]; then 
    local url="$(cat "$SOURCE_PATH")"
    
    echo "$url"

    if record $len "$tmp"; then
      echo "--> OK"
      rm "$tmp"
      return 0
    else
      echo "--> NG"
    fi
  fi

  # find
  local srcs="$(cat "$SOURCES_PATH")"
  for src in $srcs; do
    echo "$src" > "$SOURCE_PATH"

    echo "$src"

    if record $len "$tmp"; then
      echo "--> OK"
      rm "$tmp"
      return 1
    else
      echo "--> NG" 
      rm "$tmp"
    fi
  done

  echo ""
  echo "  All STREAMING ENDPOINTS ARE UNAVAILABLE!!"
  echo ""

  return 1
}

################################################################

# options
while getopts hc opts
do
  case $opts in
  h)
    usage
    exit 0
    ;;
  c)
    check
    exit $?
    ;;
  \?)
    exit 0
    ;;
  esac
done

shift $((OPTIND - 1))

# requirements
readonly REQUIRED_CMDS="rtmpdump"
for cmd in $REQUIRED_CMDS
do
  if ! type ${cmd} >/dev/null 2>&1; then
    echo "${cmd} not found." >&2
    show_requirements
    exit 1
  fi
done

# arguments
: $1 $2

readonly LENGTH="$1"
readonly OUTPUT="$2"
record "$LENGTH" "$OUTPUT"
exit $?
