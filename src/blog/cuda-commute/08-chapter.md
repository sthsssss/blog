---
title: "CUDA 출근길 08 — unsafe와 오류 경계"
description: "host와 device가 공유하는 ABI·pointer·length·lifetime 계약, launch 오류와 비동기 실행 오류를 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:08:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "cpp", "rust", "gpu", "cuda-commute"]
---

CUDA kernel launch는 type-checked C++ 함수 호출처럼 보이지만, host와 device 사이의 모든 조건을 compiler가 증명하지는 않습니다. 두 code path는 서로 다른 target으로 compile되고, pointer가 가리키는 device allocation의 크기와 thread별 access 범위는 program logic에 의해 결정됩니다. CUDA C++에는 이 경계를 표시하는 `unsafe` keyword가 없지만, operation 자체에는 memory-safety contract가 존재합니다.

```cpp
fill_pattern<<<grid_size, block_size>>>(device_output, count);
```

이 한 줄이 올바르려면 다음 조건이 모두 성립해야 합니다.

- `device_output`은 현재 CUDA context에서 유효한 device pointer입니다.
- allocation에는 적어도 `count * sizeof(unsigned int)` byte가 있습니다.
- kernel parameter type과 host가 전달한 argument representation이 일치합니다.
- 각 thread는 `index < count`인 경우에만 `device_output[index]`를 씁니다.
- GPU가 작업을 완료할 때까지 allocation과 context가 유지됩니다.
- 여러 thread가 synchronization 없이 같은 원소를 동시에 수정하지 않습니다.

CUDA compiler는 parameter type 같은 일부 조건을 검사할 수 있습니다. 그러나 allocation의 실제 크기와 kernel 내부의 모든 address 계산을 일반적으로 증명하지는 않습니다. 잘못된 program은 compile된 뒤 GPU에서 out-of-bounds access나 data race를 일으킬 수 있습니다.

## launch를 제출한 결과와 kernel이 완료된 결과는 다릅니다

CUDA launch는 일반적으로 asynchronous합니다. host가 launch statement 다음 줄로 진행했다는 사실은 GPU thread가 계산을 마쳤다는 뜻이 아닙니다. 따라서 오류도 두 관찰 지점으로 나뉩니다.

```cpp
fill_pattern<<<grid_size, block_size>>>(device_output, count);

cudaError_t launch_error = cudaGetLastError();
cudaError_t execution_error = cudaDeviceSynchronize();
```

`cudaGetLastError()`는 invalid execution configuration처럼 launch 제출 과정에서 확인되는 오류를 관찰합니다. `cudaDeviceSynchronize()`는 앞서 제출된 GPU 작업이 완료될 때까지 기다리며, illegal memory access처럼 asynchronous execution 중 발생한 오류를 반환할 수 있습니다.

두 검사를 합쳐 “kernel call이 성공했다”라고 표현하면 어느 단계가 확인됐는지 알 수 없습니다. 정확한 보고는 다음과 같이 나뉩니다.

1. Runtime이 launch request를 받아들였습니다.
2. GPU가 kernel execution을 완료했습니다.
3. 결과를 host로 복사해 expected values와 비교했습니다.

NVIDIA Programming Guide의 [error checking 설명](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/intro-to-cuda-cpp.html#error-checking-in-cuda)은 launch error와 asynchronous error를 이와 같이 구분합니다. Debugging 단계에서는 Compute Sanitizer 같은 도구로 memory access와 race를 추가 검사할 수 있지만, 도구가 모든 input과 execution path의 정확성을 증명하는 것은 아닙니다.

## Rust는 같은 계약을 unsafe operation으로 표시할 수 있습니다

mini-infer의 Rust host는 CUDA Driver API wrapper인 cudarc를 사용합니다.

```rust
let mut launch = stream.launch_builder(&kernel);
launch.arg(&mut device_output).arg(&count);

unsafe {
    launch.launch(config)?;
}
```

cudarc는 Rust lifetime과 buffer type을 이용해 일부 잘못을 줄입니다. 그러나 별도로 compile된 PTX kernel의 parameter layout, raw pointer access 범위와 thread별 write를 Rust type checker가 함께 증명하지는 않습니다. 그래서 wrapper는 launch를 `unsafe` operation으로 노출하고 호출자가 남은 contract를 검토하게 합니다.

여기서 `unsafe`는 CUDA에만 있는 특별한 위험을 새로 만드는 keyword가 아닙니다. CUDA C++에서도 존재하던 cross-target contract를 Rust API가 source code에 표시한 것입니다. `unsafe` block을 작성했다고 조건이 자동으로 만족되는 것도 아닙니다. buffer length 검사, kernel parameter 순서, synchronization과 result validation이 실제 근거입니다.

다음 편에서는 correctness를 위해 선택한 `thread i → output[i]` mapping이 performance에도 영향을 주는 이유를 살펴봅니다. 같은 warp의 thread가 요청한 address가 어떻게 global-memory transaction으로 합쳐지는지가 핵심입니다.

이전: [07 - 전송, stream, 동기화](/posts/cuda-출근길-07-전송-stream-동기화/). 다음: [09 - coalescing](/posts/cuda-출근길-09-coalescing/).
