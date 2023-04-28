#!/bin/bash
# Author: Tim.Chen

# shellcheck source=./

set -e
TSE_API_URL_PREFIX='https://mis.twse.com.tw/stock/api/getStockInfo.jsp?json=1&delay=0&ex_ch='
REFRESH_INTERVAL=${1:-3}
OUTPUT_ENV_FILE=${2:-"./.glance.sh.env"}

function _die () {
  echo "[ERROR] $*" && exit 1
}

function _check_command () {
  command -v "$1" >/dev/null 2>&1 || _die "Please install $1 ; can try: https://command-not-found.com/$1"
}

function _get_shares () {
  # Parse the cost of the stock; format: [shares]@[price]
  local SHARES
  SHARES="GLANCE_STOCK_${1}_SHARES"
  echo "${!SHARES}"
}

function _get_cost () {
  # Parse the cost of the stock; format: [shares]@[price]
  local COST
  COST="GLANCE_STOCK_${1}_COST"
  echo "${!COST}"
}

function _split_underscore () {
  # Split the string by underscore with cut
  local STRING
  STRING="$1" ; shift
  local INDEX
  INDEX="$1"
  INDEX=$((INDEX+1))
  echo "${STRING}" | cut -d"_" -f"${INDEX}"
}

function _concatenate_stock () {
  # add | to the end of each stock code in ${GLANCE_STOCK_ARRAY}
  local STOCK_LIST
  STOCK_LIST=""
  for STOCK in "${GLANCE_STOCK_ARRAY[@]}"; do
    STOCK_LIST+=$(printf "otc_%s.tw|tse_%s.tw|" "${STOCK}" "${STOCK}")
  done
  STOCK_LIST=${STOCK_LIST%|}
  echo ${STOCK_LIST}
}

function _format_frame_top (){
  local FRAME_WIDTH
  FRAME_WIDTH="$1"

  printf "╭"
  printf "─%.0s" $(seq 1 "${FRAME_WIDTH}")
  printf "╮\n"
}

function _format_frame_hline (){
  local FRAME_WIDTH
  FRAME_WIDTH="$1"

  printf "╞"
  printf "=%.0s" $(seq 1 "${FRAME_WIDTH}")
  printf "╡\n"
}

function _format_frame_bottom (){
  local FRAME_WIDTH
  FRAME_WIDTH="$1"

  printf "╰"
  printf "─%.0s" $(seq 1 "${FRAME_WIDTH}")
  printf "╯\n"
}

function check_shell () {
  command -v "declare" >/dev/null 2>&1 || _die "command: [declare] not found. Please use bash version >= 4"
}

function check_commands () {
  for CMD in "$@"; do
    _check_command "$CMD"
  done
}

function gather_meta () {
  read -r SCREEN_ROWS SCREEN_COLS < <(stty size)
}

function watching_data () {
  [[ -z ${GLANCE_STOCK_ARRAY} ]] && echo "[x] | No stock code found. Please add stock code first." && return 0
  local TS
  local LOOP_INDEX=0  # up to 2 (0~2: length=3) -> length of: {c,a,b}
  local DELTA_TARGET=ask
  local CURRENT_SHARES=""
  local CURRENT_COST=""
  echo "Starting Watching ..."
  while true; do 
    DELTA=$(($(date +%s) - TS))
    if [[ ${DELTA} -gt ${REFRESH_INTERVAL} ]] ; then 
      clear
      
      # print header
      _format_frame_top 51
      printf "┊ %-10s ┊ %10s ┊ %10s ┊ %10s ┊\n" "Stock" "Ask" "Bid" "P/L"
      _format_frame_hline 51
      # fetch new data
      RESULT=$(curl -s "${TSE_API_URL_PREFIX}$(_concatenate_stock)" | jq '.msgArray | map({c,a,b})')
      for DATA in $(echo "${RESULT}" | jq -rc '.[] | flatten | join(" ")' ) ; do

        # deal with stock code (index = 0)
        if [[ "${GLANCE_STOCK_ARRAY[*]}" =~ ${DATA} ]] ; then
          local CURRENT_STOCK=${DATA}
          [[ $(_get_shares "${CURRENT_STOCK}") -gt 0 ]] && DELTA_TARGET=ask  # 多單看賣價
          [[ $(_get_shares "${CURRENT_STOCK}") -lt 0 ]] && DELTA_TARGET=bid  # 空單看買價
          echo "${CURRENT_STOCK}: ${DELTA_TARGET}"
          continue
        fi

        # deal with ask (index = 1)
        if [[ ${LOOP_INDEX} -eq 1 ]] && [[ ${DELTA_TARGET} == "ask" ]]; then
          # CURRENT_ASK=${DATA}
          echo "stock: ${CURRENT_STOCK} | index: ${LOOP_INDEX} | target: ${DELTA_TARGET} | ASK: ${DATA} | ($(_get_shares ${CURRENT_STOCK})@$(_get_cost ${CURRENT_STOCK}))"
          continue
        fi

        # deal with bid (index = 2)
        if [[ ${LOOP_INDEX} -eq 2 ]] && [[ ${DELTA_TARGET} == "bid" ]]; then
          # CURRENT_BID=${DATA}
          echo "stock: ${CURRENT_STOCK} | index: ${LOOP_INDEX} | target: ${DELTA_TARGET} | BID: ${DATA} | ($(_get_shares ${CURRENT_STOCK})@$(_get_cost ${CURRENT_STOCK}))"
          LOOP_INDEX=0
          continue
        fi

        if [[ ${LOOP_INDEX} -ge 2 ]] ; then
           LOOP_INDEX=0
        else
          (( LOOP_INDEX++ ))
        fi
        
      done
      TS=$(date +%s)
    fi

    echo
    read -r -t "${REFRESH_INTERVAL}" -p "(q)uit: " INPUT || printf ""
    case "$INPUT" in
      q)
        break 
        ;;
      *)
        :
        ;;
    esac
  done
}

