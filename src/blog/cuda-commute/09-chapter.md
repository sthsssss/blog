---
title: "CUDA 출근길 09 — coalescing"
description: "warp의 인접 thread가 인접 global memory 주소를 접근할 때 transaction이 합쳐지는 원리를 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:09:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


probe에서는 thread `i`가 `out[i]`를 씁니다. 같은 warp의 thread 0–31은 연속된 32개의 `u32` 원소에 접근합니다. 이 패턴은 global memory 요청을 적은 수의 transaction으로 묶기 쉽습니다.

NVIDIA는 warp의 global memory load/store가 필요한 memory transaction으로 **coalesce**된다고 설명합니다. compute capability 6.0 이상에서 필요한 32바이트 구간의 수가 핵심 기준입니다. GTX 1070은 compute capability 6.1이므로 이 설명 범위에 들어갑니다. [Coalesced Access to Global Memory](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#coalesced-access-to-global-memory)

```text
thread:   0   1   2   3   ... 31
address: out out+4 out+8 out+12 ... 연속
```

각 `u32`는 4바이트입니다. warp 전체가 128바이트의 연속 영역을 정렬된 위치에서 접근하면, 필요한 32바이트 구간들로 요청을 처리할 수 있습니다. 시작 주소가 어긋나거나 thread마다 큰 stride로 떨어진 주소를 읽으면 더 많은 구간과 transaction이 필요할 수 있습니다.

coalescing은 “thread가 순서대로 하나씩 실행된다”는 뜻이 아닙니다. 같은 warp가 요청한 주소들의 배치를 메모리 시스템이 묶는 것입니다. 또한 cache가 있으므로 transaction 수와 실제 DRAM traffic이 항상 같은 값은 아닙니다.

linear kernel에서 weight 배치를 정할 때 이 원리가 중요합니다. 인접 thread가 서로 다른 출력 `o`를 담당할 경우, 같은 입력 `i`에서 접근하는 `weights[o * inputs + i]`는 출력 간 stride가 `inputs`입니다. 단순한 CPU용 row-major 배치를 그대로 쓰면 warp의 weight 접근이 멀리 떨어질 수 있습니다. 첫 정확성 kernel과 이후 성능용 배치 변경을 분리해야 하는 이유입니다.

다음 편에서는 여러 thread가 같은 입력을 반복해서 읽을 때 shared memory에 한 번 가져와 block 안에서 재사용하는 구조와 필요한 barrier를 살펴봅니다.

이전: [08 - unsafe와 오류 경계](/posts/cuda-출근길-08-unsafe와-오류-경계/). 다음: [10 - shared memory와 barrier](/posts/cuda-출근길-10-shared-memory와-barrier/).
