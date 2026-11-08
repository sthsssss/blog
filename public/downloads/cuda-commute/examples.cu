#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <vector>

// Standalone publication example; not the mini-infer exercise solution.
void Check(cudaError_t status)
{
    if (status != cudaSuccess)
    {
        throw std::runtime_error(cudaGetErrorString(status));
    }
}

template<class T>
class DeviceBuffer
{
public:
    T* data = nullptr;

    explicit DeviceBuffer(size_t count)
    {
        if (count != 0)
        {
            Check(cudaMalloc(&data, count * sizeof(T)));
        }
    }

    ~DeviceBuffer() { if (data) cudaFree(data); }
    DeviceBuffer(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;
};

template<class T>
class HostBuffer
{
public:
    T* data = nullptr;

    explicit HostBuffer(size_t count)
    {
        Check(cudaMallocHost(&data, count * sizeof(T)));
    }

    ~HostBuffer() { if (data) cudaFreeHost(data); }
    HostBuffer(const HostBuffer&) = delete;
    HostBuffer& operator=(const HostBuffer&) = delete;
};

class Stream
{
public:
    cudaStream_t value = nullptr;
    Stream() { Check(cudaStreamCreateWithFlags(&value, cudaStreamNonBlocking)); }
    ~Stream()
    {
        // Best-effort completion on exceptional exits before buffers are released.
        cudaStreamSynchronize(value);
        cudaStreamDestroy(value);
    }
    Stream(const Stream&) = delete;
    Stream& operator=(const Stream&) = delete;
};

class Event
{
public:
    cudaEvent_t value = nullptr;
    Event() { Check(cudaEventCreate(&value)); }
    ~Event() { cudaEventDestroy(value); }
    Event(const Event&) = delete;
    Event& operator=(const Event&) = delete;
};

__global__ void Add(const float* a, const float* b, float* c, unsigned int count)
{
    unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count)
    {
        c[i] = a[i] + b[i];
    }
}

__global__ void FillPattern(unsigned int* output, unsigned int count)
{
    unsigned int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < count)
    {
        output[index] = 3 * index + 7;
    }
}

__global__ void Scale(const float* input, float* output,
                      float factor, unsigned int count)
{
    unsigned int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < count)
    {
        float value = input[index];
        output[index] = value * factor;
    }
}

__global__ void Relu(const float* input, float* output, unsigned int count)
{
    unsigned int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < count)
    {
        output[index] = fmaxf(input[index], 0.0f);
    }
}

// Contract: exactly 128 threads per block; partial has ceil(count / 128) elements.
__global__ void BlockSum(const float* input, float* partial, unsigned int count)
{
    __shared__ float values[128];
    unsigned int local = threadIdx.x;
    unsigned int index = blockIdx.x * 128 + local;

    values[local] = index < count ? input[index] : 0.0f;
    __syncthreads();

    if (local == 0)
    {
        float sum = 0.0f;
        for (unsigned int i = 0; i < 128; ++i)
        {
            sum += values[i];
        }
        partial[blockIdx.x] = sum;
    }
}

// Contract: weights is outputCount x inputCount, row-major; no output aliasing.
__global__ void Linear(const float* input, const float* weights,
                       const float* bias, float* output,
                       unsigned int inputCount, unsigned int outputCount)
{
    unsigned int o = blockIdx.x * blockDim.x + threadIdx.x;
    if (o >= outputCount)
    {
        return;
    }

    float sum = bias[o];
    for (unsigned int i = 0; i < inputCount; ++i)
    {
        sum += weights[o * inputCount + i] * input[i];
    }
    output[o] = sum;
}

unsigned int GridSize(unsigned int count)
{
    return count / 128 + (count % 128 != 0);
}

void LaunchPattern(unsigned int* output, unsigned int count)
{
    if (count == 0) return;
    constexpr unsigned int blockSize = 128;
    unsigned int gridSize = count / blockSize + (count % blockSize != 0);
    FillPattern<<<gridSize, blockSize>>>(output, count);
    Check(cudaGetLastError());
}

