#!/bin/bash
#SBATCH --job-name=bcast_fixed_size
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=01:59:59
#SBATCH --partition EPYC
#SBATCH --exclusive


module load openMPI/4.1.6

# Benchmarks parameters
repetitions=5000
size=4


#------------- BCAST 1 -----------
echo "Processes,Size,Latency" > ../results/bcast1_fixed_core.csv # CSV file to store results

# Benchmark loop for different number of processes
for processes in {2..256} # from 2 to 256 tasks (128 per node)
do
    result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 1 ../osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}') # osu_bcast with current processors, fixed message size and fixed number of repetitions
    echo "$processes,$size,$result_bcast" >> ../results/bcast1_fixed_core.csv # CSV file to store results
done
#--------------------------------


#------------- BCAST 3 -----------
echo "Processes,Size,Latency" > ../results/bcast3_fixed_core.csv # CSV file to store results

# Benchmark loop for different number of processes
for processes in {2..256} # from 2 to 256 tasks (128 per node)
do
    # Perform osu_bcast with current processors, fixed message size and fixed number of repetitions
    result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 3 ../osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}') # osu_bcast with current processors, fixed message size and fixed number of repetitions
    echo "$processes,$size,$result_bcast" >> ../results/bcast3_fixed_core.csv # CSV file to store results
done
#--------------------------------


#------------- BCAST 5 -----------
echo "Processes,Size,Latency" > ../results/bcast5_fixed_core.csv # CSV file to store results

# Benchmark loop for different number of processes
for processes in {2..256} # from 2 to 256 tasks (128 per node)
do
    # Perform osu_bcast with current processors, fixed message size and fixed number of repetitions
    result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 5 ../osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}') # osu_bcast with current processors, fixed message size and fixed number of repetitions
    echo "$processes,$size,$result_bcast" >> ../results/bcast5_fixed_core.csv # CSV file to store results
done
#--------------------------------