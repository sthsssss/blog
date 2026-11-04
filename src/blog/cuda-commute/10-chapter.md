---
title: "CUDA 출근길 10 — shared memory와 barrier"
description: "block 안에서 데이터를 재사용할 때 저장과 barrier가 해결하는 문제를 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:10:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


global memory의 같은 입력을 block의 여러 thread가 반복해서 읽는다면, 일부 값을 shared memory에 가져와 재사용할 수 있습니다. shared memory는 block마다 별도로 존재하며 그 block의 thread만 접근합니다.

개념적인 tile 흐름은 다음과 같습니다.

```text
각 thread가 global input 일부를 shared tile에 기록
                    ↓
          block 범위 barrier
                    ↓
각 thread가 shared tile을 읽어 자신의 누적합 계산
```

barrier가 필요한 이유는 thread별 실행 속도가 같다고 보장할 수 없기 때문입니다. 어떤 thread가 tile 기록을 끝내기 전에 다른 thread가 그 위치를 읽으면 아직 준비되지 않은 값을 사용할 수 있습니다. block barrier는 모든 참여 thread가 해당 지점에 도착한 뒤 다음 단계로 진행하게 합니다.

NVIDIA Programming Guide는 `__syncthreads()`가 같은 block의 thread만 동기화한다고 명시합니다. 다른 frontend가 PTX barrier instruction을 생성하더라도 동기화 범위는 같습니다. [CUDA kernel의 shared memory와 동기화](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/intro-to-cuda-cpp.html)

조건문 안에서 일부 thread만 barrier에 도착하도록 만들면 교착이나 정의되지 않은 동작으로 이어질 수 있습니다. 경계 밖 thread도 협력 단계의 barrier에는 참여하고, 실제 global load나 계산만 조건으로 막는 형태가 필요할 수 있습니다.

shared memory가 항상 빠르게 만드는 것도 아닙니다. global load의 중복을 줄일 수 있지만 tile을 복사하는 명령, barrier, shared memory 사용량이 추가됩니다. 같은 bank를 여러 thread가 충돌하는 방식으로 접근하면 요청이 직렬화될 수 있습니다. NVIDIA Best Practices Guide는 shared memory가 재사용과 coalescing을 돕는 경우와 bank conflict를 함께 설명하고 있습니다. [Shared Memory and Memory Banks](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#shared-memory)

첫 linear kernel은 shared memory 없이 정확성을 검증합니다. 그 결과와 접근 패턴을 측정한 뒤 tile을 추가해야 최적화의 효과와 비용을 비교할 수 있습니다.

이전: [09 - coalescing](/posts/cuda-출근길-09-coalescing/). 다음: [11 - linear kernel로 확장](/posts/cuda-출근길-11-linear-kernel로-확장/).
