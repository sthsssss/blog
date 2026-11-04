---
title: "CUDA 출근길 시리즈"
description: "그래픽 전용 장치가 범용 병렬 계산 장치로 바뀐 역사에서 시작해 PTX·thread·warp·메모리·Rust linear kernel까지 이어 읽는 12편입니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:00:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---

GPU는 처음부터 신경망이나 범용 계산을 위해 만들어진 장치가 아닙니다. 초기 PC의 그래픽 가속기는 정해진 렌더링 단계를 빠르게 처리했고, programmable shader가 등장한 뒤에도 일반 계산을 하려면 데이터를 texture와 pixel처럼 꾸며 그래픽스 파이프라인에 넣어야 했습니다. 오늘날 `kernel`을 작성하고 숫자 배열을 넘기는 CUDA의 모습은 이 역사적 제약을 걷어 낸 결과입니다.

2006년의 G80은 vertex와 pixel 작업에 따로 배정되던 처리기를 unified shader 구조로 합쳤습니다. 같은 해 NVIDIA는 GPU의 병렬 처리 능력을 과학·연구 계산에 개방하는 CUDA를 공개했습니다. 중요한 변화는 단순히 “그래픽카드가 빨라졌다”가 아닙니다. 그래픽스 API를 우회하지 않고, 일반 목적의 thread와 memory라는 언어로 GPU에 계산을 기술할 수 있게 된 것입니다. NVIDIA의 [기업 연혁](https://www.nvidia.com/en-us/about-nvidia/corporate-timeline/)과 [GTX 200 기술 문서](https://www.nvidia.com/docs/io/55506/geforce_gtx_200_gpu_technical_brief.pdf)는 이 전환을 각각 CUDA 공개와 unified architecture의 맥락에서 기록합니다.

이 시리즈는 그 변화의 중간 언어인 **PTX**에서 시작합니다. Rust kernel은 GPU가 곧바로 실행하는 최종 명령이 아닙니다. Rust compiler와 LLVM의 NVPTX backend가 PTX를 만들고, NVIDIA driver가 실제 GPU 세대에 맞는 machine code로 바꿉니다. 이 경로를 먼저 알아야 `ptx-kernel`, compute capability, module load와 driver JIT가 서로 어떤 관계인지 이해할 수 있습니다.

하나의 예제는 끝까지 유지합니다. Rust로 작성한 `probe_pattern` kernel에서 각 GPU thread가 자신의 인덱스 `i`를 구해 `3 * i + 7`을 씁니다. 그 kernel이 PTX가 되는 지점부터 host가 module을 적재하는 과정, thread가 실제 원소를 고르는 과정, warp와 memory transaction을 거쳐 신경망의 linear 연산으로 확장되는 과정까지 한 줄로 연결합니다.

**읽는 순서**

1. [01 - PTX에서 시작하는 GPU의 역사](/posts/cuda-출근길-01-ptx에서-시작하는-gpu의-역사/) — 그래픽 장치가 범용 계산 장치가 된 과정과 Rust kernel의 실제 실행 경로.
2. [02 - kernel과 thread index](/posts/cuda-출근길-02-kernel과-thread-index/) — 한 thread가 자기 원소를 선택하는 과정.
3. [03 - launch 크기와 경계 검사](/posts/cuda-출근길-03-launch-크기와-경계-검사/) — block 수를 올림하고 남는 thread를 막는 이유.
4. [04 - grid, block, warp](/posts/cuda-출근길-04-grid-block-warp/) — 프로그래밍 계층과 실제 실행 묶음.
5. [05 - SIMT와 분기](/posts/cuda-출근길-05-simt와-분기/) — 같은 명령 흐름과 thread별 데이터.
6. [06 - GPU 메모리 공간](/posts/cuda-출근길-06-gpu-메모리-공간/) — register·local·shared·global의 소유 범위.
7. [07 - 전송, stream, 동기화](/posts/cuda-출근길-07-전송-stream-동기화/) — 제출 순서와 완료 확인.
8. [08 - unsafe와 오류 경계](/posts/cuda-출근길-08-unsafe와-오류-경계/) — Rust가 보장하는 부분과 launch 계약.
9. [09 - coalescing](/posts/cuda-출근길-09-coalescing/) — 인접 thread와 인접 주소가 만나는 이유.
10. [10 - shared memory와 barrier](/posts/cuda-출근길-10-shared-memory와-barrier/) — block 안의 데이터 재사용과 동기화.
11. [11 - linear kernel로 확장](/posts/cuda-출근길-11-linear-kernel로-확장/) — 출력 하나를 thread 하나에 배정하기.
12. [12 - 자원 재사용과 측정](/posts/cuda-출근길-12-자원-재사용과-측정/) — 초기화와 반복 추론을 나누고 시간을 읽기.

각 편은 앞 편에서 확립한 `count = 257`, `block_dim = 128` 예제를 유지하면서 조건 하나를 추가합니다. Rust는 host와 GPU kernel 양쪽에 사용합니다. CUDA C++ 표기는 NVIDIA 공식 문서의 개념을 인용할 때만 등장하며 별도의 학습 언어로 사용하지 않습니다.

이 시리즈의 장치는 GTX 1070, compute capability 6.1입니다. 현재 mini-infer가 사용하는 Rust GPU target은 nightly-2026-04-02와 PTX 7.8로 고정되어 있습니다. 최신 CUDA 문서에는 이 장치에서 사용할 수 없는 기능도 포함되므로, 일반 CUDA 모델과 현재 장치에서 검증한 범위를 구분합니다.

NVIDIA의 **PTX ISA 문서**는 가상 명령어와 실행 모델을, **CUDA Programming Guide**는 host·device와 thread·memory 모델을 정의합니다. **Best Practices Guide**는 그 모델에서 성능을 개선하는 지침입니다. 서로 다른 층의 문서를 한 종류의 사용 설명서처럼 섞지 않습니다. [PTX ISA](https://docs.nvidia.com/cuda/parallel-thread-execution/), [CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/), [CUDA Best Practices Guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/)

현재 확인된 실행은 257개 출력이 모두 `3 * index + 7`과 일치한 probe입니다. 이는 Rust kernel이 GPU에서 실행되었다는 증거이며, 신경망 GPU 추론이나 성능 향상이 완료되었다는 뜻은 아닙니다. 검증 범위와 아직 확인하지 않은 항목은 [검증 기록](/posts/cuda-출근길-부록-검증-기록/)에 분리했습니다.
