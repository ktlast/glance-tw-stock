#!/bin/bash

BASE_API_URL="https://mis.twse.com.tw/stock/api/getStockInfo.jsp"

# create from redis:
#   ->   for code in $(redis-cli smembers codes:tse:all); do echo $code | cut -d')' -f2 | xargs printf -- 'tse_%s.tw\n' >> .exchange_table.txt; done
#   ->   for code in $(redis-cli smembers codes:otc:all); do echo $code | cut -d')' -f2 | xargs printf -- 'otc_%s.tw\n' >> .exchange_table.txt; done
EXCHANGE_TABLE_PATH="./.exchange_table.txt"
EXCHANGE_TABLE_REMOTE=""
PORTFOLIO="./portfolio.conf"
WATCH_INTERVAL_DEFAULT=15
WATCH_INTERVAL=${WATCH_INTERVAL_DEFAULT}

RED='\033[0;31m'
NC='\033[0m' # No Color
UWHITE='\033[4;37m'
CYAN='\033[0;36m'  
_WHOLE_DIGITS_STYLE=${CYAN}
_FRACTIONAL_DIGITS_STYLE=${UWHITE}


# ENV VAR (Generated dynamically)
# ->
#   PORTFOLIO_${CODE}_AMOUNT=${AMOUNT}
#   PORTFOLIO_${CODE}_AT_COST=${AT_COST}
#   STOCK_${CODE}_ASK
#   STOCK_${CODE}_BID


function init_exchange_table () {
  EXCHANGE_CODE_URL="https://raw.githubusercontent.com/ktlast/market-envs/master/api/tw-stock-api-code.txt"
  if [[ $(curl -LI ${EXCHANGE_CODE_URL} -o /dev/null -w '%{http_code}\n' -s) == "200" ]]; then
    curl -s ${EXCHANGE_CODE_URL} -o ${EXCHANGE_TABLE_PATH}
  fi
  [[ ! -e ${EXCHANGE_TABLE_PATH} ]] && echo "Exchange table not found at: [${EXCHANGE_TABLE_PATH}]." && exit 1
}


function check_command_exists () {
  CMDS=(
    "curl"
    "jq"
    "xargs"
    "cut"
    "python3"
  )

  for CMD in ${CMDS[@]}; do
    [[ ! $(which ${CMD}) ]] && echo "Command : [${CMD}] not found, please install it and try again." && exit 1
  done
}


function form_symbol_payload () {
  RAW_PARAM=""
  for SYMBOL in ${SYMBOLS[@]}; do
    FULL_SYMBOL=$(grep ${SYMBOL} ${EXCHANGE_TABLE_PATH} | head -1)
    RAW_PARAM+="${FULL_SYMBOL}|"
  done
  PARAM="${RAW_PARAM%%|}"
}

