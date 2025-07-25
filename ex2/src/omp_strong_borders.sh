#!/bin/bash
#SBATCH --job-name=OMP-STRONG-BORDERS
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --time=02:00:00
#SBATCH --partition=EPYC
#SBATCH --exclusive

module purge
module load openMPI/4.1.6

# compile - remove -DDECOMP flag since it's no longer used
mpicc -fopenmp mandel_borders.c -o mandel_borders_omp -lm

OUTPUT_FILE="../results/omp-strong/omp_strong_borders.csv"
echo "cores,threads,width,height,time" > "${OUTPUT_FILE}"

# fixed image size
X_LEFT=-2.0
Y_LOWER=-1.0
X_RIGHT=1.0
Y_UPPER=1.0
MAX_ITERATIONS=255
n=10000

for THREADS in {1..128}; do
    export OMP_NUM_THREADS=$THREADS
    export OMP_PLACES=threads
    export OMP_PROC_BIND=true

    EXEC_TIME=$(mpirun -np 1 --map-by socket --bind-to socket \
                ./mandel_borders_omp \
                "${n}" "${n}" \
                "${X_LEFT}" "${Y_LOWER}" \
                "${X_RIGHT}" "${Y_UPPER}" \
                "${MAX_ITERATIONS}" "${THREADS}")

    echo "1,${THREADS},${n},${n},${EXEC_TIME}" >> "${OUTPUT_FILE}"
    echo "OMP-STRONG-BORDERS: cores=1, threads=${THREADS}, width=${n}, height=${n}, time=${EXEC_TIME}"
done