void Require(bool condition)
{
    if (!condition) throw std::runtime_error("Output mismatch");
}

void VerifyAdd()
{
    for (unsigned int count : {0u, 1u, 127u, 128u, 129u, 257u, 1048576u})
    {
        if (count == 0) continue; // Empty input submits no GPU work.
        const size_t bytes = count * sizeof(float);
        HostBuffer<float> a(count), b(count), c(count);
        DeviceBuffer<float> da(count), db(count), dc(count);
        Stream stream; // Destroy before buffers, including exceptional exits.

        for (unsigned int i = 0; i < count; ++i)
        {
            a.data[i] = static_cast<float>(i % 128);
            b.data[i] = -static_cast<float>(i % 17);
        }
        Check(cudaMemcpyAsync(da.data, a.data, bytes, cudaMemcpyHostToDevice, stream.value));
        Check(cudaMemcpyAsync(db.data, b.data, bytes, cudaMemcpyHostToDevice, stream.value));
        Add<<<GridSize(count), 128, 0, stream.value>>>(da.data, db.data, dc.data, count);
        Check(cudaGetLastError());
        Check(cudaMemcpyAsync(c.data, dc.data, bytes, cudaMemcpyDeviceToHost, stream.value));
        Check(cudaStreamSynchronize(stream.value));

        for (unsigned int i = 0; i < count; ++i)
            Require(c.data[i] == a.data[i] + b.data[i]);
    }
    std::cout << "PASS add: 0, 1, 127, 128, 129, 257, 1048576\n";
}

void VerifyPattern()
{
    for (unsigned int count : {0u, 1u, 127u, 128u, 129u, 257u})
    {
        DeviceBuffer<unsigned int> output(count);
        LaunchPattern(output.data, count);
        Check(cudaDeviceSynchronize());

        if (count == 0) continue;
        std::vector<unsigned int> actual(count);
        Check(cudaMemcpy(actual.data(), output.data,
                         count * sizeof(unsigned int), cudaMemcpyDeviceToHost));
        for (unsigned int i = 0; i < count; ++i) Require(actual[i] == 3 * i + 7);
    }
    std::cout << "PASS pattern: 0, 1, 127, 128, 129, 257\n";
}

void VerifyStream()
{
    constexpr unsigned int count = 257;
    constexpr size_t bytes = count * sizeof(float);
    HostBuffer<float> input(count), output(count);
    DeviceBuffer<float> deviceInput(count), deviceOutput(count);
    // Created last so completion precedes buffer destruction on exceptional exits.
    Stream stream;

    for (unsigned int i = 0; i < count; ++i) input.data[i] = static_cast<float>(i) - 128;
    Check(cudaMemcpyAsync(deviceInput.data, input.data, bytes,
                          cudaMemcpyHostToDevice, stream.value));
    Relu<<<GridSize(count), 128, 0, stream.value>>>(
        deviceInput.data, deviceOutput.data, count);
    Check(cudaGetLastError());
    Check(cudaMemcpyAsync(output.data, deviceOutput.data, bytes,
                          cudaMemcpyDeviceToHost, stream.value));
    Check(cudaStreamSynchronize(stream.value));
    for (unsigned int i = 0; i < count; ++i)
        Require(output.data[i] == std::max(input.data[i], 0.0f));

    // Demonstrate an explicit dependency between two non-blocking streams.
    Stream consumer;
    Event ready;
    Scale<<<GridSize(count), 128, 0, stream.value>>>(
        deviceInput.data, deviceOutput.data, 2.0f, count);
    Check(cudaGetLastError());
    Check(cudaEventRecord(ready.value, stream.value));
    Check(cudaStreamWaitEvent(consumer.value, ready.value, 0));
    Check(cudaMemcpyAsync(output.data, deviceOutput.data, bytes,
                          cudaMemcpyDeviceToHost, consumer.value));
    Check(cudaStreamSynchronize(consumer.value));
    for (unsigned int i = 0; i < count; ++i)
        Require(output.data[i] == 2.0f * input.data[i]);
    std::cout << "PASS stream: ReLU and event dependency\n";
}