function parse_portfolio_file () {
  SYMBOLS=()
  local _CODE
  local _AMOUNT
  local _AT_COST
  while read -r line;
  do
    if [[ $line =~ \s*^\#.* ]] || [[ $line =~ ^\s*$ ]]; then
      continue
    fi
    _CODE=$(echo "$line" | xargs | cut -s -d '_' -f1)
    _AMOUNT=$(echo "$line" | xargs | cut -s -d '_' -f2)
    _AT_COST=$(echo "$line" | xargs | cut -s -d '_' -f3)
    SYMBOLS+=("${_CODE}")
    export "PORTFOLIO_${_CODE}_AMOUNT=${_AMOUNT}"
    export "PORTFOLIO_${_CODE}_AT_COST=${_AT_COST}"
  done < ${PORTFOLIO}
}


function portfolio_delete () {
  local _CODE=$1
  local RANDOM_POSTFIX="POSTFIX$(echo $RANDOM)"
  # sed "/${_CODE}/d" ${PORTFOLIO}

  # use sed inline deletion; works on both GNU and not-GNU version sed (OSX)
  sed -i${RANDOM_POSTFIX}  "/${_CODE}/d" ${PORTFOLIO} && rm -f "${PORTFOLIO}${RANDOM_POSTFIX}"
}


function portfolio_add () {
  local INPUT=$1
  local _CODE
  local _AMOUNT
  local _AT_COST

  # if input contains amount and avg cost (with a '_' delimeter)
  if [[ ${INPUT} =~ ^[0-9]{4}_[0-9]+_[0-9]+(\.[0-9]+)?$ ]]; then
    _CODE=$(echo "${INPUT}" | xargs | cut -s -d '_' -f1)
    if grep -q ${_CODE} ${PORTFOLIO}; then 
      portfolio_delete ${_CODE}
    fi
    echo ${INPUT} >> ${PORTFOLIO}

  # else if input just is a pure stock code (4-digit number); just for watching price, will not calculate profit.
  elif [[ ${INPUT} =~ ^[0-9][0-9][0-9][0-9]$ ]]; then
    if grep -q ${INPUT} ${PORTFOLIO}; then 
      portfolio_delete ${INPUT}
    fi
    echo ${INPUT}_0_0 >> ${PORTFOLIO}
  else
    echo "[ERROR] invalid input! GOT: [${INPUT}].  (Example: 2330_3_600.0 )"
  fi
  
}


function portfolio_list () {
  echo 
  printf "%-7s%10s%10s\n" "CODE" "#share" "@cost"
  echo "----------------------------"
  # cat ${PORTFOLIO} |grep -v '#' | grep . | sed 's/_/\'$'\t\t/g'
  cat ${PORTFOLIO} |grep -v '#' | grep . | sed 's/_/\ /g' | xargs printf "%-7s%10s%10s\n" 

}


# check_command_exists
# parse_portfolio_file
# form_symbol_payload


function start_watching () {
  parse_portfolio_file
  form_symbol_payload

  local _CODE
  local _BID
  local _ASK
  local _COST
  local _AMOUNT
  local _FRACTIONAL_AMOUNT
  local _WHOLE_AMOUNT
  local _PL
  local _NET_PL
 

  # refresh forever
  while true; do
    local _SUM=()
    clear
    RESULT=$(curl -s "${BASE_API_URL}?ex_ch=${PARAM}&json=1&delay=0")

    # FORMAT="%-7s\t\t%4d\t\t%4d\t\t%0.2f\t\t%0.2f\t\t%0.1f\n"
    # print(title
    # printf "CODE\t\t#share\t\t@cost\t\tBID\t\tASK\t\tP/L\n"
    printf "%-7s%10s%10s%10s%10s%15s\n" "CODE" "#share" "@cost" "BID" "ASK" "P/L"
    echo

    # parse result; calculate profit/loss (PL).
    for DATA_ARR in $(echo ${RESULT}| jq -c '.msgArray[]'); do
      local TMP_RESULT=$(echo ${DATA_ARR} |  jq '.c,.b,.a' | xargs printf "%s %s %s")
      _CODE=$(echo ${TMP_RESULT} | cut -d ' '  -f 1)
      _BID=$(echo ${TMP_RESULT} | cut -d ' '  -f 2 | cut -d '_' -f 1)
      _ASK=$(echo ${TMP_RESULT} | cut -d ' '  -f 3 | cut -d '_' -f 1)
      # _CODE=$(echo ${DATA_ARR} | jq -r '.c')
      # _BID=$(echo ${DATA_ARR} | jq -r '.b' | cut -d '_' -f1)
      # _ASK=$(echo ${DATA_ARR} | jq -r '.a' | cut -d '_' -f1)
      
      local _REF_COST="PORTFOLIO_${_CODE}_AT_COST"
      local _REF_AMOUNT="PORTFOLIO_${_CODE}_AMOUNT"

      _COST=${!_REF_COST}
      _AMOUNT=${!_REF_AMOUNT}
      
      # echo ${_COST}
      # echo ${_AMOUNT}

      _PL=$(python3 -c "print(round(( ${_BID} - ${_COST} ) * ${_AMOUNT}, 2))")
      _SUM+=" ${_PL}"

       if [[ ${#_AMOUNT} -ge 4 ]]; then
        _WHOLE_AMOUNT=${_AMOUNT%???}
        _FRACTIONAL_AMOUNT=${_AMOUNT:${#_AMOUNT}-3}
      else
        _WHOLE_AMOUNT=""
        _FRACTIONAL_AMOUNT=${_AMOUNT}
      fi

      # printf "%-7s%10d%10.2f%10.2f%10.2f%15.1f\n" "${_CODE}" "${_AMOUNT}" "${_COST}" "${_BID}" "${_ASK}" "${_PL}"
      printf "%-7s${_WHOLE_DIGITS_STYLE}%7s${NC}${_FRACTIONAL_DIGITS_STYLE}%3s${NC}%10.2f%10.2f%10.2f%15.1f\n" "${_CODE}" "${_WHOLE_AMOUNT}" "${_FRACTIONAL_AMOUNT}" "${_COST}" "${_BID}" "${_ASK}" "${_PL}"

    done
    echo "--------------------------------------------------------------"
    _NET_PL=$(python3 -c "print(round(sum(map(float, \"${_SUM}\".split())), 2))")
    printf "%62s\n" "${_NET_PL}"

    # echo ${RESULT} | jq '.msgArray[]| .c, .a, .b'
    sleep ${WATCH_INTERVAL}
  done
}

# echo -e "\n----init ----------"
# cat ${PORTFOLIO}
# echo "------------"
# echo 


while [[ $# -gt 0 ]]; do
  case $1 in
    -a|add)
      # SYMBOL_CODE="$2"
      PORTFOLIO_METHOD="ADD"
      shift
      ;;
    -d|delete)
      PORTFOLIO_METHOD="DELETE"
      shift
      ;;
    -l|list)
      portfolio_list
      exit 0
      ;;
    -i|interval)
      WATCH_INTERVAL=$2
      echo ${WATCH_INTERVAL}
      [[ ! ${WATCH_INTERVAL} =~ ^([1-9][0-9]+|[1-9])$ ]] && WATCH_INTERVAL=5 && echo "[ERROR] Invalid input interval, reset to default (${WATCH_INTERVAL_DEFAULT})."
      shift
      shift
      ;;
    [0-9][0-9][0-9][0-9]*)
      [[ ${PORTFOLIO_METHOD} == "DELETE" ]] &&  portfolio_delete "$1"
      [[ ${PORTFOLIO_METHOD} == "ADD" ]]  &&  portfolio_add "$1"
      shift
      ;;
    start)
      init_exchange_table
      start_watching
      ;;
    
    # -*|--*)
    #   echo "Unknown option $1"
    #   exit 1
    #   ;;
    *)
      echo pass
      shift
      ;;
  esac
done

# cat ${PORTFOLIO}
# echo "TO ADD: ${PORTFOLIO_TO_ADD[@]}"
# echo "TO DELETE: ${PORTFOLIO_TO_DELETE[@]}"




