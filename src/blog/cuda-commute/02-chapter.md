---
title: "CUDA 출근길 02 — kernel과 thread index"
description: "CUDA C++ 확장, nvcc의 host/device 분리, PTX와 driver의 역할을 거쳐 각 thread가 출력 원소를 선택하는 과정을 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:02:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "cpp", "gpu", "ptx", "cuda-commute"]
---

CUDA C++ program에는 CPU에서 실행되는 host code와 GPU에서 실행되는 device code가 함께 들어갈 수 있습니다. 두 code는 같은 source file에 있어도 같은 instruction set으로 compile되지 않습니다. `nvcc`는 CUDA syntax를 이해하는 compiler driver이며, host 부분은 platform C++ compiler와 연결하고 device 부분은 NVIDIA GPU compilation pipeline으로 보냅니다.

이 분리를 이해하면 CUDA를 “C++을 GPU가 직접 실행한다”라고 잘못 설명하지 않게 됩니다. GPU가 실행하는 것은 C++ source가 아니라 device compilation을 거쳐 만들어진 GPU machine code입니다. PTX는 source와 physical GPU instruction 사이에서 CUDA execution model을 보존하는 virtual ISA입니다.

## CUDA C++은 무엇을 C++에 추가합니까

CUDA C++은 ISO C++ 위에 GPU execution을 표현하는 language extension과 library API를 추가합니다. 다음 kernel에는 대표적인 확장이 들어 있습니다.

```cpp
__global__ void fill_pattern(unsigned int* output, unsigned int count)
{
    unsigned int index = blockIdx.x * blockDim.x + threadIdx.x;

    if (index < count) {
        output[index] = 3 * index + 7;
    }
}
```

`__global__`은 함수의 호출자와 실행 위치를 지정합니다. host가 함수를 launch하고 device thread들이 본문을 실행합니다. `threadIdx`, `blockIdx`와 `blockDim`은 library의 보통 global variable이 아니라 compiler와 GPU execution environment가 제공하는 built-in variable입니다.

host code는 kernel을 일반 함수 호출과 다른 syntax로 launch합니다.

```cpp
fill_pattern<<<3, 128>>>(device_output, 257);
```

`<<<3, 128>>>`은 return value를 받는 C++ operator가 아닙니다. CUDA compiler가 해석하는 execution configuration입니다. 이 호출은 block 3개, block당 thread 128개로 구성된 grid를 제출합니다. CPU는 kernel body를 한 번 실행하는 대신 driver/runtime에 GPU work를 제출합니다.

execution-space 지정자는 함수 관계를 더 세밀하게 표현합니다.

| 지정자 | 호출 위치 | 실행 위치 |
| --- | --- | --- |
| `__host__` | host | CPU |
| `__device__` | device code | GPU |
| `__global__` | host | GPU kernel |

`__host__ __device__`를 함께 붙이면 compiler는 CPU version과 GPU version을 각각 생성할 수 있습니다. 그러나 두 target이 지원하는 library와 behavior가 같아지는 것은 아닙니다. 한 source language를 사용해도 allocation, address space와 execution environment는 분리됩니다.

## nvcc는 하나의 compiler executable이지만 모든 code를 혼자 처리하지 않습니다

`nvcc`는 CUDA compilation의 단계를 조정하는 compiler driver입니다. 현재 toolchain의 세부 구현은 version과 option에 따라 달라질 수 있지만, developer가 관찰해야 하는 논리적 흐름은 다음과 같습니다.

```text
CUDA C++ translation unit
        │
        ├─ host code ──▶ generated host C++ ──▶ MSVC/GCC/Clang ──▶ CPU object
        │
        └─ device code ─▶ NVIDIA device compiler
                               │
                               ├─ PTX virtual ISA
                               └─ cubin: 특정 GPU용 binary

CPU object + embedded device image ──▶ executable / library
```

host compiler는 `<<<...>>>` syntax를 직접 이해할 필요가 없습니다. `nvcc`가 launch를 CUDA runtime 호출로 변환하고, host compiler가 처리할 형태를 준비합니다. device function은 NVIDIA compiler가 GPU용으로 compile합니다. 결과 executable에는 특정 architecture용 binary와 PTX가 하나 이상의 **fat binary** 형태로 포함될 수 있습니다.

