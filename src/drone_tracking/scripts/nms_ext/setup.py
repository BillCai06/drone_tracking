from setuptools import setup
from torch.utils.cpp_extension import BuildExtension, CUDAExtension

setup(
    name="nms_ext",
    ext_modules=[
        CUDAExtension(
            name="nms_ext",
            sources=["nms_kernel.cu", "nms_binding.cpp"],
            include_dirs=[
                "/usr/include/aarch64-linux-gnu",   # TRT 8.5 headers location on Jetson
            ],
            extra_compile_args={
                "cxx":  ["-O3"],
                "nvcc": [
                    "-O3",
                    "-gencode=arch=compute_87,code=sm_87",
                    "--expt-relaxed-constexpr",
                    "--threads", "4",
                ],
            },
        )
    ],
    cmdclass={"build_ext": BuildExtension},
)