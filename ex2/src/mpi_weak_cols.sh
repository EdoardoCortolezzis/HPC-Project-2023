#!/bin/bash
#SBATCH --job-name=MPI-WEAK-COLS
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=02:00:00
#SBATCH --partition=EPYC
#SBATCH --exclusive

module purge
module load openMPI/4.1.6

mpicc -fopenmp mandel_cols.c -o mandel_cols_mpi -lm

OUTPUT_FILE="../results/mpi-weak/mpi_weak_cols.csv"
echo "cores,threads,width,height,time" > "${OUTPUT_FILE}"

export OMP_NUM_THREADS=1

X_LEFT=-2.0
Y_LOWER=-1.0
X_RIGHT=1.0
Y_UPPER=1.0
MAX_ITERATIONS=255
C=1000000

for CORES in {1..256}; do
    n=$(echo "scale=0; sqrt($CORES * $C)/1" | bc)   # integer side length
    EXEC_TIME=$(mpirun -np "${CORES}" \
                --map-by core --bind-to core \
                ./mandel_cols_mpi \
                "${n}" "${n}" \
                "${X_LEFT}" "${Y_LOWER}" \
                "${X_RIGHT}" "${Y_UPPER}" \
                "${MAX_ITERATIONS}" 1)

    echo "${CORES},1,${n},${n},${EXEC_TIME}" >> "${OUTPUT_FILE}"
    echo "MPI-COLS-WEAK: cores=${CORES}, threads=1, width=${n}, height=${n}, time=${EXEC_TIME}"
done