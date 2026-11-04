---
title: "CUDA 출근길 03 — launch 크기와 경계 검사"
description: "원소 수를 block 크기로 올림하고 초과 thread의 메모리 접근을 막습니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:03:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


CUDA의 scalability model은 application이 “G80의 processor 몇 번에서 실행하라”고 지정하지 않는 데서 시작합니다. host는 처리할 work를 grid와 block으로 표현하고, GPU scheduler는 현재 장치의 streaming multiprocessor에 block을 배치합니다. 같은 launch가 SM 수가 다른 GPU에서도 의미를 유지하는 이유입니다.

출력이 257개이고 한 block에 128개 thread가 있으면 block 두 개로는 256개 원소만 처리합니다. 마지막 원소를 처리하려면 세 번째 block이 필요합니다.

```cpp
constexpr unsigned int count = 257;
constexpr unsigned int block_size = 128;
unsigned int grid_size = (count + block_size - 1) / block_size;

fill_pattern<<<grid_size, block_size>>>(device_output, count);
```

`div_ceil`은 나눗셈 결과를 올림합니다. `257.div_ceil(128)`은 3입니다. 따라서 host는 3 × 128 = 384개 thread가 있는 grid를 요청합니다. 필요한 원소보다 127개 thread가 많습니다.

CUDA launch는 마지막 block만 1개 thread로 줄이는 방식이 아닙니다. 같은 grid 차원의 모든 block은 같은 block 차원을 사용합니다. 그래서 kernel이 유효 범위를 검사합니다.

```cpp
if (i < count) {
    output[i] = 3 * i + 7;
}
```

인덱스 0–256의 thread만 씁니다. 257–383의 thread는 조건을 통과하지 않으며 포인터 계산과 쓰기를 수행하지 않습니다. 이 검사는 “마지막 block에 여분 thread가 있다”는 host의 launch 선택과 짝을 이룹니다.

`count = 256`이면 block은 정확히 두 개입니다. 그래도 같은 경계 검사를 유지하면 kernel의 계약이 분명하고, 다음에 입력 크기가 바뀌어도 안전한 범위를 보존합니다. `count = 0`은 별도 조건입니다. 일부 launch API와 설정은 0개의 block을 유효한 작업으로 다루지 않으므로 host에서 빈 입력을 처리하는 편이 명확합니다.

실제 project에서는 launch helper가 이 올림 계산을 감쌀 수 있습니다. 첫 예제에서는 `grid_size` 계산과 kernel의 범위 검사가 서로 대응한다는 사실을 보이기 위해 식을 직접 작성합니다.

이제 thread와 block의 번호는 계산할 수 있습니다. 다음 편에서는 이 프로그래밍 계층과 GPU가 실제 명령을 발행하는 warp를 구분합니다.

이전: [02 - kernel과 thread index](/posts/cuda-출근길-02-kernel과-thread-index/). 다음: [04 - grid, block, warp](/posts/cuda-출근길-04-grid-block-warp/).
