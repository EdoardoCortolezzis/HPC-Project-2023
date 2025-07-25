/*  MPI/OpenMP Mandelbrot – column decomposition  */

#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>
#include <omp.h>

static inline unsigned char mandelbrot(double cr, double ci, int max_iter)
{
    double zr = cr, zi = ci;
    for (int n = 0; n < max_iter; ++n) {
        double r2 = zr * zr, i2 = zi * zi;
        if (r2 + i2 > 4.0) return (unsigned char)n;
        zi = 2.0 * zr * zi + ci;
        zr = r2 - i2 + cr;
    }
    return (unsigned char)max_iter;
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int rank, P;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &P);

    /* ---------------- read parameters ---------------- */
    if (argc != 9) {
        if (rank == 0) fprintf(stderr, "wrong args\n");
        MPI_Finalize();
        return 1;
    }
    const int width   = atoi(argv[1]);
    const int height  = atoi(argv[2]);
    const double x0   = atof(argv[3]);
    const double y0   = atof(argv[4]);
    const double x1   = atof(argv[5]);
    const double y1   = atof(argv[6]);
    const int max_iter = atoi(argv[7]);
    const int nthreads = atoi(argv[8]);
    omp_set_num_threads(nthreads);

    /* ------------- column decomposition -------------- */
    int base_cols = width / P;
    int rem_cols  = width % P;
    int my_cols   = base_cols + (rank < rem_cols ? 1 : 0);
    int my_off    = rank * base_cols + (rank < rem_cols ? rank : rem_cols);

    /* local buffer is stored column-major */
    unsigned char *buf = (unsigned char *)malloc(my_cols * height);
    double t0 = MPI_Wtime();

    #pragma omp parallel for schedule(dynamic)
    for (int i = 0; i < my_cols; ++i) {
        int global_i = my_off + i;
        double x = x0 + global_i * (x1 - x0) / width;
        for (int j = 0; j < height; ++j) {
            double y = y0 + j * (y1 - y0) / height;
            buf[i * height + j] = mandelbrot(x, y, max_iter);
        }
    }

    /* ------------- gather on rank 0 -------------- */
    int *recvcounts = NULL, *displs = NULL;
    unsigned char *image = NULL;

    if (rank == 0) {
        recvcounts = (int *)malloc(P * sizeof(int));
        displs     = (int *)malloc(P * sizeof(int));
        image      = (unsigned char *)malloc(width * height);
        for (int p = 0, pos = 0; p < P; ++p) {
            int cols = base_cols + (p < rem_cols ? 1 : 0);
            recvcounts[p] = cols * height;
            displs[p]     = pos;
            pos          += cols * height;
        }
    }

    MPI_Gatherv(buf, my_cols * height, MPI_UNSIGNED_CHAR,
                image, recvcounts, displs, MPI_UNSIGNED_CHAR,
                0, MPI_COMM_WORLD);

    double elapsed = MPI_Wtime() - t0;

    if (rank == 0) {
        /* transpose back to row-major for PGM */
        unsigned char *row_major = (unsigned char *)malloc(width * height);
        for (int p = 0, col0 = 0; p < P; ++p) {
            int cols = base_cols + (p < rem_cols ? 1 : 0);
            for (int i = 0; i < cols; ++i)
                for (int j = 0; j < height; ++j)
                    row_major[j * width + (col0 + i)] =
                        image[displs[p] + i * height + j];
            col0 += cols;
        }

        FILE *f = fopen("image_cols.pgm", "wb");
        if (f) {
            fprintf(f, "P5\n%d %d\n255\n", width, height);
            fwrite(row_major, 1, width * height, f);
            fclose(f);
        }
        free(row_major);
        free(image);
        free(recvcounts);
        free(displs);
        printf("%.6f\n", elapsed);
    }

    free(buf);
    MPI_Finalize();
    return 0;
}