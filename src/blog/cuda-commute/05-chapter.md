---
title: "CUDA 출근길 05 — SIMT와 분기"
description: "warp가 같은 명령 흐름을 실행하면서 thread별 데이터와 조건을 처리하는 방식을 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:05:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


그래픽 pipeline은 많은 vertex와 pixel에 비슷한 계산을 반복합니다. G80은 이 처리 방식에서 발전한 **SIMT(Single Instruction, Multiple Threads)** 실행 모델을 CUDA 계산에 사용했습니다. thread마다 인덱스와 register 상태가 있지만, warp는 여러 thread의 명령을 함께 발행합니다. 따라서 같은 코드를 실행한다는 말과 모든 thread의 데이터가 같다는 말은 다릅니다.

probe의 경계 조건에서 마지막 warp를 생각해 봅니다.

```cpp
if (i < count) {
    output[i] = 3 * i + 7;
}
```

`count = 257`일 때 마지막 block의 첫 thread만 조건이 참이고 나머지는 거짓입니다. 같은 warp 안에서 경로가 나뉩니다. GPU는 활성 lane을 구분하여 필요한 경로를 실행합니다. 이런 현상을 **branch divergence**라고 부릅니다.

분기가 있다고 항상 성능 문제가 되는 것은 아닙니다. 이 경계 분기는 전체 grid에서 마지막 warp에만 영향을 주고, 범위 밖 쓰기를 막기 위해 필요합니다. 먼저 정확성을 보장한 뒤 측정으로 비용을 판단해야 합니다.

반대로 데이터 값에 따라 반복문의 횟수가 크게 달라지고 warp의 thread마다 다른 경로를 오래 실행한다면, 일부 lane이 쉬는 시간이 커질 수 있습니다. 이 경우 데이터 배치나 알고리즘을 바꿔 같은 warp가 비슷한 작업을 하게 만드는 방법을 검토합니다.

NVIDIA Best Practices Guide의 [Branching and Divergence](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/#branching-and-divergence)는 같은 warp의 서로 다른 실행 경로가 별도로 처리되어 instruction 수가 늘어나는 관계를 설명하고 있습니다. 현재 GTX 1070은 Pascal 계열 sm_61이며, 이 시리즈는 warp 안의 암묵적 실행 순서에 기대지 않고 명시적 동기화 범위를 기준으로 설명합니다.

다음 편에서는 thread가 계산 중 사용하는 값이 어느 메모리 공간에 놓이고, 누가 그 값에 접근할 수 있는지 나눕니다.

이전: [04 - grid, block, warp](/posts/cuda-출근길-04-grid-block-warp/). 다음: [06 - GPU 메모리 공간](/posts/cuda-출근길-06-gpu-메모리-공간/).
