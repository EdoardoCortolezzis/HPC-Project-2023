#!/bin/bash
#SBATCH --job-name=gather_var_size
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=01:59:59
#SBATCH --partition EPYC
#SBATCH --exclusive

module load openMPI/4.1.6

# Benchmarks parameters
repetitions=5000


#------------- GATHER 1 -----------
echo "Processes,Size,Latency" > ../results/gather1_var_core.csv

for power in {1..8} # 2^1 to 2^8 processes (2, 4, 8, ..., 256)
do
    processes=$((2**power))
    for size_power in {1..10} # 2^1 to 2^10 size (2, 4, 8, ..., 1024)
    do
        size=$((2**size_power)) # variable size
        result_gather=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_gather_algorithm 1 ../osu_gather -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
        echo "$processes,$size,$result_gather" >> ../results/gather1_var_core.csv
    done
done	
#--------------------------------


#------------- GATHER 2 -----------
echo "Processes,Size,Latency" > ../results/gather2_var_core.csv

for power in {1..8} # 2^1 to 2^8 processes (2, 4, 8, ..., 256)
do
    processes=$((2**power))
    for size_power in {1..10} # 2^1 to 2^10 size (2, 4, 8, ..., 1024)
    do
        size=$((2**size_power)) # variable size
        result_gather=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_gather_algorithm 2 ../osu_gather -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
        echo "$processes,$size,$result_gather" >> ../results/gather2_var_core.csv
    done
done	
#--------------------------------


#------------- GATHER 3 -----------
echo "Processes,Size,Latency" > ../results/gather3_var_core.csv

for power in {1..8} # 2^1 to 2^8 processes (2, 4, 8, ..., 256)
do
    processes=$((2**power))
    for size_power in {1..10} # 2^1 to 2^10 size (2, 4, 8, ..., 1024)
    do
        size=$((2**size_power)) # variable size
        result_gather=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_gather_algorithm 3 ../osu_gather -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
        echo "$processes,$size,$result_gather" >> ../results/gather3_var_core.csv
    done
done	
#--------------------------------