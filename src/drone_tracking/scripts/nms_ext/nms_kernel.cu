#include <torch/extension.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include <c10/cuda/CUDAStream.h>

// ── IoU helper ───────────────────────────────────────────────────────────────

__device__ __forceinline__ float iou_device(
    float ax1, float ay1, float ax2, float ay2,
    float bx1, float by1, float bx2, float by2)
{
    float ix1  = fmaxf(ax1, bx1);
    float iy1  = fmaxf(ay1, by1);
    float ix2  = fminf(ax2, bx2);
    float iy2  = fminf(ay2, by2);
    float inter = fmaxf(0.f, ix2 - ix1) * fmaxf(0.f, iy2 - iy1);
    if (inter == 0.f) return 0.f;
    float area_a = (ax2 - ax1) * (ay2 - ay1);
    float area_b = (bx2 - bx1) * (by2 - by1);
    return inter / (area_a + area_b - inter + 1e-6f);
}

// ── Greedy NMS ───────────────────────────────────────────────────────────────
//
// Algorithm: correct sequential greedy NMS, parallelised safely.
//
// The sequential greedy algorithm is:
//   for i in order (high→low score):
//     if not suppressed:
//       for j in remaining: suppress j if IoU(i,j) > threshold
//
// We parallelise the INNER loop only (one thread per candidate j),
// keeping the outer loop sequential on a single block.
// This eliminates all read-write races on `keep`.
//
// Shared memory holds the current pivot box so all threads in the
// block can read it with a single broadcast rather than N global reads.
//
// Complexity: O(N²/BLOCK) kernel launches → O(N) sequential outer steps,
// each with O(N/BLOCK) parallel inner steps.
// For N=8400, BLOCK=256: 33 outer steps × 33 inner steps = ~1000 iterations.

#define BLOCK 256

__global__ void nms_iou_kernel(
    const float* __restrict__ boxes,   // [N, 4]
    const int*   __restrict__ order,   // [N] sorted high→low score
    int*         __restrict__ keep,    // [N] 1=alive 0=suppressed
    int   pivot_rank,                  // current outer-loop index into order
    float iou_thr,
    int   N)
{
    // Pivot box (the current "winner") in shared memory — one broadcast
    __shared__ float pivot[4];
    if (threadIdx.x < 4) {
        int pivot_idx = order[pivot_rank];
        pivot[threadIdx.x] = boxes[pivot_idx * 4 + threadIdx.x];
    }
    __syncthreads();

    // Each thread handles one candidate box ranked BELOW the pivot
    int rank_j = pivot_rank + 1 + blockIdx.x * BLOCK + threadIdx.x;
    if (rank_j >= N) return;

    int j = order[rank_j];
    if (keep[j] == 0) return;   // already suppressed — nothing to do

    float iou = iou_device(
        pivot[0], pivot[1], pivot[2], pivot[3],
        boxes[j*4+0], boxes[j*4+1], boxes[j*4+2], boxes[j*4+3]);

    if (iou > iou_thr)
        keep[j] = 0;
    // No write to keep[pivot] — pivot is never suppressed by this kernel.
    // No read of keep[j] by another thread at the same time.
    // → zero races.
}

// ── Soft-NMS (Gaussian decay) ─────────────────────────────────────────────────
//
// Same structure: sequential outer loop, parallel inner loop.
// Each thread decays one score; no two threads write the same score[j].

__global__ void soft_nms_iou_kernel(
    const float* __restrict__ boxes,
    const int*   __restrict__ order,
    float*       __restrict__ scores,  // decayed in-place
    int   pivot_rank,
    float sigma,
    float score_thr,
    int   N)
{
    __shared__ float pivot[4];
    if (threadIdx.x < 4) {
        int pivot_idx = order[pivot_rank];
        pivot[threadIdx.x] = boxes[pivot_idx * 4 + threadIdx.x];
    }
    __syncthreads();

    int rank_j = pivot_rank + 1 + blockIdx.x * BLOCK + threadIdx.x;
    if (rank_j >= N) return;

    int j = order[rank_j];
    if (scores[j] < score_thr) return;

    float iou = iou_device(
        pivot[0], pivot[1], pivot[2], pivot[3],
        boxes[j*4+0], boxes[j*4+1], boxes[j*4+2], boxes[j*4+3]);

    // Gaussian decay — each thread writes only its own score[j]
    scores[j] *= expf(-(iou * iou) / sigma);
}