void VerifyBlockSum()
{
    constexpr unsigned int count = 257;
    std::vector<float> input(count, 1.0f);
    DeviceBuffer<float> deviceInput(count), partial(GridSize(count));
    Check(cudaMemcpy(deviceInput.data, input.data(), count * sizeof(float),
                     cudaMemcpyHostToDevice));
    BlockSum<<<GridSize(count), 128>>>(deviceInput.data, partial.data, count);
    Check(cudaGetLastError());
    Check(cudaDeviceSynchronize());
    float actual[3];
    Check(cudaMemcpy(actual, partial.data, sizeof(actual), cudaMemcpyDeviceToHost));
    Require(actual[0] == 128 && actual[1] == 128 && actual[2] == 1);
    std::cout << "PASS shared memory: [128, 128, 1]\n";
}

void VerifyLinear()
{
    constexpr unsigned int inputs = 2;
    for (unsigned int outputs : {2u, 129u})
    {
        std::vector<float> input{2.0f, 3.0f}, weights(inputs * outputs), bias(outputs);
        for (unsigned int o = 0; o < outputs; ++o)
        {
            weights[o * inputs] = o % 2 == 0 ? 1.0f : -1.0f;
            weights[o * inputs + 1] = o % 2 == 0 ? 2.0f : 1.0f;
            bias[o] = o % 2 == 0 ? 0.5f : -0.5f;
        }
        DeviceBuffer<float> x(inputs), w(weights.size()), b(outputs), y(outputs);
        Check(cudaMemcpy(x.data, input.data(), inputs * sizeof(float), cudaMemcpyHostToDevice));
        Check(cudaMemcpy(w.data, weights.data(), weights.size() * sizeof(float), cudaMemcpyHostToDevice));
        Check(cudaMemcpy(b.data, bias.data(), outputs * sizeof(float), cudaMemcpyHostToDevice));
        Linear<<<GridSize(outputs), 128>>>(x.data, w.data, b.data, y.data, inputs, outputs);
        Check(cudaGetLastError());
        Check(cudaDeviceSynchronize());
        std::vector<float> actual(outputs);
        Check(cudaMemcpy(actual.data(), y.data, outputs * sizeof(float), cudaMemcpyDeviceToHost));
        for (unsigned int o = 0; o < outputs; ++o)
        {
            float expected = o % 2 == 0 ? 8.5f : 0.5f;
            Require(std::isfinite(actual[o]) && actual[o] == expected);
        }
    }
    std::cout << "PASS linear: [8.5, 0.5] and 129 outputs\n";
}

void VerifyEventTiming()
{
    constexpr unsigned int count = 257;
    constexpr unsigned int iterations = 100;
    DeviceBuffer<unsigned int> output(count);
    Stream stream;
    Event start, stop;
    FillPattern<<<GridSize(count), 128, 0, stream.value>>>(output.data, count);
    Check(cudaGetLastError());
    Check(cudaStreamSynchronize(stream.value));
    Check(cudaEventRecord(start.value, stream.value));
    for (unsigned int i = 0; i < iterations; ++i)
    {
        FillPattern<<<GridSize(count), 128, 0, stream.value>>>(output.data, count);
        Check(cudaGetLastError());
    }
    Check(cudaEventRecord(stop.value, stream.value));
    Check(cudaEventSynchronize(stop.value));
    float milliseconds = 0.0f;
    Check(cudaEventElapsedTime(&milliseconds, start.value, stop.value));
    Require(std::isfinite(milliseconds) && milliseconds >= 0.0f);
    std::cout << "PASS event timing: completed 100 launches (not a benchmark)\n";
}

int main()
{
    try
    {
        Check(cudaSetDevice(0));
        VerifyAdd();
        VerifyPattern();
        VerifyStream();
        VerifyBlockSum();
        VerifyLinear();
        VerifyEventTiming();
        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr << "CUDA example: " << error.what() << '\n';
        return 1;
    }
}
