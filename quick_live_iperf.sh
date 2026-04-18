#!/usr/bin/env bash
# quick_live_iperf.sh
# Simple iperf3 wrapper for live testing between a testing net and a target net.
# - Prompts for target IP/hostname (target net)
# - Prompts for iperf3 port (default 5201)
# - Runs TCP up/down + UDP at configured rates
# - Shows a spinner while tests run
# - Prints compact labeled summaries and a final table
# Requirements: iperf3, ping, timeout, awk, grep

set -euo pipefail

# Ask for target IP if not provided as first argument
if [[ $# -ge 1 ]]; then
  SERVER_IP="$1"
else
  read -rp "Enter target IP or hostname (target net): " SERVER_IP
fi

if [[ -z "${SERVER_IP}" ]]; then
  echo "No target specified, exiting."
  exit 1
fi

# Ask for iperf3 port, default 5201
read -rp "Enter iperf3 port [5201]: " PORT_INPUT
PORT="${PORT_INPUT:-5201}"

DURATION="${DURATION:-10}"          # seconds per test
PARALLEL="${PARALLEL:-4}"
UDP_RATES="${UDP_RATES:-500M 800M}" # UDP bandwidths to test

# Quick reachability check (2 pings, 1s timeout each)
echo "Checking reachability from testing net to target net (${SERVER_IP})..."
if ! ping -c 2 -W 1 "${SERVER_IP}" >/dev/null 2>&1; then
  echo "ERROR: ${SERVER_IP} is not reachable (ping failed)."
  echo "Aborting tests."
  exit 1
fi

# Determine testing net IP used to reach SERVER_IP (LAN IP) - best effort
TESTING_IP="$(
  ip route get "${SERVER_IP}" 2>/dev/null \
  | awk '/src/ {for (i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' \
  | head -n1 || true
)"
TESTING_IP="${TESTING_IP:-LOCAL}"

spinner() {
  local pid="$1"
  local msg="$2"
  local spin='-\|/'
  local i=0

  while kill -0 "${pid}" 2>/dev/null; do
    printf "\r%s %s" "${msg}" "${spin:i++%${#spin}:1}"
    sleep 0.2
  done
  printf "\r%s done\n" "${msg}"
}

# Array of summary lines: "NAME|BW|EXTRA"
summaries=()

run_test() {
  local name="$1"; shift

  echo
  echo ">>> ${name}"
  local tmp
  tmp="$(mktemp)"

  # Run iperf3 in background with a hard timeout, capture output to temp file
  timeout "$((DURATION+5))" iperf3 "$@" > "${tmp}" 2>&1 &
  local ipid=$!

  spinner "${ipid}" "Running ${name} (${DURATION}s)"

  if ! wait "${ipid}"; then
    echo
    echo "${name}: iperf3 failed:"
    tail -n 5 "${tmp}"
    rm -f "${tmp}"
    summaries+=("${name}|FAILED|")
    return 1
  fi

  echo
  # Show only last few lines (summary) from iperf3
  tail -n 5 "${tmp}"

  # Add labeled human summary & store for final table
  if [[ "${name}" == TCP_* ]]; then
    # For TCP, parse [SUM] sender line for bandwidth and Retr
    local sum_line bw retr
    sum_line=$(grep 'SUM' "${tmp}" | grep sender | tail -n1 || true)
    if [[ -n "${sum_line}" ]]; then
      bw=$(echo "${sum_line}" | awk '{print $(NF-3), $(NF-2)}')
      retr=$(echo "${sum_line}" | awk '{print $(NF-1)}')
      echo ">>> ${name} summary: TESTING_NET(${TESTING_IP}) -> TARGET_NET(${SERVER_IP}:${PORT}) = ${bw}, Retransmissions=${retr}"
      summaries+=("${name}|${bw}|Retransmissions=${retr}")
    else
      summaries+=("${name}|N/A|")
    fi
  elif [[ "${name}" == UDP_* ]]; then
    # For UDP, parse receiver line for bitrate and loss
    local udp_line bw loss
    udp_line=$(grep 'receiver' "${tmp}" | tail -n1 || true)
    if [[ -n "${udp_line}" ]]; then
      bw=$(echo "${udp_line}" | awk '{print $(NF-6), $(NF-5)}')
      # Loss% is inside parentheses in the last field, e.g. "(48%)"
      loss=$(echo "${udp_line}" | awk '{print $NF}' | tr -d '()%')
      echo ">>> ${name} summary: TESTING_NET(${TESTING_IP}) -> TARGET_NET(${SERVER_IP}:${PORT}) = ${bw}, Loss=${loss}%"
      summaries+=("${name}|${bw}|Loss=${loss}%")
    else
      summaries+=("${name}|N/A|")
    fi
  else
    summaries+=("${name}|N/A|")
  fi

  rm -f "${tmp}"
}

echo "=== quick_live_iperf: testing net -> target net ==="
echo "Testing net (client): ${TESTING_IP}"
echo "Target net (server): ${SERVER_IP}:${PORT}"
echo "(Each test ${DURATION}s, compact summary only)"
echo

# 1) TCP upload (testing net -> target net)
run_test "TCP_UP"   -c "${SERVER_IP}" -p "${PORT}" -t "${DURATION}" -P "${PARALLEL}" -i 1

# 2) TCP download (target net -> testing net)
run_test "TCP_DOWN" -c "${SERVER_IP}" -p "${PORT}" -R -t "${DURATION}" -P "${PARALLEL}" -i 1

# 3+) UDP tests (testing net -> target net)
for rate in ${UDP_RATES}; do
  run_test "UDP_${rate}" -c "${SERVER_IP}" -p "${PORT}" -u -b "${rate}" -t "${DURATION}" -i 1 --get-server-output
done

echo
echo "=== SUMMARY TABLE ==="
printf '%-12s %-40s %-30s\n' "Test" "Direction" "Result"
printf '%-12s %-40s %-30s\n' "------------" "----------------------------------------" "------------------------------"

for entry in "${summaries[@]}"; do
  IFS='|' read -r name bw extra <<< "${entry}"
  printf '%-12s %-40s %-30s\n' \
    "${name}" "TESTING_NET(${TESTING_IP}) -> TARGET_NET(${SERVER_IP}:${PORT})" "${bw} ${extra}"
done

echo
echo "=== DONE ==="