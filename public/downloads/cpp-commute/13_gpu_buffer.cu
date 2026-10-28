#include <cuda_runtime.h>
#include <cstddef>
#include <cstdio>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>

void check(cudaError_t status, const char* operation) {
    if (status != cudaSuccess) {
        throw std::runtime_error(std::string(operation) + ": " + cudaGetErrorString(status));
    }
}

struct DeviceFree {
    void operator()(float* pointer) const noexcept {
        if (pointer != nullptr) {
            const cudaError_t status = cudaFree(pointer);
            if (status != cudaSuccess) {
                std::fprintf(stderr, "cudaFree: %s\n", cudaGetErrorString(status));
            }
        }
    }
};

struct GpuBuffer {
    std::unique_ptr<float, DeviceFree> storage;
    std::size_t count;

    float* data() { return storage.get(); }
    const float* data() const { return storage.get(); }
};

GpuBuffer allocate_buffer(std::size_t count) {
    if (count == 0 || count > std::numeric_limits<std::size_t>::max() / sizeof(float)) {
        throw std::invalid_argument("invalid element count");
    }
    float* pointer = nullptr;
    check(cudaMalloc(&pointer, count * sizeof(float)), "allocate");
    return GpuBuffer{std::unique_ptr<float, DeviceFree>{pointer}, count};
}

__global__ void add_one(const float* input, float* output, std::size_t count) {
    const std::size_t i = static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (i < count) {
        const float& source = input[i];
        float& target = output[i];
        target = source + 1.0f;
    }
}

// This small teaching helper deliberately launches one block and waits for it.
void run(const GpuBuffer& input, GpuBuffer& output) {
    if (input.count != output.count || output.count == 0 || output.count > 32
        || input.storage == nullptr || output.storage == nullptr) {
        throw std::invalid_argument("expected two live buffers with matching sizes in [1, 32]");
    }
    add_one<<<1, 32>>>(input.data(), output.data(), output.count);
    check(cudaGetLastError(), "launch");
    check(cudaDeviceSynchronize(), "execute");
}

int main() {
    try {
        const float host_input[]{10.0f, 20.0f, 30.0f};
        float host_output[3]{};
        GpuBuffer input = allocate_buffer(3);
        GpuBuffer output = allocate_buffer(3);
        check(cudaMemcpy(input.data(), host_input, sizeof(host_input), cudaMemcpyHostToDevice), "upload");
        run(input, output);

        float* observed_address = output.data();
        GpuBuffer moved = std::move(output);
        check(cudaMemcpy(host_output, moved.data(), sizeof(host_output), cudaMemcpyDeviceToHost), "download");
        for (std::size_t i = 0; i < 3; ++i) {
            if (host_output[i] != host_input[i] + 1.0f) {
                throw std::runtime_error("GPU result mismatch");
            }
        }
        std::cout << "GPU result: " << host_output[0] << ' ' << host_output[1] << ' ' << host_output[2] << '\n';
        std::cout << std::boolalpha << "same device address: " << (moved.data() == observed_address) << '\n';
        std::cout << "old storage empty: " << (output.storage == nullptr) << '\n';
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
