---
title: "CUDA 출근길 07 — 전송, stream, 동기화"
description: "host-device 복사와 kernel 제출의 순서, 완료를 관찰하는 지점을 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:07:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


host 메모리의 배열과 device global memory의 배열은 별도 저장 공간입니다. 일반적인 device allocation을 사용하는 경로에서는 입력을 host에서 device로 복사하고, kernel이 끝난 뒤 결과를 device에서 host로 복사합니다.

```rust
let device_input = stream.clone_htod(&host_input)?;
let mut device_output = stream.alloc_zeros::<u32>(count)?;

unsafe { launch.launch(config)? };
stream.synchronize()?;

let host_output = stream.clone_dtoh(&device_output)?;
```

**stream**은 GPU에 제출하는 작업의 순서를 나타냅니다. 같은 stream에 앞서 제출한 입력 복사, kernel, 결과 복사는 의존 순서대로 실행됩니다. CPU가 launch 함수를 반환받았다는 사실만으로 GPU 계산이 완료되었다고 결론 내릴 수는 없습니다.

`synchronize()`는 해당 stream의 앞선 작업이 완료될 때까지 host가 기다리고, 비동기 실행 중 발생한 오류를 관찰할 지점을 제공합니다. 결과를 host로 복사하는 API가 필요한 동기화를 포함할 수도 있지만, 학습용 probe는 완료 경계를 명시적으로 드러냅니다.

NVIDIA Programming Guide의 [Asynchronous Execution](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/asynchronous-execution.html)은 stream 안의 작업 순서와 stream 사이의 동기화 관계를 구분합니다. 여러 stream을 사용한다고 작업이 자동으로 겹치는 것은 아닙니다. 장치 기능, 메모리 종류, 의존 관계와 제출 방식이 겹침 가능성을 결정합니다.

첫 구현에서는 stream 하나와 명시적 동기화로 정확성을 확인합니다. 이후 반복 추론에서 복사와 계산을 겹치려면 event나 여러 stream의 의존 관계를 별도로 설계합니다. 비동기화는 동기화 코드를 지우는 작업이 아니라, **어느 작업이 어느 작업을 기다려야 하는지 더 정확하게 표현하는 작업**입니다.

다음 편에서는 왜 Rust 코드인데도 kernel launch가 `unsafe`인지, 어떤 오류가 launch 시점과 완료 시점에 나뉘는지 설명합니다.

이전: [06 - GPU 메모리 공간](/posts/cuda-출근길-06-gpu-메모리-공간/). 다음: [08 - unsafe와 오류 경계](/posts/cuda-출근길-08-unsafe와-오류-경계/).
