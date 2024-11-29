#!/bin/bash
#PJM -L "node=1"
#PJM -L "rscunit=rscunit_ft01"
#PJM -L "rscgrp=small"
#PJM -L "elapse=2:00:00"
#PJM --llio cn-cache-size=4096Mi
#PJM --llio localtmp-size=80Gi
#PJM -x PJM_LLIO_GFSCACHE='/vol0002:/vol0003:/vol0004:/vol0005:/vol0006'
#PJM --mpi max-proc-per-node=4
#PJM -L freq=2200
#PJM -L throttling_state=0
#PJM -L issue_state=0
#PJM -L ex_pipe_state=0
#PJM -L eco_state=0
#PJM -L retention_state=0
#PJM -j

set +e	#commands returning non-zero exit codes will not cause the entire script to fail
set -x
if ! lscpu | grep 'sve' >/dev/null 2>&1; then echo "ERR: not on login node"; exit 1; fi

function try_to_build() {
	ARGS=(${@})
	echo -e "\n\nBUILDING: ${ARGS[@]}"
	#try first in ramdisk and hope its big enough
	export TMP=/worktmp ; export TMPDIR=/worktmp ;
	${ARGS[@]} && return ;
	#if not work, then llio disk
	export TMP=/local ; export TMPDIR=/local ;
	${ARGS[@]} || cp -r ${TMP}/$(whoami)/spack-stage ${HOME}/
}

SPACKVERS="0.22.2"
CLANGVERS="19.1.4"
CLANGSVERS="$(echo ${CLANGVERS} | sed -e 's@\..*@@')"
CLANGCOMP="clang@${CLANGVERS}"

if [[ -z "${SPACK_PATH}" ]]; then
	FIRST_GROUP="$(/bin/groups | cut -d' ' -f1)"
	[ -d /vol0004 ] && SPACK_PATH="$(/bin/find /vol*/data/${FIRST_GROUP}/ -maxdepth 1 -name $(whoami) | head -1)/.spack-llvm-v${CLANGVERS}" || SPACK_PATH="${HOME}/.spack-llvm-v${CLANGVERS}"
fi
SPACK_PATH="$(readlink -f "${SPACK_PATH}")"
SPACK_REPOS="${SPACK_PATH}/var/spack/repos"

export SPACK_USER_CONFIG_PATH="${SPACK_PATH}/user_config"
export SPACK_SYSTEM_CONFIG_PATH="${SPACK_PATH}/sys_config"
export SPACK_USER_CACHE_PATH="${SPACK_PATH}/user_cache"
export TMP="${PJM_LOCALTMP:=/tmp}"
export TMPDIR="${PJM_LOCALTMP}"

#XXX: on compute node
[ -e "${SPACK_PATH}" ] && { echo "wont rm ${SPACK_PATH}; please do it yourself" ; exit 1; }
mkdir -p "${SPACK_USER_CONFIG_PATH}/linux" || exit 1
mkdir -p "${SPACK_SYSTEM_CONFIG_PATH}" || exit 1
mkdir -p "${SPACK_USER_CACHE_PATH}" || exit 1
cd "${TMPDIR}" || exit 1
wget https://github.com/spack/spack/archive/refs/tags/v${SPACKVERS}.tar.gz && tar xzf v${SPACKVERS}.tar.gz && mv "spack-${SPACKVERS}"/* "${SPACK_PATH}"/ || exit 1

. "${SPACK_PATH}/share/spack/setup-env.sh"
spack compilers

# pin the spack instance to exactly this isolated config
sed -i -e "/^export _sp_initializing/a export SPACK_USER_CONFIG_PATH=\"${SPACK_PATH}/user_config\"\nexport SPACK_SYSTEM_CONFIG_PATH=\"${SPACK_PATH}/sys_config\"\nexport SPACK_USER_CACHE_PATH=\"${SPACK_PATH}/user_cache\"" "${SPACK_PATH}/share/spack/setup-env.sh"

cat <<'EOF' > ${SPACK_USER_CONFIG_PATH}/linux/packages.yaml
packages:
  all:
    compiler: [clang]
    providers:
      mpi: [fujitsu-mpi]
      blas: [fujitsu-ssl2, openblas]
      lapack: [fujitsu-ssl2, openblas]
      scalapack: [fujitsu-ssl2, netlib-scalapack]
    permissions:
      write: group
  htslib:
    version: [1.12]
  openssh:
    permissions:
      write: user
  mpi:
    buildable: False
  fujitsu-mpi:
    version: [head, 4.11.1]
    buildable: False
    externals:
      - spec: "fujitsu-mpi@head%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/mpi
      - spec: "fujitsu-mpi@4.11.1%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/mpi
  fujitsu-ssl2:
    version: [head, 4.11.1]
    buildable: False
    externals:
      - spec: "fujitsu-ssl2@head%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/ssl2
      - spec: "fujitsu-ssl2@4.11.1%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/ssl2
  elfutils:
    externals:
      - spec: "elfutils@0.186%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/crosstools/aarch64-none-linux-gnu/libc/usr
  pmix:
    externals:
      - spec: "pmix@2.1.4%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/crosstools/aarch64-none-linux-gnu/libc/usr
  hwloc:
    externals:
      - spec: "hwloc@2.2.0%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/crosstools/aarch64-none-linux-gnu/libc/usr
  libevent:
    externals:
      - spec: "libevent@2.1.8%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/crosstools/aarch64-none-linux-gnu/libc/usr
  papi:
    externals:
      - spec: "papi@5.6.0%CLANGCOMP arch=linux-rhel8-a64fx"
        prefix: CLANGROOT/crosstools/aarch64-none-linux-gnu/libc/usr
  binutils:
    externals:
      - spec: "binutils@2.41%CLANGCOMP+gold arch=linux-rhel8-a64fx"
        prefix: CLANGROOT
        extra_attributes:
          environment:
            append_path:
              PATH: CLANGROOT/crosstools/aarch64-none-linux-gnu
