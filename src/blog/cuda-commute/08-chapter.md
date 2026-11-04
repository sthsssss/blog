---
title: "CUDA 출근길 08 — unsafe와 오류 경계"
description: "kernel 인수·포인터·길이·수명 계약과 launch/완료 오류를 분리합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:08:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


Rust로 host와 kernel을 모두 작성해도 CUDA launch 전체가 자동으로 memory-safe해지지는 않습니다. host와 device는 별도로 컴파일되고, driver는 kernel 이름과 인수 배치를 바탕으로 실행을 연결합니다.

```rust
let mut launch = stream.launch_builder(&kernel);
launch.arg(&mut device_output).arg(&count);

unsafe {
    launch.launch(config)?;
}
```

cudarc의 builder는 Rust 수명과 읽기·쓰기 의도를 이용해 많은 잘못을 줄입니다. 그러나 host가 로드한 kernel의 실제 매개변수 순서·타입과 builder에 넣은 값이 일치하는지, thread가 포인터 범위를 벗어나지 않는지까지 Rust 타입 시스템이 두 compilation target 사이에서 증명하지는 않습니다. 이 남은 계약 때문에 launch가 `unsafe`입니다.

안전 조건은 구체적으로 적을 수 있습니다.

- 첫 인수는 적어도 `count`개의 `u32`를 쓸 수 있는 device allocation입니다.
- 둘째 인수의 표현과 kernel의 `u32` 매개변수가 일치합니다.
- 모든 thread는 `i < count`인 경우에만 `out[i]`를 씁니다.
- GPU가 사용을 마칠 때까지 allocation과 context가 유효합니다.
- 여러 thread가 같은 원소를 동시에 수정하지 않습니다.

오류도 두 시점으로 나뉩니다. launch API 자체가 잘못된 설정이나 인수를 거절할 수 있고, 비동기 실행 중의 잘못된 메모리 접근은 이후 synchronize나 복사 지점에서 보고될 수 있습니다. launch의 `Result`만 확인하고 완료 오류를 확인하지 않으면 실행 성공을 과장할 수 있습니다.

NVIDIA Programming Guide의 [Error Checking](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/intro-to-cuda-cpp.html#error-checking-in-cuda)은 즉시 확인한 launch 상태가 kernel 실행 완료를 뜻하지 않으며, 비동기 오류는 이후 동기화 지점에서 나타날 수 있다고 구분하고 있습니다.

`unsafe` 블록은 “여기부터 검사하지 않는다”는 표시가 아닙니다. 컴파일러가 증명하지 못하는 조건을 호출자가 검토한다는 경계입니다. 안전 조건을 짧은 주석과 shape 검사로 launch 가까이에 유지하면 리뷰할 대상이 분명해집니다.

다음 편에서는 정확한 인접 쓰기 패턴이 global memory 성능에도 유리한 이유를 warp의 memory transaction으로 연결합니다.

이전: [07 - 전송, stream, 동기화](/posts/cuda-출근길-07-전송-stream-동기화/). 다음: [09 - coalescing](/posts/cuda-출근길-09-coalescing/).
