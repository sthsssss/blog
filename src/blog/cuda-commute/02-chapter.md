---
title: "CUDA 출근길 02 — kernel과 thread index"
description: "block과 thread 좌표를 전역 원소 번호로 바꾸어 각 thread의 작업을 정합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:02:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


모든 GPU thread는 같은 `probe_pattern` 본문에서 시작합니다. 서로 다른 원소를 처리하게 만드는 값은 각 thread가 읽는 내장 인덱스입니다.

```rust
let i = unsafe {
    (_block_idx_x() * _block_dim_x() + _thread_idx_x()) as u32
};
```

`_thread_idx_x()`는 현재 block 안에서의 번호입니다. `_block_idx_x()`는 grid 안에서 현재 block의 번호이고, `_block_dim_x()`는 한 block에 배치한 thread 수입니다. 1차원 배치에서 전역 번호는 다음과 같습니다.

```text
global index = block index × threads per block + thread index
```

block당 128개 thread를 사용하면 block 0은 인덱스 0–127, block 1은 128–255를 얻습니다. block 2의 첫 thread는 256을 얻습니다. 이 계산은 thread를 새로 만들지 않습니다. host가 정한 실행 배치 안에서 현재 thread가 담당할 데이터 위치를 계산합니다.

NVIDIA Programming Guide의 [Thread Hierarchy](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/writing-cuda-kernels.html#thread-hierarchy)는 `blockIdx`·`blockDim`·`threadIdx`가 각각 무엇을 나타내며 전역 인덱스 계산에 어떻게 사용되는지 설명하고 있습니다.

```rust
if i < count {
    unsafe {
        out.add(i as usize).write(3 * i + 7);
    }
}
```

`out.add(i)`는 출력 시작 주소에서 `i`번째 `u32` 위치를 계산합니다. `write`는 그 위치에 값을 기록합니다. 인덱스 계산이 틀리면 서로 다른 thread가 같은 원소를 쓰거나 할당 범위를 벗어날 수 있습니다.

여기서 “thread 하나가 원소 하나를 처리한다”는 것은 CUDA가 강제하는 규칙이 아니라 이 kernel의 **작업 매핑**입니다. 한 thread가 여러 원소를 반복 처리할 수도 있고, 여러 thread가 한 결과를 협력해 만들 수도 있습니다. 단순한 1:1 매핑은 첫 kernel의 결과를 추적하기 쉽고, 인접 thread가 인접 주소를 쓰므로 뒤에서 다룰 coalescing에도 유리합니다.

다음 편에서는 출력이 257개인데 block 크기가 128일 때 왜 thread가 384개 실행되는지, 남는 thread가 왜 필요한지 설명합니다.

이전: [01 - PTX에서 시작하는 GPU의 역사](/posts/cuda-출근길-01-ptx에서-시작하는-gpu의-역사/). 다음: [03 - launch 크기와 경계 검사](/posts/cuda-출근길-03-launch-크기와-경계-검사/).
