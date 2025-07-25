#!/bin/bash
#SBATCH --job-name=MPI-STRONG-BORDERS
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=02:00:00
#SBATCH --partition=EPYC
#SBATCH --exclusive

module purge
module load openMPI/4.1.6

# compile - remove -DDECOMP flag since it's no longer used
mpicc -fopenmp mandel_borders.c -o mandel_borders_mpi -lm

OUTPUT_FILE="../results/mpi-strong/mpi_strong_borders.csv"
echo "cores,threads,width,height,time" > "${OUTPUT_FILE}"

export OMP_NUM_THREADS=1          # pure MPI scaling

# fixed image size
X_LEFT=-2.0
Y_LOWER=-1.0
X_RIGHT=1.0
Y_UPPER=1.0
MAX_ITERATIONS=255
n=10000

for CORES in {1..256}; do
    EXEC_TIME=$(mpirun -np "${CORES}" --map-by core --bind-to core \
                ./mandel_borders_mpi \
                "${n}" "${n}" \
                "${X_LEFT}" "${Y_LOWER}" \
                "${X_RIGHT}" "${Y_UPPER}" \
                "${MAX_ITERATIONS}" 1)

    echo "${CORES},1,${n},${n},${EXEC_TIME}" >> "${OUTPUT_FILE}"
    echo "MPI-STRONG-BORDERS: cores=${CORES}, threads=1, width=${n}, height=${n}, time=${EXEC_TIME}"
done