---
title: "CUDA 출근길 06 — GPU 메모리 공간"
description: "register·local·shared·global memory를 접근 범위와 수명으로 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:06:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


GPU의 처리량은 계산기 수만으로 나오지 않습니다. 수많은 thread의 작업 상태를 가까운 register에 두고, block의 협력 데이터는 shared memory에 두며, 큰 데이터는 global memory에 보관하는 계층이 함께 필요합니다. 이 구조는 CPU cache의 이름만 바꾼 것이 아니라 대량의 독립 작업을 교대로 진행해 memory latency를 숨기려는 GPU 실행 모델과 맞물립니다.

따라서 GPU의 모든 값이 같은 메모리에 저장되는 것은 아닙니다. CUDA의 메모리 공간은 접근할 수 있는 thread의 범위와 수명, 성능 특성이 다릅니다.

| 공간 | 주된 접근 범위 | 일반적인 수명 |
| --- | --- | --- |
| register | 한 thread | thread 실행 |
| local memory | 한 thread | thread 실행 |
| shared memory | 한 block | block 실행 |
| global memory | device의 여러 thread와 host API | 할당부터 해제까지 |

kernel의 지역 변수 `i`는 소스 수준에서 한 thread의 값입니다. 컴파일러는 가능한 경우 register에 배치합니다. register가 부족하거나 주소가 필요한 배열 같은 값은 local memory로 내려갈 수 있습니다. 이름은 local이지만 물리적으로 항상 빠른 on-chip 저장 공간이라는 뜻은 아닙니다.

`out`이 가리키는 배열은 global memory에 있습니다. 여러 block의 thread가 접근할 수 있고 kernel 호출이 끝난 뒤에도 할당이 남습니다. 그래서 host가 결과를 다시 복사할 수 있습니다. 접근 범위가 넓은 대신 register나 shared memory보다 지연이 큽니다.

shared memory는 같은 block의 thread가 데이터를 재사용하고 협력할 때 사용합니다. 다른 block은 같은 shared memory 인스턴스에 접근하지 않습니다. block이 끝나면 그 저장 내용도 유지되지 않습니다.

NVIDIA의 Best Practices Guide는 memory space를 위치·cache·접근 범위·수명으로 비교하고 있습니다. 이 표는 절대적인 한 사이클 비용표가 아니라 어떤 값을 어디에 둘지 판단하는 모델입니다. [Device Memory Spaces](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#device-memory-spaces)

host language의 object lifetime과 CUDA memory space는 같은 개념이 아닙니다. host의 buffer wrapper가 global-memory allocation의 해제 책임을 관리할 수 있지만, kernel parameter로 전달된 device pointer가 그 host object를 소유하는 것은 아닙니다. GPU 실행이 끝날 때까지 유효한 allocation과 범위를 제공하는 책임은 launch contract에 남습니다.

다음 편에서는 host의 값이 global memory에 도착하고, kernel 작업과 결과 복사가 stream에서 어떤 순서로 완료되는지 살펴봅니다.

이전: [05 - SIMT와 분기](/posts/cuda-출근길-05-simt와-분기/). 다음: [07 - 전송, stream, 동기화](/posts/cuda-출근길-07-전송-stream-동기화/).
