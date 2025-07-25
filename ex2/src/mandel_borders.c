#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>
#include <omp.h>
#include <math.h>

static inline int mandel_iter(double cr, double ci, int max_iter)
{
    double zr = cr, zi = ci;
    for (int n = 0; n < max_iter; ++n) {
        double r2 = zr * zr, i2 = zi * zi;
        if (r2 + i2 > 4.0) return n;
        zi = 2.0 * zr * zi + ci;
        zr = r2 - i2 + cr;
    }
    return max_iter;
}

/* Check if a point is on the border of the Mandelbrot set */
static inline int is_border_point(int W, int H, int i, int j, 
                                  double x0, double y0, double x1, double y1, int max_iter)
{
    double cx = x0 + i * (x1 - x0) / W;
    double cy = y0 + j * (y1 - y0) / H;
    int center_iter = mandel_iter(cx, cy, max_iter);
    
    /* Point must be in the set to be a border point */
    if (center_iter != max_iter) return 0;
    
    /* Check 4-connected neighbors */
    int dx[] = {-1, 1, 0, 0};
    int dy[] = {0, 0, -1, 1};
    
    for (int k = 0; k < 4; ++k) {
        int ni = i + dx[k];
        int nj = j + dy[k];
        
        /* Boundary of image counts as "outside" */
        if (ni < 0 || ni >= W || nj < 0 || nj >= H) return 1;
        
        double ncx = x0 + ni * (x1 - x0) / W;
        double ncy = y0 + nj * (y1 - y0) / H;
        int neighbor_iter = mandel_iter(ncx, ncy, max_iter);
        
        /* If any neighbor is outside the set, this is a border point */
        if (neighbor_iter != max_iter) return 1;
    }
    
    return 0;
}

