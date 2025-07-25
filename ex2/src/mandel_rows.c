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

    /* --------------- row decomposition --------------- */
    int base_rows = height / P;
    int rem_rows  = height % P;
    int my_rows   = base_rows + (rank < rem_rows ? 1 : 0);
    int my_off    = rank * base_rows + (rank < rem_rows ? rank : rem_rows);

    unsigned char *buf = (unsigned char *)malloc(my_rows * width);
    double t0 = MPI_Wtime();

    #pragma omp parallel for schedule(dynamic)
    for (int j = 0; j < my_rows; ++j) {
        int global_j = my_off + j;
        double y = y0 + global_j * (y1 - y0) / height;
        for (int i = 0; i < width; ++i) {
            double x = x0 + i * (x1 - x0) / width;
            buf[j * width + i] = mandelbrot(x, y, max_iter);
        }
    }

    /* --------------- gather on rank 0 --------------- */
    int *recvcounts = NULL, *displs = NULL;
    unsigned char *image = NULL;

    if (rank == 0) {
        recvcounts = (int *)malloc(P * sizeof(int));
        displs     = (int *)malloc(P * sizeof(int));
        image      = (unsigned char *)malloc(width * height);
        for (int p = 0, pos = 0; p < P; ++p) {
            int rows = base_rows + (p < rem_rows ? 1 : 0);
            recvcounts[p] = rows * width;
            displs[p]     = pos;
            pos          += rows * width;
        }
    }

    MPI_Gatherv(buf, my_rows * width, MPI_UNSIGNED_CHAR,
                image, recvcounts, displs, MPI_UNSIGNED_CHAR,
                0, MPI_COMM_WORLD);

    double elapsed = MPI_Wtime() - t0;

    if (rank == 0) {
        /* --------------- write PGM (optional) --------------- */
        FILE *f = fopen("image_rows.pgm", "wb");
        if (f) {
            fprintf(f, "P5\n%d %d\n255\n", width, height);
            fwrite(image, 1, width * height, f);
            fclose(f);
        }
        free(image);
        free(recvcounts);
        free(displs);
        /* --------------- ONLY THIS LINE ON STDOUT --------------- */
        printf("%.6f\n", elapsed);
    }

    free(buf);
    MPI_Finalize();
    return 0;
}