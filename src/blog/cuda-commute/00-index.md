---
title: "CUDA 출근길 시리즈"
description: "CUDA가 그래픽 회사 NVIDIA의 컴퓨팅 플랫폼으로 등장한 배경부터 CUDA C++, PTX, GPU architecture, memory와 실행 모델까지 연결하는 12편입니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:00:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

CUDA는 GPU에서 함수를 실행하는 문법만을 가리키지 않습니다. NVIDIA가 그래픽 전용 제품의 병렬 처리 능력을 범용 컴퓨팅 시장에 제공하기 위해 만든 **하드웨어 아키텍처, 프로그래밍 모델, 언어 확장, compiler toolchain, driver와 library 생태계**입니다. 이 구성 요소들이 함께 작동하기 때문에 CUDA program은 C++ source에서 시작해 PTX와 GPU machine code를 거쳐 장치에서 실행됩니다.

이 정의에는 CUDA가 등장한 이유가 들어 있습니다. 2000년대 초의 GPU는 이미 CPU보다 많은 산술 장치와 높은 memory bandwidth를 제공했지만, 일반 계산을 실행하는 공식 인터페이스가 없었습니다. 연구자는 숫자 배열을 texture로 포장하고 계산을 pixel shader로 표현한 뒤, rendering 결과를 다시 읽어야 했습니다. 연산 성능은 매력적이었지만 programming model은 graphics pipeline의 규칙에 묶여 있었습니다.

