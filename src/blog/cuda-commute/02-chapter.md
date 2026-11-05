---
title: "CUDA 출근길 02 — kernel과 thread index"
description: "호스트의 진입점에서 커널 실행과 결과 복사까지 살펴보고 컴파일 과정과 PTX의 역할을 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:02:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA의 배경, 실행 모델 및 애플리케이션 구성"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

CUDA 커널은 GPU의 여러 스레드가 실행하는 함수입니다. 호스트 코드는 커널에 사용할 인수와 실행할 스레드의 배치를 지정합니다. 각 스레드는 동일한 함수 본문을 실행하지만 자신의 인덱스를 사용하여 서로 다른 데이터를 처리할 수 있습니다.

이 문서에서는 배열에 일정한 규칙의 값을 기록하는 프로그램을 사용합니다. CPU의 `main`에서 시작하여 GPU 작업을 제출하고, 결과를 다시 읽는 순서로 실행을 설명합니다. 이어서 이 코드가 PTX와 GPU 명령어로 변환되는 과정을 살펴봅니다.

## 호스트에서 프로그램 시작

다음 코드는 전체 예제의 실행 순서를 간략하게 나타냅니다. `Check`는 CUDA API가 실패하면 오류를 보고하는 보조 함수입니다. 실제 프로그램의 정의와 정리 코드는 [전체 소스](/downloads/cuda-commute/examples.cu)를 참조하세요.

```cpp
constexpr unsigned int count = 257;
unsigned int* deviceOutput = nullptr;
std::vector<unsigned int> hostOutput(count);

Check(cudaMalloc(&deviceOutput, count * sizeof(unsigned int)));

FillPattern<<<3, 128>>>(deviceOutput, count);
Check(cudaGetLastError());
Check(cudaDeviceSynchronize());

Check(cudaMemcpy(
    hostOutput.data(),
    deviceOutput,
    count * sizeof(unsigned int),
    cudaMemcpyDeviceToHost));

Check(cudaFree(deviceOutput));
```

`hostOutput`은 CPU에서 접근하는 결과 배열입니다. `cudaMalloc`은 GPU 계산에 사용할 메모리를 할당하고 그 주소를 `deviceOutput`에 기록합니다. 여기서 포인터 변수와 포인터가 가리키는 메모리는 다릅니다. CPU 코드가 포인터 값을 보관한다고 해서 일반 CPU 역참조로 해당 장치 메모리를 읽을 수 있는 것은 아닙니다.

`FillPattern<<<3, 128>>>`은 블록 세 개, 블록당 스레드 128개로 커널을 제출합니다. `cudaGetLastError`로 제출 관련 오류를 확인하고, `cudaDeviceSynchronize`로 장치 작업의 완료를 기다립니다. 마지막으로 `cudaMemcpy`가 결과를 호스트 배열로 복사합니다. 복사가 성공한 뒤 CPU가 `hostOutput`의 원소를 검사할 수 있습니다.

커널 호출은 C++의 일반 함수 호출과 다릅니다. CPU가 함수 본문을 실행하여 결과를 반환하는 대신 GPU 작업을 제출합니다. 완료 대기를 별도로 표현하는 이유도 여기에 있습니다.

## 스레드별 작업 선택

앞에서 호출한 커널은 다음과 같습니다.

```cpp
__global__ void FillPattern(
    unsigned int* output,
    unsigned int count)
{
    unsigned int index =
        blockIdx.x * blockDim.x + threadIdx.x;

    if (index < count)
    {
        output[index] = 3 * index + 7;
    }
}
```

`__global__`은 이 함수가 GPU 커널 진입점임을 나타냅니다. 함수의 매개 변수는 출력 메모리의 주소와 유효 원소 수입니다. 이 예제에서 커널은 값을 반환하지 않고 전달받은 메모리에 결과를 기록합니다.

`threadIdx.x`는 블록 안의 스레드 번호이고, `blockIdx.x`는 그리드 안의 블록 번호입니다. `blockDim.x`는 블록당 스레드 수입니다. 세 값을 조합하면 배열 전체에서 사용할 인덱스를 계산할 수 있습니다.

| 실행 위치 | 인덱스 계산 | 기록할 값 |
| --- | --- | --- |
| 블록 0, 스레드 0 | `0 * 128 + 0 = 0` | `7` |
| 블록 0, 스레드 1 | `0 * 128 + 1 = 1` | `10` |
| 블록 1, 스레드 0 | `1 * 128 + 0 = 128` | `391` |
| 블록 2, 스레드 0 | `2 * 128 + 0 = 256` | `775` |

이 배치는 스레드 384개를 요청하지만 배열에는 원소 257개만 있습니다. `index < count` 조건은 배열 밖의 스레드가 메모리에 기록하지 않도록 합니다. 실행 수와 배열 크기의 관계는 다음 문서에서 자세히 설명합니다.

