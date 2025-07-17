#!/bin/bash

# OSU Benchmark Setup Script
# This script downloads, compiles, and sets up OSU benchmarks for the HPC project

set -e  # Exit on any error

echo "=== OSU Benchmark Setup Script ==="

# Configuration
OSU_VERSION="7.4"  # Latest version from official site
OSU_URL="https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${OSU_VERSION}.tar.gz"
OSU_DIR="osu-micro-benchmarks-${OSU_VERSION}"
INSTALL_DIR="$(pwd)/osu_benchmarks"

echo "Downloading OSU Micro-Benchmarks version ${OSU_VERSION}..."

# Download OSU benchmarks
if [ ! -f "${OSU_DIR}.tar.gz" ]; then
    wget "${OSU_URL}" || curl -O "${OSU_URL}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download OSU benchmarks"
        echo "Please check your internet connection or download manually from:"
        echo "${OSU_URL}"
        exit 1
    fi
else
    echo "OSU benchmark archive already exists, skipping download..."
fi

# Extract
echo "Extracting OSU benchmarks..."
if [ ! -d "${OSU_DIR}" ]; then
    tar -xzf "${OSU_DIR}.tar.gz"
fi

# Navigate to source directory
cd "${OSU_DIR}"

# Load OpenMPI module (adjust for your cluster)
echo "Loading OpenMPI module..."
module load openMPI/4.1.6

# Configure - following official documentation
echo "Configuring OSU benchmarks..."
./configure CC=mpicc CXX=mpicxx

# Compile
echo "Compiling OSU benchmarks..."
make

# Go back to src directory
cd ..

# Create symlinks for easy access - correct paths from documentation
echo "Creating symbolic links..."
ln -sf "src/${OSU_DIR}/c/mpi/collective/blocking/osu_bcast" ../osu_bcast
ln -sf "src/${OSU_DIR}/c/mpi/collective/blocking/osu_gather" ../osu_gather


# Create results directory
echo "Creating results directory..."
mkdir -p ../results

# Verify installation
echo "Verifying installation..."
if [ -x "../osu_bcast" ] && [ -x "../osu_gather" ]; then
    echo "✅ OSU benchmarks successfully installed!"
    echo "📁 Source directory: ${OSU_DIR}"
    echo "🔗 Symbolic links created in ex1 directory"
    echo ""
    echo "Available benchmarks:"
    ls -la ../osu_*
    echo ""
    echo "Testing osu_bcast with 2 processes..."
    mpirun -np 2 ../osu_bcast -m 4 -x 10 -i 10 | head -5
    echo ""
    echo "You can now run your benchmark scripts with:"
    echo "  sbatch bcast_fixed_size.sh"
    echo "  sbatch bcast_var_size.sh"
else
    echo "❌ Installation verification failed!"
    echo "Expected files not found at:"
    echo "  ${OSU_DIR}/c/mpi/collective/blocking/osu_bcast"
    echo "  ${OSU_DIR}/c/mpi/collective/blocking/osu_gather"
    exit 1
fi

# Cleanup (optional)
read -p "Do you want to remove the downloaded archive to save space? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleaning up archive..."
    rm -f "${OSU_DIR}.tar.gz"
    echo "✅ Cleanup completed (source directory kept for potential recompilation)"
fi

echo "=== Setup Complete ==="