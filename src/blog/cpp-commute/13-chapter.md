---
title: "C++ 출근길 13 — GPU 버퍼로 전체 흐름 연결하기"
description: "주소·참조·const·관리 객체·장치 메모리와 이동. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:51+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute", "cuda"]
---

앞 편에서는 원본을 찾는 주소 값이 레지스터에만 남을 수 있고, 다른 함수가 객체를 읽어야 하면 주소를 담은 메모리 배치가 필요할 수 있음을 보았습니다. CUDA 버퍼에서도 먼저 같은 구분을 합니다. CPU 쪽 관리 객체, 그 객체가 가진 장치 주소, GPU 메모리의 실제 원소는 서로 다른 대상입니다.

CUDA를 개발하는 NVIDIA의 공식 문서는 일반 장치 메모리를 `cudaMalloc`으로 할당하고 복사 API로 데이터를 전송하는 사용법을 설명하고 있습니다. 이 글은 이 방식으로 할당한 메모리를 사용합니다. CPU와 GPU에서 함께 접근하는 Unified Memory 등의 별도 방식에는 다른 조건이 적용됩니다. [NVIDIA: 장치 메모리](https://docs.nvidia.com/cuda/archive/12.6.3/cuda-c-programming-guide/index.html#device-memory)

```cpp
float* device_data = nullptr;
cudaMalloc(&device_data, 3 * sizeof(float));
```

설명을 위해 할당 부분만 떼어 냈습니다. 성공하면 GPU 쪽에 세 원소를 담을 공간이 생기고 CPU 쪽 포인터 변수에 그 시작 주소가 기록됩니다. `&device_data`는 함수가 결과 주소를 써 넣을 수 있도록 포인터 변수 자체의 주소를 제공하는 표현식입니다. 5편에서 호출자의 포인터를 수정하려면 그 포인터 객체에 접근해야 했던 것과 같은 관계입니다.

**주소를 복사하는 것과 원소를 전송하는 것은 별도 연산입니다.**

```cpp
float* same_address = device_data;
float host_values[]{10.0f, 20.0f, 30.0f};
cudaMemcpy(device_data, host_values, sizeof(host_values),
           cudaMemcpyHostToDevice);
```

첫 줄은 주소 값만 복사합니다. GPU 메모리를 새로 할당하거나 원소를 전송하지 않습니다. 뒤의 `cudaMemcpy`가 CPU 배열의 바이트를 GPU 저장 공간에 복사합니다. 이 할당 방식의 장치 메모리를 CPU에서 `*device_data`로 직접 읽는 코드로 바꿀 수는 없습니다. C++의 `float*`만으로 CPU 주소와 GPU 주소를 구별하지 않으므로 할당 API와 실행 위치도 함께 알아야 합니다.

포인터를 쓰는 이유는 시작 주소와 길이로 연속된 원소를 다루기 때문입니다. `float&` 하나는 한 원소에 대한 참조이므로 동적 길이 버퍼 전체를 대신 표현하지 않습니다. 고정 크기 배열 참조나 범위 타입도 존재하지만, 원시 주소를 요구하는 API의 계약은 그에 맞춰 사용합니다.

**GPU 코드에서도 원소에 참조를 연결할 수 있습니다.**

```cpp
__global__ void add_one(const float* input, float* output,
                       std::size_t count) {
    const std::size_t i =
        static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (i < count) {
        const float& source = input[i];
        float& target = output[i];
        target = source + 1.0f;
    }
}
```

`__global__` 함수는 GPU에서 실행하는 커널입니다. 블록 번호 `blockIdx.x`, 블록당 스레드 수 `blockDim.x`, 블록 안 번호 `threadIdx.x`로 원소 번호를 계산합니다. `std::size_t`는 크기를 표현하는 부호 없는 정수 타입이며 앞의 형 변환은 큰 인덱스를 계산할 타입을 정합니다.

`source`는 읽기 전용 원소 참조이고 `target`은 수정 가능한 출력 원소 참조입니다. 이 선언으로 새 원소를 만들지 않습니다. `target`에 대입하면 GPU 원소가 수정됩니다. 참조 대상을 정해 사용하는 언어 규칙과, 컴파일러가 원소를 읽고 쓰는 명령으로 구현하는 관계는 CPU에서 살펴본 원리와 같습니다. GPU에는 별도의 명령 집합과 호출 방식이 있으므로 앞의 `rdi` 같은 CPU 레지스터 이름을 그대로 적용하지 않습니다.

입력 포인터의 const는 그 경로를 통한 쓰기를 제한합니다. 같은 GPU 메모리에 수정 가능한 다른 별칭이 있다면 메모리 자체가 잠기는 것은 아닙니다. 이 예제는 입력과 출력을 따로 할당합니다.

**관리 객체에는 소유권과 const 접근 경로를 제공합니다.**

```cpp
struct GpuBuffer {
    std::unique_ptr<float, DeviceFree> storage;
    std::size_t count;
    float* data() { return storage.get(); }
    const float* data() const { return storage.get(); }
};
```

10편의 unique_ptr에 `DeviceFree`라는 사용자 정의 해제 함수를 연결했습니다. 장치 메모리는 기본 `delete`가 아니라 `cudaFree`로 해제해야 하기 때문입니다. `count`는 원소 개수입니다. 이 관리 객체는 CPU에 존재하며 장치 주소를 가지고 해제 책임을 맡습니다.

수정 가능한 관리 객체의 `data()`는 `float*`를 반환하고 const 관리 객체의 `data()`는 `const float*`를 반환하도록 설계했습니다. 둘은 함수 뒤의 const로 구별되는 오버로드입니다. 반환 타입에 const를 붙인 경로를 제공한 것이지 GPU 메모리의 모든 별칭을 금지한 것은 아닙니다.

```cpp
void run(const GpuBuffer& input, GpuBuffer& output);
GpuBuffer input = allocate_buffer(3);
GpuBuffer output = allocate_buffer(3);
run(input, output);
GpuBuffer moved = std::move(output);
```

`allocate_buffer`는 새 소유 객체를 값으로 반환합니다. `run`은 CPU 함수이며 관리 객체를 복사하지 않고 참조로 접근합니다. 내부에서는 장치 주소와 길이를 커널에 전달합니다. 커널 완료를 동기화한 뒤 마지막 줄에서 관리 객체를 이동 생성합니다.

이 이동은 GPU 원소의 전송이 아닙니다. 기본 이동 생성자가 unique_ptr 멤버의 소유권을 옮기고 개수 값을 복사합니다. `moved`가 같은 장치 주소를 관리하며 기존 `output.storage`는 비어 있습니다. `output.count`까지 자동으로 0이 되지는 않으므로 이동한 객체의 모든 필드가 초기 상태가 된다고 가정하면 안 됩니다.

일반 커널 실행 요청은 CPU에 대해 비동기적입니다. 참조 매개변수를 사용하는 CPU 함수가 반환했다는 사실만으로 GPU의 버퍼 사용이 끝나는 것은 아닙니다. 첨부 예제는 완료를 명시적으로 기다려 수명 관계를 단순하게 유지했습니다. [NVIDIA: 비동기 실행](https://docs.nvidia.com/cuda/archive/12.6.3/cuda-c-programming-guide/index.html#asynchronous-concurrent-execution)

**실제 실행에서 서로 다른 세 동작을 확인합니다.**

입력 `{10, 20, 30}`을 전송해 GPU에서 계산한 결과는 `{11, 21, 31}`이었습니다. 관리 객체 이동 전후의 장치 주소는 같았으며 이동한 원본 unique_ptr는 비어 있었습니다. 수치 계산, 주소 유지, 해제 책임 이전을 각각 확인한 결과입니다. 메모리 할당이나 전송 비용에 대한 성능 벤치마크는 이 결과에 포함되지 않습니다.

전체 실행 코드: [13_gpu_buffer.cu](/downloads/cpp-commute/13_gpu_buffer.cu). 할당·해제·오류 검사·커널과 CPU 기준값 비교가 들어 있습니다. 현재 CUDA 12.6과 GTX 1070의 `sm_61` 대상으로 검증했습니다. 원소 수는 학습용으로 1–32개를 한 블록에서 처리하도록 제한했습니다.

이전: [12 - Clang에서 참조가 사라지는 과정](/posts/c-출근길-12-clang에서-참조가-사라지는-과정/). 전체 순서: [00 - 시리즈 안내](/posts/c-출근길-시리즈/). 검증: [90 - 예제와 어셈블리 검증 기록](/posts/c-출근길-부록-예제와-어셈블리-검증/).