EOF

#spack compiler find
cat <<'EOF' > ${SPACK_USER_CONFIG_PATH}/linux/compilers.yaml
compilers:
- compiler:
    spec: clang@=CLANGVERS
    paths:
      cc: CLANGROOT/bin/clang
      cxx: CLANGROOT/bin/clang++
      f77: CLANGROOT/bin/flang
      fc: CLANGROOT/bin/flang
    flags: {}
    operating_system: rhel8
    target: aarch64
    modules: []
    environment: {}
    extra_rpaths: []
EOF

. /home/apps/oss/llvm-v${CLANGVERS}/init.sh
CLANGROOT="$(readlink -f "$(dirname "$(which clang)")/../")"
sed -i -e "s@CLANGROOT@${CLANGROOT}@g" -e "s@CLANGVERS@${CLANGVERS}@g" -e "s@clang-${CLANGSVERS}@clang@g" \
       -e "s@fc: null@fc: $(which flang)@g" -e "s@f77: null@f77: $(which flang)@g" \
       -e "s@environment: {}@environment:\n      append_path:\n        PATH: $(dirname $(which clang))\n        LD_LIBRARY_PATH: $(dirname $(which clang))/../mpi/lib64@g" "${SPACK_USER_CONFIG_PATH}/linux/compilers.yaml"
#XXX: for llama and others in sve256 we cannot target sve512
sed -i -e 's@flags: {}@flags:\n      cflags: -msve-vector-bits=scalable\n      cxxflags: -msve-vector-bits=scalable\n      fflags: -msve-vector-bits=scalable@g' "${SPACK_USER_CONFIG_PATH}/linux/compilers.yaml"

sed -i -e "s@CLANGROOT@${CLANGROOT}@g" -e "s#CLANGCOMP#${CLANGCOMP}#g" "${SPACK_USER_CONFIG_PATH}/linux/packages.yaml"
sed -i -e "s@SYSTEM_PATHS = \[\(.*\)\]@SYSTEM_PATHS = [\1, \"$(readlink -f "$(dirname "$(which clang)")/../")/crosstools/aarch64-none-linux-gnu/libc/usr\"]@g" "${SPACK_PATH}/lib/spack/spack/util/environment.py"

#get newer/fixed spack files
#wget https://raw.githubusercontent.com/jdomke/spack/RIKEN_CCS_fugaku5/lib/spack/spack/util/libc.py -O workspace/spack/lib/spack/spack/util/libc.py
for PP in fujitsu-mpi hpcg ; do
	curl "https://raw.githubusercontent.com/spack/spack/develop/var/spack/repos/builtin/packages/${PP}/package.py" -o "${SPACK_REPOS}/builtin/packages/${PP}/package.py"
	[ -f "${SPACK_REPOS}/local/packages/${PP}/package.py" ] && cp "${SPACK_REPOS}/builtin/packages/${PP}/package.py" "${SPACK_REPOS}/local/packages/${PP}/package.py"
done
for PP in hpl; do
	curl "https://raw.githubusercontent.com/jdomke/spack/RIKEN_CCS_fugaku10/var/spack/repos/builtin/packages/${PP}/package.py" -o "${SPACK_REPOS}/builtin/packages/${PP}/package.py"
	[ -f "${SPACK_REPOS}/local/packages/${PP}/package.py" ] && cp "${SPACK_REPOS}/builtin/packages/${PP}/package.py" "${SPACK_REPOS}/local/packages/${PP}/package.py"
done
for PP in fujitsu-ssl2; do
	curl "https://raw.githubusercontent.com/jdomke/spack/RIKEN_CCS_fugaku11/var/spack/repos/builtin/packages/${PP}/package.py" -o "${SPACK_REPOS}/builtin/packages/${PP}/package.py"
done

#XXX: not taken automatically without pre-registering (stupid stack falls back to stuff from other repo) XXX: issue!!! https://github.com/spack/spack/issues/46058
COMPPATH="$(readlink -f "$(dirname "$(which clang)")/../../")"
for PP in fujitsu-mpi@head fujitsu-mpi@4.11.1 fujitsu-ssl2@head fujitsu-ssl2@4.11.1 elfutils@0.186 pmix@2.1.4 hwloc@2.2.0 libevent@2.1.8 papi@5.6.0 binutils@2.41; do
	while true; do
		try_to_build spack install --reuse --deprecated ${PP} %${CLANGCOMP}
		#test if correct
		if spack find -p ${PP} %${CLANGCOMP} | /bin/grep -q " ${COMPPATH}/"; then break; fi
		spack uninstall --yes-to-all ${PP} %${CLANGCOMP}
	done
done

echo "Setup complete, load via:"
echo "    . \"${SPACK_PATH}/share/spack/setup-env.sh\""