function main(){
  check_shell
  check_commands "stty" "jq" "curl" "seq"
  gather_meta

  HELP_COUNTER=0
  GLANCE_STOCK_ARRAY=()
  trap "echo :" SIGINT
  echo "Press (h) for help."
  while true
  do
    read -r -p ": " INPUT
    case "$INPUT" in
      w | watch)
        watching_data
        echo "Watching Stopped."
        ;;
      q | quit)
        echo "Exit."
        break
        ;;
      h | help)
        echo "[(n)ew | (l)ist | (d)elete | (w)atch | (q)uit | (h)elp]"
        ;;
      n | new)
        read -r -p " > Add stock code: " NEW_STOCK
        if [[ ! ${NEW_STOCK} =~ ^[1-9][0-9][0-9][0-9]$ ]] ; then
          echo "stock code must be 4 digits. Cancelled."
          unset NEW_SHARES NEW_SHARES NEW_COST
          continue
        fi
        read -r -p " > with shares: " NEW_SHARES
        if [[ ! ${NEW_SHARES} =~ ^-?[0-9]+$ ]] ; then
          echo "Shares must be a number. Cancelled."
          unset NEW_SHARES NEW_SHARES NEW_COST
          continue
        fi
        read -r -p " > @ avg cost: " NEW_COST
        if [[ ! ${NEW_COST} =~ ^[0-9]{1,4}(\.[0-9]{2})?$ ]] ; then
          echo "AVG Cost not valid. Cancelled."
          unset NEW_SHARES NEW_SHARES NEW_COST
          continue
        fi
        declare "GLANCE_STOCK_${NEW_STOCK}_SHARES"="${NEW_SHARES}"
        declare "GLANCE_STOCK_${NEW_STOCK}_COST"="${NEW_COST}"
        [[ ! "${GLANCE_STOCK_ARRAY[*]}" =~ ${NEW_STOCK} ]] && GLANCE_STOCK_ARRAY+=("${NEW_STOCK}")
        unset NEW_STOCK NEW_SHARES NEW_COST
        ;;
      l | list)
        _format_frame_top 37
        printf "┊ %s\t%9s %s %9s ┊\n" "Stock Code" "Shares" "@" "Cost"
        _format_frame_hline 37
        for STOCK in "${GLANCE_STOCK_ARRAY[@]}"; do
          printf "┊ %10s\t%'9d @ %9.2f ┊\n" "${STOCK}" "$(_get_shares "${STOCK}")" "$(_get_cost "${STOCK}")"
        done
        _format_frame_bottom 37
        ;;
      d | delete)
        read -r -p " > Delete stock code: " DEL_STOCK
        unset GLANCE_STOCK_"${DEL_STOCK}"_SHARES GLANCE_STOCK_"${DEL_STOCK}"_COST
        GLANCE_STOCK_ARRAY=("${GLANCE_STOCK_ARRAY[@]/$DEL_STOCK}")
        NEW_ARRAY=()
        for STOCK in "${GLANCE_STOCK_ARRAY[@]}"; do
          [[ -n ${STOCK} ]] && NEW_ARRAY+=("${STOCK}")
        done
        GLANCE_STOCK_ARRAY=("${NEW_ARRAY[@]}")
        unset NEW_ARRAY
        echo "${GLANCE_STOCK_ARRAY[@]}"
        ;;
      v | vars)
        ( set -o posix ; set ) | grep -E "^GLANCE_STOCK_" || true
        ;;
      e | export)
        echo "Exporting to [${OUTPUT_ENV_FILE}]"
        ( set -o posix ; set ) | grep -E  "^GLANCE_STOCK" > "${OUTPUT_ENV_FILE}"
        ;;
      i | import)
        echo "Importing from [${OUTPUT_ENV_FILE}]"
        source "${OUTPUT_ENV_FILE}"
        ;;
      c | config)
        echo "Export ENV @ path: [${OUTPUT_ENV_FILE}]"
        ;;
      *)
        (( HELP_COUNTER+=1 ))
        [[ ${HELP_COUNTER} -ge 3 ]] && echo "[(n)ew | (l)ist | (d)elete | (w)atch | (q)uit | (h)elp]" && HELP_COUNTER=0
        :
        ;;
    esac
  done
}

main