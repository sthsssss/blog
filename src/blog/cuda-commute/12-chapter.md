---
title: "CUDA 출근길 12 — 자원 재사용과 측정"
description: "context·module·weights·작업 buffer를 재사용하고 kernel 시간과 전체 지연을 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:12:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


정확한 linear kernel을 한 번 실행한 뒤에는 어떤 비용을 반복 추론에 포함할지 정해야 합니다. context 생성, PTX module load, 모델 weight 전송과 buffer 할당은 일반적으로 모델 초기화 단계에 속합니다. 입력 전송, kernel launch와 결과 사용은 추론 단계에 속합니다.

```text
초기화: context → module → weights upload → work buffers
반복:   input upload → linear → ReLU → linear → result/argmax
종료:   stream 완료 확인 → device resources drop
```

매 추론마다 context와 module을 다시 만들면 kernel 계산보다 초기화 비용을 측정할 수 있습니다. GPU 모델 객체가 context 관련 자원, device weights와 작업 buffer를 소유하고 여러 입력에 재사용하도록 설계하면 두 비용을 분리할 수 있습니다.

측정값도 적어도 두 종류가 필요합니다.

- **kernel 시간**: GPU에서 해당 kernel 구간이 실행된 시간
- **전체 지연**: host가 입력을 준비한 시점부터 결과를 사용할 수 있는 시점까지

CUDA event는 같은 stream의 GPU 작업 구간을 측정하는 데 사용합니다. host의 wall-clock은 API 호출, 전송, 동기화와 host scheduling을 포함한 전체 경로를 관찰할 수 있습니다. 둘은 질문이 다르므로 하나의 “GPU 시간”으로 합치지 않습니다.

첫 실행에는 module 준비, cache와 clock 상태 같은 warm-up 효과가 포함될 수 있습니다. release build에서 warm-up 후 여러 번 측정하고, 원시 표본과 중앙값뿐 아니라 필요하면 tail도 기록합니다. 입력 shape, batch, GPU, driver, toolchain, block 크기와 commit도 함께 남겨야 결과를 재현할 수 있습니다.

**occupancy**는 SM이 보유할 수 있는 최대 warp 대비 활성 warp의 비율입니다. register와 shared memory 사용량, block 크기가 제한 요인이 됩니다. 높은 occupancy는 latency를 숨길 기회를 늘릴 수 있지만 그 자체가 높은 성능을 보장하지 않습니다. NVIDIA Best Practices Guide도 occupancy를 launch 설정의 한 판단 요소로 다루고 있습니다. [Occupancy](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#occupancy)

한 장짜리 작은 MLP에서는 GPU가 CPU보다 느릴 수 있습니다. 이는 실패가 아니라 전송·launch 고정비가 계산량보다 큰 조건을 드러낸 결과입니다. batch를 늘릴 때 처리량과 지연이 어떻게 달라지는지 측정하면 GPU가 유리해지는 작업 크기를 설명할 수 있습니다.

첫 장에서 PTX를 특정 GPU 세대와 programming language 사이의 중간층으로 보았습니다. 마지막 장의 측정은 그 추상화를 다시 실제 장치 조건으로 내려놓는 일입니다. 같은 PTX와 같은 kernel이라도 GPU 세대, driver의 code generation, block 크기와 memory access에 따라 시간은 달라집니다. 이식 가능한 실행 모델과 이식 가능한 성능은 같은 약속이 아닙니다.

이 시리즈의 끝은 “CUDA를 다 배웠다”가 아닙니다. 그래픽 장치에서 시작한 GPU가 PTX와 CUDA를 통해 범용 계산을 받아들이는 이유를 이해하고, probe에서 정확한 GPU linear로 나아가며 자원 수명과 측정 조건을 설명할 수 있는 기준점을 마련한 것입니다. 최적화는 기준 결과와 원시 측정값을 보존한 채 한 가지 변경씩 진행합니다.

이전: [11 - linear kernel로 확장](/posts/cuda-출근길-11-linear-kernel로-확장/). 전체 순서: [시리즈 안내](/posts/cuda-출근길-시리즈/). 검증: [부록 - 검증 기록](/posts/cuda-출근길-부록-검증-기록/).