/* Flood-fill to mark interior points */
static void flood_fill(char *mask, int W, int H,
                       int *border_x, int *border_y, int border_cnt,
                       double x0, double y0, double x1, double y1, int max_iter)
{
    /* Mark all border points as "inside" */
    for (int k = 0; k < border_cnt; ++k) {
        int x = border_x[k], y = border_y[k];
        if (x >= 0 && x < W && y >= 0 && y < H) {
            mask[y * W + x] = 1;
        }
    }
    
    /* Iterative flood fill from border points */
    int changed = 1;
    while (changed) {
        changed = 0;
        #pragma omp parallel for collapse(2) reduction(||:changed)
        for (int j = 0; j < H; ++j) {
            for (int i = 0; i < W; ++i) {
                if (!mask[j * W + i]) {
                    /* Check if any neighbor is marked as inside */
                    int neighbors_inside = 0;
                    if (i > 0 && mask[j * W + (i-1)]) neighbors_inside = 1;
                    if (i < W-1 && mask[j * W + (i+1)]) neighbors_inside = 1;
                    if (j > 0 && mask[(j-1) * W + i]) neighbors_inside = 1;
                    if (j < H-1 && mask[(j+1) * W + i]) neighbors_inside = 1;
                    
                    if (neighbors_inside) {
                        /* Check if this point is in the Mandelbrot set */
                        double cx = x0 + i * (x1 - x0) / W;
                        double cy = y0 + j * (y1 - y0) / H;
                        if (mandel_iter(cx, cy, max_iter) == max_iter) {
                            mask[j * W + i] = 1;
                            changed = 1;
                        }
                    }
                }
            }
        }
    }
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int rank, P;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &P);

    /* Parse arguments */
    if (argc != 9) {
        if (rank == 0) fprintf(stderr, "Usage: %s width height x0 y0 x1 y1 max_iter nthreads\n", argv[0]);
        MPI_Finalize();
        return 1;
    }
    
    const int width = atoi(argv[1]);
    const int height = atoi(argv[2]);
    const double x0 = atof(argv[3]);
    const double y0 = atof(argv[4]);
    const double x1 = atof(argv[5]);
    const double y1 = atof(argv[6]);
    const int max_iter = atoi(argv[7]);
    const int nthreads = atoi(argv[8]);
    omp_set_num_threads(nthreads);

    /* Row decomposition - distribute rows among processes */
    int my_size = height / P + (rank < height % P ? 1 : 0);
    int my_off = rank * (height / P) + (rank < height % P ? rank : height % P);

    /* Allocate border point storage per thread */
    int num_threads = omp_get_max_threads();
    int max_points = width * my_size; /* realistic upper bound */
    
    int **thread_bx = malloc(num_threads * sizeof(int*));
    int **thread_by = malloc(num_threads * sizeof(int*));
    int *thread_counts = calloc(num_threads, sizeof(int));
    
    for (int t = 0; t < num_threads; t++) {
        thread_bx[t] = malloc(max_points * sizeof(int));
        thread_by[t] = malloc(max_points * sizeof(int));
    }

    double t0 = MPI_Wtime();

    /* Parallel border detection */
    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        #pragma omp for schedule(dynamic)
        for (int jj = 0; jj < my_size; ++jj) {
            int j = my_off + jj;
            for (int i = 0; i < width; ++i) {
                if (is_border_point(width, height, i, j, x0, y0, x1, y1, max_iter)) {
                    int idx = thread_counts[tid]++;
                    thread_bx[tid][idx] = i;
                    thread_by[tid][idx] = j;
                }
            }
        }
    }

    /* Combine results from all threads */
    int border_cnt = 0;
    for (int t = 0; t < num_threads; t++) {
        border_cnt += thread_counts[t];
    }
    
    int *bx = malloc(border_cnt * sizeof(int));
    int *by = malloc(border_cnt * sizeof(int));
    int pos = 0;
    
    for (int t = 0; t < num_threads; t++) {
        for (int i = 0; i < thread_counts[t]; i++) {
            bx[pos] = thread_bx[t][i];
            by[pos] = thread_by[t][i];
            pos++;
        }
        free(thread_bx[t]);
        free(thread_by[t]);
    }
    free(thread_bx);
    free(thread_by);
    free(thread_counts);

    /* Gather all border points to rank 0 */
    int *recv_counts = NULL, *displs = NULL;
    if (rank == 0) {
        recv_counts = malloc(P * sizeof(int));
        displs = malloc(P * sizeof(int));
    }
    
    MPI_Gather(&border_cnt, 1, MPI_INT, recv_counts, 1, MPI_INT, 0, MPI_COMM_WORLD);

    int total_borders = 0;
    int *all_bx = NULL, *all_by = NULL;
    
    if (rank == 0) {
        for (int p = 0, pos = 0; p < P; ++p) {
            displs[p] = pos;
            pos += recv_counts[p];
            total_borders += recv_counts[p];
        }
        all_bx = malloc(total_borders * sizeof(int));
        all_by = malloc(total_borders * sizeof(int));
    }
    
    MPI_Gatherv(bx, border_cnt, MPI_INT, all_bx, recv_counts, displs, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Gatherv(by, border_cnt, MPI_INT, all_by, recv_counts, displs, MPI_INT, 0, MPI_COMM_WORLD);

    /* Global flood-fill on rank 0 */
    char *mask = NULL;
    if (rank == 0) {
        mask = calloc(width * height, 1);
        flood_fill(mask, width, height, all_bx, all_by, total_borders, x0, y0, x1, y1, max_iter);
        free(all_bx);
        free(all_by);
    }

    /* Scatter mask back to processes */
    int stripe_size = my_size * width;
    char *stripe = malloc(stripe_size);
    
    int *send_counts = NULL, *send_displs = NULL;
    if (rank == 0) {
        send_counts = malloc(P * sizeof(int));
        send_displs = malloc(P * sizeof(int));
        
        for (int p = 0, pos = 0; p < P; ++p) {
            int p_size = height / P + (p < height % P ? 1 : 0);
            send_counts[p] = p_size * width;
            send_displs[p] = pos;
            pos += send_counts[p];
        }
    }
    
    MPI_Scatterv(mask, send_counts, send_displs, MPI_CHAR, 
                 stripe, stripe_size, MPI_CHAR, 0, MPI_COMM_WORLD);

    /* Convert to 0/255 image */
    unsigned char *img = malloc(stripe_size);
    for (int i = 0; i < stripe_size; ++i) {
        img[i] = stripe[i] ? 255 : 0;
    }

    /* Gather final image */
    unsigned char *final_img = NULL;
    if (rank == 0) {
        final_img = malloc(width * height);
    }
    
    MPI_Gatherv(img, stripe_size, MPI_UNSIGNED_CHAR,
                final_img, send_counts, send_displs, MPI_UNSIGNED_CHAR, 0, MPI_COMM_WORLD);

    double elapsed = MPI_Wtime() - t0;

    /* Write result and cleanup */
    if (rank == 0) {
        FILE *f = fopen("border_image.pgm", "wb");
        if (f) {
            fprintf(f, "P5\n%d %d\n255\n", width, height);
            fwrite(final_img, 1, width * height, f);
            fclose(f);
        }
        
        printf("%.6f\n", elapsed);
        
        free(final_img);
        free(mask);
        free(recv_counts);
        free(displs);
        free(send_counts);
        free(send_displs);
    }

    free(stripe);
    free(img);
    free(bx);
    free(by);

    MPI_Finalize();
    return 0;
}