NVIDIA는 이 간극을 새 시장으로 보았습니다. 회사가 미국 증권거래위원회에 제출한 [2007 회계연도 연차보고서](https://www.sec.gov/Archives/edgar/data/1045810/000104581007000008/fy2007annualreportonform10-k.htm)는 GeForce 8과 CUDA가 비용 때문에 어려웠던 계산 집약 문제를 PC의 GPU로 처리하는 새로운 “GPU Computing” 분야를 연다고 설명합니다. 2007년에는 화면 출력이 목적이 아닌 계산 제품군 **Tesla**도 출시했습니다. CUDA는 기존 GPU 판매를 돕는 부가 SDK가 아니라, NVIDIA가 과학·공학·금융·에너지와 고성능 컴퓨팅으로 사업 범위를 넓히는 플랫폼 전략이었습니다.

하드웨어도 같은 방향으로 바뀌었습니다. 2006년 G80 기반 GeForce 8800은 vertex와 pixel 작업에 고정된 별도 processor 대신 동일한 programmable processor pool을 여러 작업에 배정하는 unified shader architecture를 도입했습니다. 많은 thread 사이에서 실행 준비가 된 thread를 선택해 memory latency를 숨기고, CUDA thread가 협력할 shared memory와 barrier를 제공했습니다. CUDA는 이 하드웨어를 graphics API와 독립적인 `grid → block → thread` 모델로 노출했습니다.

개발자에게 가장 눈에 띈 변화는 C 계열 source code였습니다. 2007년 2월 공개 beta는 C compiler와 SDK를 제공했고, 6월의 CUDA 1.0은 `__global__` kernel, `threadIdx`, `__syncthreads()`와 `<<<grid, block>>>` launch 문법을 사용했습니다. 오늘날 이 언어 계층은 CUDA C++이라고 부릅니다. 일반 C++와 별개의 완전히 새로운 언어라기보다, NVIDIA compiler가 처리하는 execution-space 지정자, launch syntax, built-in variable과 device library를 C++에 추가한 형태입니다.

당시 반응이 일방적인 환영이었던 것은 아닙니다. 개발자는 OpenGL이나 Direct3D를 계산 API로 가장하지 않고 C로 GPU를 사용할 수 있다는 점을 높게 평가했습니다. 동시에 좋은 성능을 내려면 data parallelism, coalesced memory access, shared memory, branch divergence를 새로 이해해야 했습니다. G80에는 double precision이 없었고, CPU memory와 GPU memory를 명시적으로 옮겨야 했으며, CUDA code는 NVIDIA GPU에 종속되었습니다. 2008년의 한 [동시대 CUDA 평가](https://www.tomshardware.com/reviews/nvidia-cuda-gpu%2C1954-14.html)는 API가 명료해졌다는 장점과 새로운 병렬 architecture에 맞춰 사고해야 한다는 부담을 함께 지적했습니다.

이 시리즈는 이 역사에서 출발해 기술 계층을 하나씩 분리합니다. CUDA C++ source가 `nvcc`를 통해 host code와 device code로 나뉘고, device code가 PTX 또는 GPU binary가 되며, runtime과 driver가 memory·module·kernel launch를 관리하는 순서입니다. 그 위에서 thread hierarchy, SIMT, memory hierarchy와 synchronization을 설명하고, 마지막에는 같은 모델을 작은 neural-network linear kernel에 적용합니다.

**읽는 순서**

1. [01 - PTX에서 시작하는 GPU의 역사](/posts/cuda-출근길-01-ptx에서-시작하는-gpu의-역사/) — NVIDIA의 사업적 선택, G80, Tesla, 초기 개발자 반응과 PTX가 필요해진 과정.
2. [02 - kernel과 thread index](/posts/cuda-출근길-02-kernel과-thread-index/) — CUDA C++ 확장과 compiler·runtime·driver·PTX 계층, thread가 원소를 선택하는 과정.
3. [03 - launch 크기와 경계 검사](/posts/cuda-출근길-03-launch-크기와-경계-검사/) — hardware 규모와 무관한 launch, block 수의 올림과 범위 검사.
4. [04 - grid, block, warp](/posts/cuda-출근길-04-grid-block-warp/) — 소프트웨어가 지정하는 계층과 하드웨어가 실행하는 묶음.
5. [05 - SIMT와 분기](/posts/cuda-출근길-05-simt와-분기/) — G80이 도입한 SIMT와 warp divergence.
6. [06 - GPU 메모리 공간](/posts/cuda-출근길-06-gpu-메모리-공간/) — register·local·shared·global memory의 위치, 범위와 비용.
7. [07 - 전송, stream, 동기화](/posts/cuda-출근길-07-전송-stream-동기화/) — discrete GPU의 memory 경계와 비동기 command stream.
8. [08 - unsafe와 오류 경계](/posts/cuda-출근길-08-unsafe와-오류-경계/) — 서로 따로 compile되는 host와 device 사이의 ABI·pointer 계약.
9. [09 - coalescing](/posts/cuda-출근길-09-coalescing/) — warp의 address가 memory transaction으로 결합되는 조건.
10. [10 - shared memory와 barrier](/posts/cuda-출근길-10-shared-memory와-barrier/) — block 안에서 데이터를 재사용하고 쓰기 완료를 맞추는 방법.
11. [11 - linear kernel로 확장](/posts/cuda-출근길-11-linear-kernel로-확장/) — 출력 원소와 thread를 대응시키는 기준 구현.
12. [12 - 자원 재사용과 측정](/posts/cuda-출근길-12-자원-재사용과-측정/) — CUDA context·module·buffer의 수명과 kernel 시간·전체 지연의 구분.

1편과 2편은 CUDA가 처음 제공한 언어와 platform을 설명하므로 CUDA C++을 기준 표기로 사용합니다. 3편 이후의 실행 모델은 언어와 독립적으로 성립합니다. 현재 mini-infer는 host와 kernel을 모두 Rust로 작성하지만, Rust NVPTX backend도 같은 PTX와 CUDA driver 계층에 접속합니다. Rust 구현은 CUDA의 기원을 대신하는 설명이 아니라, 뒤에서 동일한 architecture를 확인하는 현재 사례입니다.

NVIDIA의 현재 [CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/)는 programming model과 platform 구성 요소를 정의합니다. [PTX ISA](https://docs.nvidia.com/cuda/parallel-thread-execution/)는 virtual instruction set을 정의하며, [Best Practices Guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/)는 memory access와 occupancy 같은 성능 판단을 설명합니다. 역사적 주장은 현재 guide의 회고만으로 정리하지 않고, NVIDIA의 연차보고서·초기 CUDA 자료와 당시의 외부 평가를 함께 사용합니다.

현재 mini-infer에서 확인된 GPU 실행은 GTX 1070에서 257개 출력이 모두 `3 * index + 7`과 일치한 probe입니다. 이는 Rust kernel과 CUDA driver 경로가 작동했다는 검증이며, GPU neural-network inference나 성능 향상이 완료되었다는 뜻은 아닙니다. 검증 범위는 [검증 기록](/posts/cuda-출근길-부록-검증-기록/)에 따로 기록합니다.
