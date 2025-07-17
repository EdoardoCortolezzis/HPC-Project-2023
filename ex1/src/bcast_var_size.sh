#!/bin/bash
#SBATCH --job-name=bcast_var_size
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=01:59:59
#SBATCH --partition EPYC
#SBATCH --exclusive

module load openMPI/4.1.6

# Benchmarks parameters
repetitions=5000


#------------- BCAST 1 -----------
echo "Processes,Size,Latency" > ../results/bcast1_var_core.csv

for power in {1..8} # 2^1 to 2^8 processes (2, 4, 8, ..., 256)
do
	processes=$((2**power))
	for size_power in {1..10} # 2^1 to 2^10 size (2, 4, 8, ..., 1024)
	do
		size=$((2**size_power)) # variable size
		result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 1 ../osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
		echo "$processes,$size,$result_bcast" >> ../results/bcast1_var_core.csv
	done
done	
#--------------------------------


#------------- BCAST 3 -----------
echo "Processes,Size,Latency" > ../results/bcast3_var_core.csv

for power in {1..8} # 2^1 to 2^8 processes (2, 4, 8, ..., 256)
do
	processes=$((2**power))
	for size_power in {1..10} # 2^1 to 2^10 size (2, 4, 8, ..., 1024)
	do
		size=$((2**size_power)) # variable size
		result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 3 ../osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
		echo "$processes,$size,$result_bcast" >> ../results/bcast3_var_core.csv
	done
done	
#--------------------------------


#------------- BCAST 5 -----------
echo "Processes,Size,Latency" > ../results/bcast5_var_core.csv

for power in {1..8} # 2^1 to 2^8 processes (2, 4, 8, ..., 256)
do
	processes=$((2**power))
	for size_power in {1..10} # 2^1 to 2^10 size (2, 4, 8, ..., 1024)
	do
		size=$((2**size_power)) # variable size
		result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 5 ../osu_bcast -m $size -x $repetitions -i $repetitions | tail -n 1 | awk '{print $2}')
		echo "$processes,$size,$result_bcast" >> ../results/bcast5_var_core.csv
	done
done	
#--------------------------------