NVIDIA의 현재 [CUDA Compiler Driver documentation](https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/)은 `nvcc`가 host compilation과 device compilation을 조정하고, host compiler를 사용하며, device code를 cubin이나 fatbin으로 생성하는 option을 정의합니다. 이 문서는 compiler driver의 현재 계약을 설명합니다. 2007년의 내부 pipeline이 현재와 완전히 같았다고 소급해서 읽어서는 안 되지만, host/device 분리와 PTX라는 기본 구조는 초기 CUDA부터 존재했습니다.

## PTX는 GPU assembly처럼 보이지만 physical machine ISA는 아닙니다

PTX는 **Parallel Thread Execution**의 약자이며 NVIDIA가 정의한 virtual instruction set architecture입니다. register, load/store, arithmetic, branch와 thread index를 읽는 special register를 표현하지만, 특정 GPU chip의 binary encoding을 고정하지 않습니다.

간단한 kernel의 PTX에는 다음과 비슷한 동작이 나타납니다. 실제 register 이름과 instruction 선택은 compiler version과 optimization에 따라 달라집니다.

```text
mov.u32  %r1, %ctaid.x;   // blockIdx.x
mov.u32  %r2, %ntid.x;    // blockDim.x
mov.u32  %r3, %tid.x;     // threadIdx.x
mad.lo.u32 %r4, %r1, %r2, %r3;
```

`%ctaid.x`, `%ntid.x`, `%tid.x`는 CUDA C++의 built-in index가 PTX에서 읽는 special register입니다. `mad.lo.u32`는 곱셈과 덧셈으로 global index를 만듭니다. 이 correspondence는 C++ syntax가 어떻게 GPU execution model로 내려가는지 보여 줍니다.

PTX가 virtual ISA인 이유는 GPU architecture가 세대마다 변하기 때문입니다. application이 PTX를 포함하면 CUDA driver는 현재 장치에 맞는 machine code를 JIT compile할 수 있습니다. 반대로 build 시점에 `ptxas`가 특정 compute capability의 cubin을 만들면 load 시 JIT 비용을 줄이고 build 당시 code generation을 사용할 수 있습니다. 실제 배포물은 compatibility와 startup cost를 위해 여러 cubin과 PTX를 함께 포함할 수 있습니다.

