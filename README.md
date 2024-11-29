To install Spack 0.22.2 and initialize with LLVM 19.1.4 compiler execute the following command on the login node
```
curl -OfsSL https://raw.githubusercontent.com/RIKEN-RCCS/PrivLLVMSpack/main/spck0.22_llvm19.sh && pjsub spack0.22_llvm19.sh
```

This will submit a job for you. After the job finishes you can use the private spack via
```
source ${SPACK_PATH}/share/spack/setup-env.sh
```

${SPACK_PATH} is usually points to .spack-llvm-v19.1.4/ folder within one of your data directories, and not your home folder. You may change the default path when submitting the job, e.g.
```
pjsub -x "SPACK_PATH=$HOME/newspack" ./spack0.22_llvm19.sh
```
