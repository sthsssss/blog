---
title: "CUDA 출근길 03 — launch 크기와 경계 검사"
description: "원소 수를 block 크기로 올림하고 초과 thread의 메모리 접근을 막습니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:03:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


출력이 257개이고 한 block에 128개 thread가 있으면 block 두 개로는 256개 원소만 처리합니다. 마지막 원소를 처리하려면 세 번째 block이 필요합니다.

```rust
let count = 257_u32;
let config = LaunchConfig {
    grid_dim: (count.div_ceil(128), 1, 1),
    block_dim: (128, 1, 1),
    shared_mem_bytes: 0,
};
```

`div_ceil`은 나눗셈 결과를 올림합니다. `257.div_ceil(128)`은 3입니다. 따라서 host는 3 × 128 = 384개 thread가 있는 grid를 요청합니다. 필요한 원소보다 127개 thread가 많습니다.

CUDA launch는 마지막 block만 1개 thread로 줄이는 방식이 아닙니다. 같은 grid 차원의 모든 block은 같은 block 차원을 사용합니다. 그래서 kernel이 유효 범위를 검사합니다.

```rust
if i < count {
    unsafe { out.add(i as usize).write(3 * i + 7) };
}
```

인덱스 0–256의 thread만 씁니다. 257–383의 thread는 조건을 통과하지 않으며 포인터 계산과 쓰기를 수행하지 않습니다. 이 검사는 “마지막 block에 여분 thread가 있다”는 host의 launch 선택과 짝을 이룹니다.

`count = 256`이면 block은 정확히 두 개입니다. 그래도 같은 경계 검사를 유지하면 kernel의 계약이 분명하고, 다음에 입력 크기가 바뀌어도 안전한 범위를 보존합니다. `count = 0`은 별도 조건입니다. 일부 launch API와 설정은 0개의 block을 유효한 작업으로 다루지 않으므로 host에서 빈 입력을 처리하는 편이 명확합니다.

cudarc의 `LaunchConfig::for_num_elems`도 원소 수를 block 크기로 올림하는 편의 함수입니다. 현재 probe는 학습을 위해 128이라는 block 크기와 계산을 직접 보여 줍니다. [cudarc LaunchConfig 소스](https://docs.rs/cudarc/latest/src/cudarc/driver/safe/launch.rs.html)

이제 thread와 block의 번호는 계산할 수 있습니다. 다음 편에서는 이 프로그래밍 계층과 GPU가 실제 명령을 발행하는 warp를 구분합니다.

이전: [02 - kernel과 thread index](/posts/cuda-출근길-02-kernel과-thread-index/). 다음: [04 - grid, block, warp](/posts/cuda-출근길-04-grid-block-warp/).
