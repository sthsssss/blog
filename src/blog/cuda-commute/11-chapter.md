---
title: "CUDA 출근길 11 — linear kernel로 확장"
description: "probe의 thread-to-output 매핑을 MLP linear 연산으로 확장하고 shape와 weight 배치를 읽습니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:11:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "cuda-commute"]
---


probe는 thread 하나가 출력 원소 하나를 만들었습니다. MLP의 단일 입력 벡터에 대한 linear 연산도 같은 출발점을 사용할 수 있습니다.

```text
output[o] = bias[o]
          + Σ weights[o * inputs + i] × input[i]
```

가장 단순한 GPU kernel은 전역 thread 인덱스를 출력 번호 `o`로 사용합니다. `o < outputs`인 thread만 실행하고, 그 thread가 모든 입력 `i`를 순회하며 하나의 누적합을 계산합니다.

```rust
let o = global_thread_index();

if o < outputs {
    let mut sum = bias[o];

    for i in 0..inputs {
        sum += weights[o * inputs + i] * input[i];
    }

    logits[o] = sum;
}
```

이 코드는 계산 규칙을 CPU 구현과 직접 비교하기 쉽습니다. thread 사이의 합산이나 barrier가 없고, 각 thread가 서로 다른 `logits[o]`를 쓰므로 출력 write race도 없습니다.

그러나 정확성 조건은 여전히 host와 kernel이 함께 지켜야 합니다.

- `input.len() == inputs`
- `weights.len() == inputs * outputs`
- `bias.len() == outputs`
- `logits.len() == outputs`
- weight는 CPU 기준과 같은 row-major 배치를 사용합니다.

GPU 결과 검증은 argmax 하나로 끝내지 않습니다. 첫 linear 출력, ReLU 출력, 두 번째 linear의 logits를 CPU 또는 저장된 기준값과 각각 비교합니다. 서로 다른 logits가 우연히 같은 예측 숫자를 만들 수 있기 때문입니다.

FP32 덧셈은 결합법칙을 보장하지 않습니다. 첫 kernel이 CPU와 같은 순서로 한 thread에서 누적하면 비교가 단순합니다. 이후 여러 thread가 하나의 출력 합을 병렬 reduction하면 합산 순서가 달라져 작은 수치 차이가 생길 수 있습니다. 성능 개선과 허용 오차 변경을 한 단계에서 섞지 않습니다.

이 kernel은 GPU를 충분히 활용하지 못할 수 있습니다. 출력이 128개나 10개뿐이면 활성 thread가 적고, 각 thread가 긴 직렬 loop를 실행합니다. 그래도 **작고 검증 가능한 기준 kernel**이라는 역할이 있습니다. 다음 최적화는 이 결과를 보존하면서 입력 차원의 병렬화, weight 배치, shared memory를 하나씩 비교해야 합니다.

다음 편에서는 모델과 작업 buffer를 매번 다시 만들지 않고 재사용하며, 초기화·전송·kernel·전체 지연을 구분해 측정합니다.

이전: [10 - shared memory와 barrier](/posts/cuda-출근길-10-shared-memory와-barrier/). 다음: [12 - 자원 재사용과 측정](/posts/cuda-출근길-12-자원-재사용과-측정/).