이 계산에서는 각 스레드가 다른 원소에 기록합니다. 따라서 블록 1이 블록 0보다 먼저 실행되어도 결과는 같습니다. CUDA가 원소 순서대로 스레드를 실행한다고 가정할 필요가 없습니다.

## CUDA C++과 일반 C++의 경계

CUDA C++은 C++에 실행 위치를 나타내는 지정자, 커널 실행 구문 및 관련 기능을 추가합니다. `__global__`과 `<<<...>>>`는 일반 ISO C++ 컴파일러가 그대로 처리하는 구문이 아닙니다. CUDA 도구가 이 구문을 처리해야 합니다.

반면 `std::vector`, 조건문과 정수 계산을 모두 새로운 언어로 다시 정의하는 것은 아닙니다. 호스트 코드는 C++ 환경을 사용하며, 장치 코드는 GPU 대상에서 지원하는 C++ 기능과 라이브러리를 사용합니다. 언어가 같아도 두 실행 환경에서 모든 기능을 동일하게 사용할 수 있는 것은 아닙니다.

초기의 CUDA가 C 기반으로 소개되었다는 역사와 현재 CUDA C++의 기능 범위도 구분해야 합니다. 이 문서의 코드는 현재 표기를 사용하며 2007년 도구에서 그대로 빌드할 수 있는 예제로 제시하는 것은 아닙니다.

## 컴파일 과정과 PTX

NVIDIA의 컴파일러 드라이버 `nvcc`는 호스트 코드와 장치 코드의 컴파일을 조정합니다. 호스트 코드는 호스트 C++ 컴파일러로 처리하고, 장치 코드는 GPU용 컴파일 경로로 처리합니다.

```text
CUDA C++ 소스
    ├─ 호스트 코드 → 호스트 C++ 컴파일러 → CPU 코드
    └─ 장치 코드   → 장치 컴파일러 → PTX → GPU 기계어

CPU 코드 + 장치 코드 이미지 → 실행 파일
```

PTX는 가상 명령어 집합입니다. 실제 GPU가 PTX 텍스트를 그대로 실행하는 것은 아닙니다. 빌드할 때 `ptxas`가 대상 GPU용 코드를 생성하거나, 드라이버가 포함된 PTX에서 실행 시점에 코드를 생성할 수 있습니다. 특정 GPU용 바이너리는 cubin으로, 여러 장치 코드 이미지를 포함하는 묶음은 fat binary로 다룹니다.

이 방식에서는 컴파일 결과와 실행 환경을 따로 확인할 수 있습니다. PTX 생성에 성공해도 설치된 드라이버가 그 PTX 버전을 지원하지 않으면 적재에 실패할 수 있습니다. 반대로 적합한 GPU 바이너리가 포함되어 있으면 실행할 때마다 PTX를 새로 컴파일할 필요는 없습니다.

NVIDIA의 [컴파일러 드라이버 설명](https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/)은 이러한 호스트·장치 코드 분리와 장치 이미지 생성 과정을 정의합니다. [PTX 설명](https://developer.nvidia.com/blog/understanding-ptx-the-assembly-language-of-cuda-gpu-computing/)은 가상 명령어와 실제 GPU 명령어의 관계를 별도로 설명합니다.

## 실행 라이브러리와 드라이버

앞의 `cudaMalloc`과 `cudaMemcpy`는 CUDA Runtime API입니다. 애플리케이션은 이 API를 통해 장치 메모리와 실행을 관리합니다. 더 명시적인 컨텍스트·모듈 관리를 수행하려면 CUDA Driver API의 `cuModuleLoad`, `cuLaunchKernel` 등을 사용할 수 있습니다.

여기서 드라이버 API는 `nvcc`와 다릅니다. `nvcc`는 빌드 도구이고, 드라이버 API는 실행 중 장치 작업을 다루는 인터페이스입니다. 컴파일러 드라이버라는 이름과 GPU 장치 드라이버라는 이름에서 사용하는 “드라이버”를 구분해야 합니다.

이 관계는 다른 언어로 CUDA를 사용할 때도 유지됩니다. 예를 들어 별도의 컴파일러가 PTX를 생성하고 호스트 언어의 바인딩이 Driver API로 커널을 실행할 수 있습니다. CUDA C++은 대표적인 개발 경로이지만 PTX 아래의 실행 모델이 C++ 구문만을 위한 것은 아닙니다.

이제 계산식, 실행 배치 및 컴파일 경로를 구분할 수 있습니다. 다음 문서에서는 배열 크기가 달라졌을 때 실행 배치를 계산하고 범위 검사를 유지하는 방법을 설명합니다.

## 다음 단계

[시리즈 안내](/posts/cuda-출근길-시리즈/) · [이전 문서](/posts/cuda-출근길-01-ptx에서-시작하는-gpu의-역사/) · [다음 문서](/posts/cuda-출근길-03-launch-크기와-경계-검사/)
