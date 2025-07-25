#!/bin/bash
#SBATCH --job-name=MPI-COLS
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=02:00:00
#SBATCH --partition=EPYC
#SBATCH --exclusive

module purge
module load openMPI/4.1.6

# --- compile the column version ---
mpicc -fopenmp mandel_cols.c -o mandel_cols -lm

# --- strong-scaling loop ---
OUTPUT_FILE="../results/mpi-strong/mpi_strong_cols.csv"
echo "cores,threads,width,height,time" > "${OUTPUT_FILE}"

export OMP_NUM_THREADS=1          # keep 1 OMP thread per rank

X_LEFT=-2.0
Y_LOWER=-1.0
X_RIGHT=1.0
Y_UPPER=1.0
MAX_ITERATIONS=255
n=10000

for CORES in {1..256}; do
    EXEC_TIME=$(mpirun -np "${CORES}" ./mandel_cols \
                "${n}" "${n}" \
                "${X_LEFT}" "${Y_LOWER}" \
                "${X_RIGHT}" "${Y_UPPER}" \
                "${MAX_ITERATIONS}" 1)

    echo "${CORES},1,${n},${n},${EXEC_TIME}" >> "${OUTPUT_FILE}"
    echo "COLS: cores=${CORES}, threads=1, width=${n}, height=${n}, time=${EXEC_TIME}"
done