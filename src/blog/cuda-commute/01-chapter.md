---
title: "CUDA 출근길 01 — PTX에서 시작하는 GPU의 역사"
description: "그래픽 시장의 GPU가 NVIDIA의 컴퓨팅 플랫폼이 된 사업적 배경, G80 architecture, CUDA C의 공개와 초기 개발자 반응을 연결합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:01:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "cpp", "gpu", "ptx", "cuda-commute"]
---

CUDA는 NVIDIA GPU를 범용 병렬 processor로 사용하는 proprietary computing platform입니다. 개발자는 CUDA C++로 host code와 GPU kernel을 작성하고, CUDA toolchain과 driver는 code compilation, device memory, kernel launch와 synchronization을 처리합니다. 이 platform은 GPU에 원래 없던 계산 능력을 추가한 것이 아니라, graphics pipeline 안에 갇혀 있던 programmable hardware를 일반 개발자가 직접 사용할 수 있도록 만든 것입니다.

CUDA의 등장은 언어 기능 하나의 발명으로 설명되지 않습니다. NVIDIA는 GPU architecture를 바꾸고, 그 architecture를 일반 계산에 노출하는 programming model을 설계하고, C compiler와 library를 제공하고, 계산 전용 Tesla 제품을 판매했습니다. 하드웨어와 소프트웨어를 함께 만든 선택이 CUDA를 SDK가 아니라 장기적인 사업 platform으로 만들었습니다.

## CUDA 이전에는 계산을 그래픽처럼 표현했습니다

1990년대의 PC graphics accelerator는 triangle setup, texture mapping과 rasterization처럼 정해진 rendering 단계를 빠르게 처리했습니다. 개발자는 그래픽 명령을 제출했지만 GPU에서 임의의 함수를 실행하지는 못했습니다. 2000년대 초에 vertex shader와 pixel shader가 programmable해지면서 상황이 바뀌었습니다. 동일한 작은 프로그램을 많은 vertex나 pixel에 적용하는 GPU는 data-parallel 계산 장치로도 사용할 수 있었습니다.

문제는 programming interface였습니다. OpenGL과 Direct3D는 graphics resource와 rendering pipeline을 표현하는 API입니다. 일반 계산용 array, pointer와 thread를 직접 노출하지 않았습니다. 개발자는 입력 배열을 texture에 저장하고, 계산을 fragment shader로 작성하고, 결과를 render target의 pixel로 받은 뒤 다시 읽었습니다. reduction이나 scatter처럼 graphics pipeline에 자연스럽지 않은 연산은 여러 pass와 우회 설계가 필요했습니다.

