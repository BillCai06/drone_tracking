#include <torch/extension.h>

// Declared in nms_kernel.cu
torch::Tensor nms_cuda(torch::Tensor boxes, torch::Tensor scores, float iou_thr);
torch::Tensor soft_nms_cuda(torch::Tensor boxes, torch::Tensor scores,
                             float sigma, float score_thr);

PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {
    m.def("nms_cuda",      &nms_cuda,
          "Greedy NMS (CUDA)",
          py::arg("boxes"), py::arg("scores"), py::arg("iou_threshold"));
    m.def("soft_nms_cuda", &soft_nms_cuda,
          "Soft-NMS Gaussian decay (CUDA)",
          py::arg("boxes"), py::arg("scores"),
          py::arg("sigma")=0.5f, py::arg("score_threshold")=0.05f);
}