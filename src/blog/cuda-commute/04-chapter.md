---
title: "CUDA 출근길 04 — grid, block, warp"
description: "grid와 block의 협력 범위, warp의 실행 단위를 서로 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:04:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


G80의 unified processor는 그래픽 작업의 종류에 고정되지 않은 계산 자원을 만들었지만, 프로그램을 특정 processor 개수와 배치에 고정하면 다음 GPU 세대로 옮기기 어렵습니다. CUDA는 작업을 물리적 core 번호가 아니라 **grid**, **block**, **thread**라는 논리 계층으로 표현합니다. hardware scheduler가 block을 실행 가능한 streaming multiprocessor(SM)에 배치하므로 같은 kernel을 규모가 다른 GPU에서 실행할 수 있습니다.

CUDA에서 host가 launch하는 전체 thread 집합은 **grid**입니다. grid는 여러 **block**으로 나뉘고, block은 여러 thread를 포함합니다. 이 둘은 코드에서 지정하는 프로그래밍 계층입니다.

```text
grid
├─ block 0: thread 0 ... 127
├─ block 1: thread 0 ... 127
└─ block 2: thread 0 ... 127
```

각 block은 독립적으로 어느 streaming multiprocessor(SM)에 배치될 수 있습니다. block 사이의 실행 순서를 일반 kernel 안에서 가정하면 안 됩니다. 반면 같은 block의 thread는 shared memory를 공유하고 block 범위 barrier로 협력할 수 있습니다.

**warp**는 하드웨어가 thread를 묶어 명령을 실행하는 단위입니다. NVIDIA GPU의 warp는 32개 thread로 구성됩니다. block 크기가 128이면 네 warp가 생깁니다. warp 번호를 launch 설정에 직접 쓰지는 않지만, 메모리 접근과 분기 성능을 설명할 때 warp가 기준이 됩니다.

NVIDIA Programming Guide의 [Warps and SIMT](https://docs.nvidia.com/cuda/cuda-programming-guide/01-introduction/programming-model.html#warps-and-simt)는 block의 thread가 32개 lane의 warp로 묶이는 관계를 설명하고 있습니다.

block 크기를 130으로 정하면 다섯 번째 warp에는 유효한 thread가 두 개뿐입니다. 나머지 lane은 해당 block에 속한 작업을 하지 않습니다. 그래서 block 크기를 warp 크기의 배수로 고르는 경우가 많습니다. 그러나 “항상 128이 최적”이라는 규칙은 아닙니다. register 사용량, shared memory, kernel의 연산량과 장치 제한이 동시에 영향을 줍니다.

block은 scheduling과 협력의 단위이고, warp는 명령 발행과 메모리 요청을 이해하는 단위입니다. 두 용어를 섞으면 “block 안의 모든 thread가 항상 같은 순간에 실행된다”거나 “warp끼리 barrier 없이 데이터를 공유할 수 있다”는 잘못된 결론으로 이어집니다.

다음 편에서는 같은 warp의 thread가 같은 kernel 본문을 실행하면서도 조건문에서 서로 다른 경로를 선택할 때 무슨 일이 생기는지 살펴봅니다.

이전: [03 - launch 크기와 경계 검사](/posts/cuda-출근길-03-launch-크기와-경계-검사/). 다음: [05 - SIMT와 분기](/posts/cuda-출근길-05-simt와-분기/).
