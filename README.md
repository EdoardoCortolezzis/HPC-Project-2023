# HPC-Project-2023
Repository for the HPC exam (https://github.com/Foundations-of-HPC/High-Performance-Computing-2023/tree/main).

## Quick Setup on Orfeo Cluster

### 1. Clone and Setup
```bash
git clone https://github.com/your-username/HPC-Project-2023.git
cd HPC-Project-2023
module purge
module load openMPI/4.1.6
```

### 2. Exercise 1 - OSU Benchmarks
```bash
cd ex1/src
chmod +x osu_setup.sh
./osu_setup.sh
chmod +x *.sh

# Run benchmarks
sbatch {bcast,gather}_{fixed,var}_size.sh
```

### 3. Exercise 2 - Mandelbrot
```bash
cd ../ex2/src
chmod +x *.sh

# Run tests
sbatch {mpi,omp}_strong_{rows,cols,borders}.sh
sbatch omp_weak_borders.sh
```

### 4. Monitor Jobs
```bash
squeue -u $USER          # Check job status
cat slurm-<job_id>.out   # View output
```

## Project Status

**Done:**
- Ex1:
    - bcast with algorithm: 1 (basic linear), 3 (pipeline) & 5 (binary tree);
    - gather with algorithm: 1 (basic linear), 2 (binomial) & 3 (linear with synchronization);
    - extracted data with csv format.
- Ex2:
    - static mandelbrot on rows and columns;
    - borders aimed mandelbrot

**To-Do:**
- Ex1:
    - rerun gather 3 fixed (unprinted results after a certain point);
    - analysis;
    - report.
- Ex2:
    - latency file e run su orfeo;
    - collective omp (by pixel);
    - dynamic mandelbrot (master - worker or block);
    - analysis;
    - report.