NVIDIA의 [PTX ISA specification](https://docs.nvidia.com/cuda/parallel-thread-execution/)은 PTX를 abstract GPU machine을 위한 ISA로 정의합니다. NVIDIA의 [PTX 해설](https://developer.nvidia.com/blog/understanding-ptx-the-assembly-language-of-cuda-gpu-computing/)은 PTX가 final machine code가 아니며, `ptxas` 또는 driver JIT가 실제 GPU binary로 변환한다고 설명합니다.

## runtime API와 driver API는 compiler 아래의 실행 계층입니다

compile이 끝나도 GPU는 자동으로 실행되지 않습니다. process는 GPU context를 만들고, device memory를 할당하고, module과 kernel을 찾고, argument와 execution configuration을 제출해야 합니다.

CUDA는 두 API 수준을 제공합니다.

| 계층 | 대표 이름 | 역할 |
| --- | --- | --- |
| CUDA Runtime API | `cudaMalloc`, `cudaMemcpy`, kernel launch syntax | context와 module의 일반 작업을 편리하게 관리 |
| CUDA Driver API | `cuCtxCreate`, `cuModuleLoad`, `cuLaunchKernel` | context·module·function과 launch를 더 명시적으로 관리 |

Runtime API가 driver를 대체하는 별도 GPU path는 아닙니다. runtime implementation은 CUDA driver 기능 위에서 더 높은 수준의 lifecycle과 launch 편의를 제공합니다. application이나 language binding은 driver API를 직접 사용할 수도 있습니다.

```text
CUDA C++ application
       ↓ Runtime API
CUDA user-mode driver API
       ↓ OS driver / GPU command submission
NVIDIA GPU
```

Windows의 display GPU에서는 아래쪽 command scheduling과 video-memory management가 WDDM의 영향도 받습니다. 그러나 CUDA kernel은 Direct3D shader pipeline을 통과하지 않습니다. Direct3D와 CUDA는 위쪽 compiler와 API가 다르며, 아래에서 동일한 physical GPU와 OS/vendor driver infrastructure를 공유할 수 있습니다.

## 같은 kernel body에서 thread마다 다른 원소를 선택합니다

compiler와 driver가 kernel을 준비한 뒤에는 launch된 모든 thread가 `fill_pattern`의 같은 instruction sequence에서 시작합니다. 각 thread가 서로 다른 원소를 처리하게 만드는 값은 execution configuration과 built-in index입니다.

```cpp
unsigned int index = blockIdx.x * blockDim.x + threadIdx.x;
```

1차원 grid에서 각 값은 다음 의미를 가집니다.

| 값 | 의미 | `<<<3, 128>>>`에서의 범위 |
| --- | --- | --- |
| `threadIdx.x` | 현재 block 안의 thread 번호 | 0–127 |
| `blockIdx.x` | grid 안의 block 번호 | 0–2 |
| `blockDim.x` | block마다 배치된 thread 수 | 128 |

global index 계산은 block별 local index를 전체 grid의 연속 index로 바꿉니다.

```text
block 0: 0 × 128 + threadIdx.x → 0 ... 127
block 1: 1 × 128 + threadIdx.x → 128 ... 255
block 2: 2 × 128 + threadIdx.x → 256 ... 383
```

thread 384개가 실행되지만 output은 257개뿐입니다. 따라서 kernel은 유효 범위를 검사합니다.

```cpp
if (index < count) {
    output[index] = 3 * index + 7;
}
```

index 0–256인 thread만 memory를 씁니다. 나머지 thread는 조건을 통과하지 않습니다. CUDA가 자동으로 array length를 알아내는 것이 아니라 host가 `count`를 argument로 전달하고 device code가 그 계약을 지킵니다.

“thread 하나가 원소 하나를 처리한다”는 CUDA의 고정 규칙도 아닙니다. 이 kernel이 선택한 work mapping입니다. thread 하나가 loop로 여러 원소를 처리하거나, 여러 thread가 하나의 결과를 reduction할 수도 있습니다. 첫 예제에서는 1:1 mapping이 index, memory write와 검증 결과를 가장 직접적으로 연결합니다.

## Rust kernel은 CUDA의 기원이 아니라 같은 device 계층의 다른 frontend입니다

mini-infer는 학습 project의 단일 언어 결정을 위해 Rust host와 Rust kernel을 사용합니다. Rust compiler의 LLVM NVPTX backend는 CUDA C++ device compiler 대신 PTX를 생성하고, `cudarc`는 CUDA Driver API를 호출합니다.

```text
CUDA C++: source ─▶ nvcc/device compiler ─▶ PTX/cubin ─▶ CUDA driver
Rust:      source ─▶ rustc/LLVM NVPTX     ─▶ PTX       ─▶ CUDA driver
```

두 경로는 frontend language와 compiler가 다릅니다. PTX 아래의 module load, device memory, launch configuration과 GPU execution model은 공유합니다. 따라서 CUDA의 역사와 표준 programming model을 설명할 때에는 CUDA C++이 기준이고, mini-infer의 Rust code는 그 architecture에 접속하는 별도 frontend 사례입니다.

다음 편에서는 output 257개에 block size 128을 선택했을 때 grid size가 왜 3이 되는지 설명합니다. 이 계산은 특정 GPU의 SM 개수와 무관하게 같은 kernel을 launch하도록 만드는 CUDA scalability model의 첫 부분입니다.

이전: [01 - PTX에서 시작하는 GPU의 역사](/posts/cuda-출근길-01-ptx에서-시작하는-gpu의-역사/). 다음: [03 - launch 크기와 경계 검사](/posts/cuda-출근길-03-launch-크기와-경계-검사/).
