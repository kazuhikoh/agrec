#!/bin/bash

set -u

usage(){
  cat <<EOF
Usage:
  $0 -h
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

requirements(){
  cat <<EOF
Requirements:
  - rtmpdump
EOF
}

# options
while getopts h opts
do
  case $opts in
  h)
    usage
    exit 0
    ;;
  \?)
    exit 1
  esac
done

# requirements
readonly REQUIRED_CMDS="rtmpdump"
for cmd in $REQUIRED_CMDS
do
  if ! type ${cmd} >/dev/null 2>&1; then
    echo "${cmd} not found." >&2
    requirements
    exit 1
  fi
done

# arguments
: $1 $2

################################################################

readonly DURATION="$1"
readonly OUT_PATH="$2"

readonly RTMP_URL="rtmp://fms-base2.mitene.ad.jp/agqr/aandg22"

# create output directory
readonly OUT_DIR=$(dirname "${OUT_PATH}")
if [[ ! -e "${OUT_DIR}" ]]; then
  mkdir -p "${OUT_DIR}"
fi

# recording
readonly LOG=$(mktemp -p . agrec.log.XXXXXX)
rtmpdump --rtmp ${RTMP_URL} --live --stop "${DURATION}" -o "${OUT_PATH}" >$LOG 2>&1 \
|| {
  cat $LOG 1>&2
  exit 1
}

# filesize & fullpath
msg=$(cd "$OUT_DIR"; du -b "$(pwd)/${OUT_PATH##*/}")
msg=$(echo $msg) # tab --> space

# if file is empty, exit with error
readonly filesize=${msg%% *}
if [[ "$filesize" = 0 ]]; then
  {
    echo 'ERROR: no data is captured.'
    echo "$msg"
  } >&2
  exit 1
fi

# result
echo "$msg"

# finalize
trap "
rm $LOG
" 0