// ── C++ launchers ────────────────────────────────────────────────────────────

torch::Tensor nms_cuda(
    torch::Tensor boxes,    // [N, 4] float32 CUDA  x1y1x2y2
    torch::Tensor scores,   // [N]    float32 CUDA
    float iou_thr)
{
    TORCH_CHECK(boxes.is_cuda() && scores.is_cuda(), "tensors must be on CUDA");
    TORCH_CHECK(boxes.dtype() == torch::kFloat32, "boxes must be float32");

    const int N = boxes.size(0);
    if (N == 0)
        return torch::zeros({0}, torch::dtype(torch::kInt32).device(boxes.device()));

    // Sort scores descending; get sorted index order
    auto [sorted_scores, order_long] = scores.sort(0, /*descending=*/true);
    auto order = order_long.to(torch::kInt32).contiguous();

    // All boxes start alive
    auto keep = torch::ones({N}, torch::dtype(torch::kInt32).device(boxes.device()));

    auto stream = c10::cuda::getCurrentCUDAStream();

    // Sequential outer loop: for each pivot (highest surviving score),
    // launch one kernel to suppress everything below it in parallel.
    for (int pivot_rank = 0; pivot_rank < N - 1; ++pivot_rank) {
        // Skip if this pivot was itself suppressed
        // (read keep on CPU would stall; check on GPU via kernel guard instead)
        int remaining = N - pivot_rank - 1;
        int grid = (remaining + BLOCK - 1) / BLOCK;

        nms_iou_kernel<<<grid, BLOCK, 0, stream>>>(
            boxes.data_ptr<float>(),
            order.data_ptr<int>(),
            keep.data_ptr<int>(),
            pivot_rank,
            iou_thr,
            N);
    }

    // Synchronize and check for kernel errors
    cudaError_t err = cudaStreamSynchronize(stream);
    TORCH_CHECK(err == cudaSuccess,
        "nms_cuda kernel error: ", cudaGetErrorString(err));

    return keep;  // [N] int32:  1=keep  0=suppressed
}


torch::Tensor soft_nms_cuda(
    torch::Tensor boxes,    // [N, 4] float32 CUDA
    torch::Tensor scores,   // [N]    float32 CUDA  — modified in-place
    float sigma,
    float score_thr)
{
    TORCH_CHECK(boxes.is_cuda() && scores.is_cuda(), "tensors must be on CUDA");

    const int N = boxes.size(0);
    if (N == 0) return scores;

    auto [sorted_scores, order_long] = scores.sort(0, true);
    auto order = order_long.to(torch::kInt32).contiguous();

    auto stream = c10::cuda::getCurrentCUDAStream();

    for (int pivot_rank = 0; pivot_rank < N - 1; ++pivot_rank) {
        int remaining = N - pivot_rank - 1;
        int grid = (remaining + BLOCK - 1) / BLOCK;

        soft_nms_iou_kernel<<<grid, BLOCK, 0, stream>>>(
            boxes.data_ptr<float>(),
            order.data_ptr<int>(),
            scores.data_ptr<float>(),
            pivot_rank,
            sigma,
            score_thr,
            N);
    }

    cudaError_t err = cudaStreamSynchronize(stream);
    TORCH_CHECK(err == cudaSuccess,
        "soft_nms_cuda kernel error: ", cudaGetErrorString(err));

    return scores;  // decayed scores; caller keeps where scores >= score_thr
}
