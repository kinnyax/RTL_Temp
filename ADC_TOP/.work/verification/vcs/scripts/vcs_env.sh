#!/usr/bin/env bash

export VCS_HOME=/home/zezhoux/synopsys/vcs/R-2020.12-SP2
export VERDI_HOME=/home/zezhoux/synopsys/verdi/R-2020.12-SP2
export VCS_ARCH_OVERRIDE=linux
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-/home/zezhoux/synopsys/license/synopsys.lic}"
export PATH="${VCS_HOME}/bin:${VCS_HOME}/linux64/bin:${VERDI_HOME}/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="${VCS_HOME}/linux64/lib:${VERDI_HOME}/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH:-}"

