#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JOB_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
BUILD_DIR="${JOB_ROOT}/build"
RESULT_DIR="${JOB_ROOT}/results"

source "${SCRIPT_DIR}/vcs_env.sh"

mkdir -p "${BUILD_DIR}" "${RESULT_DIR}"
cd "${JOB_ROOT}"

PATTERN_I="${JOB_ROOT}/vcs/patterns/afe0_i.hex"
PATTERN_Q="${JOB_ROOT}/vcs/patterns/afe0_q.hex"
FSDB_FILE="${RESULT_DIR}/adc_rxd_vcs.fsdb"

echo "VCS_ENV: VCS R-2020.12-SP2 Full64, Verdi R-2020.12-SP2"
echo "VCS_ENV: license source configured (value intentionally hidden)"

timeout 300s "${VCS_HOME}/bin/vcs" \
    -full64 \
    -sverilog \
    +v2k \
    -timescale=1ns/1ps \
    -top tb_adc_rxd_vcs \
    -f "${JOB_ROOT}/vcs/filelist.f" \
    -debug_access+all \
    -kdb \
    -lca \
    +define+FSDB \
    -P "${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab" \
       "${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a" \
    -Mdir="${BUILD_DIR}/csrc" \
    -o "${BUILD_DIR}/simv" \
    -l "${RESULT_DIR}/compile.log"

timeout 180s "${BUILD_DIR}/simv" \
    +PATTERN_I="${PATTERN_I}" \
    +PATTERN_Q="${PATTERN_Q}" \
    +FSDB_FILE="${FSDB_FILE}" \
    -l "${RESULT_DIR}/simulation.log"

grep -q "VCS_SMOKE_PASS" "${RESULT_DIR}/simulation.log"
sha256sum "${RESULT_DIR}/compile.log" \
          "${RESULT_DIR}/simulation.log" \
          "${FSDB_FILE}" > "${RESULT_DIR}/SHA256SUMS"

echo "VCS_RUN_PASS: ${RESULT_DIR}"