이 접근을 **GPGPU**, 즉 general-purpose computing on GPU라고 불렀습니다. GPGPU는 GPU의 잠재력을 증명했지만, 높은 진입 비용도 함께 드러냈습니다. NVIDIA가 2004년에 출판한 *GPU Gems*의 [서문](https://developer.nvidia.com/gpugems/gpugems/foreword)은 graphics accelerator가 programmable GPU로 변하던 시기와 개발자들이 반복해서 같은 기법을 발명하던 상황을 기록합니다.

Stanford의 Brook 연구도 중요한 중간 단계였습니다. Ian Buck 등이 개발한 Brook은 stream과 kernel 개념을 C 계열 언어로 표현하고 이를 GPU graphics API에 mapping했습니다. Brook은 개발자가 shader와 texture를 직접 조작하는 부담을 줄였지만, 아래에는 여전히 graphics pipeline이 있었습니다. NVIDIA는 2004년 Ian Buck을 영입했고, 이 연구 경험은 graphics API를 통하지 않는 CUDA programming model로 이어졌습니다. NVIDIA가 정리한 [accelerated computing의 역사](https://blogs.nvidia.com/blog/what-is-accelerated-computing/)는 Brook과 Buck의 합류를 CUDA 이전의 직접적인 배경으로 설명합니다. 이는 NVIDIA의 자사 회고 자료이므로, 사업 판단은 당시 공시 자료와 함께 읽어야 합니다.

## NVIDIA는 GPU 판매 시장 자체를 넓히려 했습니다

2006년 NVIDIA의 주력 사업은 GeForce, Quadro와 chipset이었습니다. GPU 성능은 빠르게 증가했지만, graphics 수요만으로 사용할 수 있는 workload는 제한되어 있었습니다. 이미 출하된 GPU의 arithmetic throughput을 scientific computing, medical imaging, financial modeling과 oil-and-gas exploration에 사용할 수 있다면 NVIDIA는 CPU가 담당하던 고성능 계산 예산으로 진입할 수 있었습니다.

이 전략은 나중의 해석이 아니라 당시 회사가 투자자에게 제시한 내용입니다. NVIDIA의 [2007 회계연도 Form 10-K](https://www.sec.gov/Archives/edgar/data/1045810/000104581007000008/fy2007annualreportonform10-k.htm)는 2006년 11월부터 CUDA-enabled GeForce 8을 업계에 제공했으며, GPU Computing이 이전에는 비용 때문에 어려웠던 계산 집약 문제를 처리하는 새로운 HPC 분야를 연다고 설명합니다. 같은 시기의 실적 발표는 fiscal 2008의 성장 동력으로 “GPU Computing era”를 명시했습니다.

사업 모델에는 두 층이 있었습니다.

| 층 | NVIDIA가 제공한 것 | 사업적 효과 |
| --- | --- | --- |
| 대중 GPU | CUDA가 동작하는 GeForce 설치 기반 | 개발자가 이미 보유한 장비에서 code를 시험하고 보급할 수 있음 |
| 전문 계산 제품 | display output보다 계산에 초점을 맞춘 Tesla | 연구소·기업·HPC의 별도 예산과 system 시장에 진입 |
| software platform | compiler, driver, libraries, tools | application이 GPU 세대가 바뀌어도 NVIDIA platform에 남을 이유를 만듦 |

2007년 6월 NVIDIA는 Tesla 브랜드를 발표했습니다. 당시 [NVIDIA의 GPU Computing 소개](https://www.nvidia.com/content/events/siggraph_2007/supercomputing.html)는 같은 compute engine을 GeForce의 game physics, Quadro의 professional visualization과 Tesla의 순수 계산에 걸쳐 사용한다는 제품 전략을 제시했습니다. CUDA compiler가 application source와 NVIDIA hardware 사이의 안정된 programming layer를 제공했기 때문에, Tesla는 단순히 video connector를 제거한 board보다 큰 의미를 가졌습니다. 하드웨어 판매와 developer ecosystem이 서로를 강화하는 구조가 시작된 것입니다.

다만 “CUDA가 처음부터 오늘날의 지배력을 보장했다”고 거꾸로 해석하면 안 됩니다. 2007년에는 CUDA가 공개 beta와 1.0을 막 지난 vendor-specific platform이었습니다. HPC 개발자는 double precision, numerical correctness, cluster deployment, long-running workload와 tool maturity를 평가해야 했습니다. NVIDIA가 의도한 시장과 실제로 장기 성공한 시장은 구분해야 합니다.

## G80은 graphics와 compute가 공유할 실행 기반을 만들었습니다

CUDA software만으로 이전 GPU의 제약을 제거할 수는 없었습니다. 2006년 11월 출시된 G80 기반 GeForce 8800은 DirectX 10을 지원하기 위해 **unified shader architecture**를 채택했습니다. 이전 세대에서는 vertex와 pixel processor 수가 고정되어 한 단계가 바쁜 동안 다른 단계의 arithmetic unit이 놀 수 있었습니다. G80은 동일한 scalar processor pool이 vertex, geometry, pixel과 compute thread를 실행하도록 만들었습니다.

NVIDIA의 [GTX 200 architecture technical brief](https://www.nvidia.com/docs/io/55506/geforce_gtx_200_gpu_technical_brief.pdf)는 GeForce 8800의 unified shader core가 작업 종류에 따라 동적으로 배정되며, 이 architecture가 CUDA compute의 기반이 되었다고 설명합니다. 이후 Fermi whitepaper의 G80 회고는 CUDA 관점에서 다음 변화를 강조합니다.

- separate vertex/pixel pipeline을 하나의 programmable processor array로 통합했습니다.
- scalar thread processor를 사용해 개발자가 vector register를 직접 packing하는 부담을 줄였습니다.
- 여러 thread가 같은 instruction을 실행하는 SIMT execution model을 도입했습니다.
- 같은 thread block이 값을 공유할 shared memory와 barrier synchronization을 제공했습니다.
- hardware thread scheduler가 memory를 기다리는 warp 대신 실행 가능한 warp를 선택했습니다.

이 목록에서 “CUDA가 G80을 만들었다”거나 “G80이 graphics 기능을 없앴다”고 결론 내리면 안 됩니다. G80은 DirectX 10 graphics workload를 위해 unified shader가 필요했고, NVIDIA는 같은 programmable and threaded foundation을 CUDA compute에도 노출했습니다. graphics와 compute는 서로 다른 API를 사용하지만 동일한 GPU execution resources를 활용합니다.

architecture의 trade-off도 분명했습니다. GPU는 많은 thread에 같은 종류의 계산을 적용하고 memory latency를 다른 thread의 실행으로 숨길 때 높은 throughput을 냅니다. 복잡한 control flow를 가진 소수 thread의 latency를 최소화하는 CPU와 목표가 다릅니다. CUDA는 GPU를 CPU처럼 보이게 감추지 않고, thread hierarchy와 memory hierarchy를 개발자에게 드러냈습니다. 이 노출은 성능을 제어할 수 있는 장점인 동시에 학습 부담이었습니다.

## 2007년의 CUDA는 “C처럼 보이는 병렬 machine interface”였습니다

NVIDIA는 2007년 2월 CUDA SDK와 C compiler의 public beta를 공개했고, 6월에 CUDA Toolkit 1.0을 배포했습니다. [NVIDIA Toolkit archive](https://developer.nvidia.com/cuda-toolkit-archive/)에서 1.0의 시점을 확인할 수 있습니다. 당시 발표가 “C compiler”를 전면에 내세운 이유는 graphics shader 언어보다 훨씬 넓은 developer base에 접근하기 위해서였습니다.

초기 CUDA source는 다음 구조를 사용했습니다. 현재 표기에서는 CUDA C++이지만, 핵심 확장은 초기 모델과 같습니다.

```cpp
__global__ void fill_pattern(unsigned int* output, unsigned int count)
{
    unsigned int index = blockIdx.x * blockDim.x + threadIdx.x;

    if (index < count) {
        output[index] = 3 * index + 7;
    }
}

int main()
{
    unsigned int* device_output = nullptr;
    cudaMalloc(&device_output, 257 * sizeof(unsigned int));

    fill_pattern<<<3, 128>>>(device_output, 257);
    cudaDeviceSynchronize();

    cudaFree(device_output);
}
```

`__global__`은 CPU가 호출하고 GPU가 실행하는 kernel entry point를 지정합니다. `blockIdx`, `blockDim`과 `threadIdx`는 각 GPU thread가 자신의 logical index를 계산하도록 제공합니다. `<<<3, 128>>>`은 block 3개와 block당 thread 128개를 launch합니다. `cudaMalloc`과 `cudaFree`는 별도의 device memory를 관리합니다.

이 source가 일반 C++ compiler에서 그대로 compile되지 않는다는 점이 중요합니다. CUDA는 C++의 library만 추가한 것이 아닙니다. NVIDIA compiler driver인 `nvcc`가 execution-space annotation과 kernel launch syntax를 해석하고, host code와 device code를 분리해 서로 다른 compiler path로 보냅니다. 다음 편에서는 이 compilation pipeline을 PTX와 driver까지 따라갑니다.

## 개발자는 접근성에 환영했고, 성능 모델에는 경계했습니다

초기 반응을 “C를 쓸 수 있어서 모두 쉽게 GPU를 사용했다”로 요약하면 실제 경험을 놓칩니다. CUDA는 source 표현을 크게 개선했지만, sequential C program을 자동으로 parallel program으로 바꾸지는 않았습니다.

긍정적인 변화는 구체적이었습니다.

- OpenGL이나 Direct3D context를 만들지 않고 계산을 제출할 수 있었습니다.
- texture와 pixel이 아니라 pointer, index와 array라는 계산 용어를 사용할 수 있었습니다.
- thread block, shared memory와 synchronization을 직접 표현할 수 있었습니다.
- GeForce 8의 대규모 설치 기반에서 같은 model을 시험할 수 있었습니다.

반면 새로 떠안은 책임도 구체적이었습니다.

- algorithm을 많은 독립 thread로 분해해야 했습니다.
- host와 device의 별도 memory 사이에서 data를 이동해야 했습니다.
- warp divergence와 memory coalescing처럼 CPU C에는 없던 성능 조건을 이해해야 했습니다.
- G80에는 hardware double precision이 없었고, 장시간 kernel과 debugging tool에도 초기 제약이 있었습니다.
- CUDA source와 binary ecosystem은 NVIDIA hardware에 종속되었습니다.

2008년 *ACM Queue*에 실린 John Nickolls, Ian Buck, Michael Garland와 Kevin Skadron의 [Scalable Parallel Programming with CUDA](https://doi.org/10.1145/1365490.1365500)는 CUDA를 core 수가 달라져도 확장되는 parallel programming model로 제시했습니다. 저자 셋이 NVIDIA 소속이므로 이 논문은 platform 설계자의 설명으로 읽어야 합니다. 같은 시기의 독립적인 [Tom's Hardware 평가](https://www.tomshardware.com/reviews/nvidia-cuda-gpu%2C1954-14.html)는 C 개발자가 실제로 사용할 수 있는 수준에 도달했다고 보면서도, 설득력 있는 성능을 얻으려면 architecture에 맞는 사고와 노력이 필요하다고 평가했습니다.

초기 scientific application은 가능성을 빠르게 시험했습니다. 2007년 7월 공개된 gravitational N-body simulation 연구처럼 CUDA 공개 직후부터 기존 GPGPU algorithm을 CUDA로 옮긴 사례가 등장했습니다. 이런 사례는 개발자들이 CUDA를 단순 graphics effect가 아니라 HPC programming interface로 받아들이기 시작했다는 증거입니다. 다만 논문의 speedup은 특정 algorithm과 비교 조건의 결과이며, 모든 program이 GPU에서 빨라진다는 뜻은 아닙니다.

## CUDA의 장기 경쟁력은 compiler 아래의 층까지 이어졌습니다

CUDA C++ syntax만 복제하면 CUDA platform 전체를 대체할 수 없습니다. application이 실제 제품이 되려면 compiler, virtual ISA, driver compatibility, optimized library, debugger, profiler와 framework integration이 함께 필요합니다. NVIDIA는 이 층을 GPU 세대와 함께 지속적으로 발전시켰습니다.

```text
application / framework
        ↓
CUDA libraries and CUDA C++ source
        ↓
compiler toolchain and PTX
        ↓
CUDA runtime / driver
        ↓
NVIDIA GPU architecture
```

아래로 갈수록 hardware와 가까워지고, 위로 갈수록 application developer가 사용하는 재사용 자산이 많아집니다. CUDA가 NVIDIA의 사업적 방어력이 된 이유는 단일 compiler syntax 때문이 아니라, application과 library가 이 여러 층의 behavior, performance와 tooling에 의존하기 때문입니다.

다음 편에서는 위 그림을 실제 compilation 순서로 펼칩니다. CUDA C++ source에서 `nvcc`가 무엇을 분리하고, PTX가 무엇을 보존하며, driver가 어느 시점에 GPU machine code를 준비하는지 설명한 뒤 `threadIdx`가 실제 출력 원소를 선택하는 과정으로 연결합니다.

이전: [시리즈 안내](/posts/cuda-출근길-시리즈/). 다음: [02 - kernel과 thread index](/posts/cuda-출근길-02-kernel과-thread-index/).
