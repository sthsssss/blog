---
title: "CUDA 출근길 부록 — 검증 기록"
description: "Rust CUDA probe의 실제 실행 결과와 문서에서 설명만 한 항목을 분리해 기록합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:13:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: CUDA C++에서 PTX와 GPU architecture를 거쳐 linear kernel까지"
tags: ["cuda", "rust", "gpu", "cuda-commute", "verification"]
---

이 부록은 실제 장치에서 관찰한 결과와 문서의 설계 설명을 구분합니다. 글과 명령이 존재한다는 사실은 독자의 구현 완료나 CUDA 숙련을 뜻하지 않습니다.

**검증된 환경**

- GPU: NVIDIA GeForce GTX 1070
- compute capability target: sm_61
- GPU kernel 언어: Rust
- kernel toolchain: nightly-2026-04-02
- PTX target: 7.8
- host: Rust와 cudarc
- probe 원소 수: 257
- block 크기: 128

사용자가 실행한 명령은 다음과 같습니다.

```text
cargo run --locked --features cuda --bin cuda-probe
```

보고된 결과는 257개 원소가 모두 `3 * index + 7`과 일치했다는 것입니다. 이는 context 생성, PTX module load, device buffer 할당, kernel launch, 완료 대기와 device-to-host 결과 확인 경로가 해당 장치에서 실행되었다는 증거입니다.

이 결과만으로 확인되지 않은 항목은 다음과 같습니다.

- GPU linear kernel의 구현과 수치 일치
- ReLU와 두 번째 linear를 포함한 GPU forward
- CPU 대비 성능 향상
- shared memory 또는 coalescing 최적화의 효과
- 여러 stream의 overlap
- sanitizer가 확인한 모든 메모리 접근
- model accuracy의 GPU 재평가

CPU linear와 저장된 NumPy 중간값의 비교는 별도 검증입니다. probe 성공을 신경망 GPU 추론 성공으로 합치지 않습니다.

시리즈의 09–12편은 성능과 이후 구현을 위한 설계 기준을 설명합니다. 실제 수치가 없는 곳에는 특정 속도 향상이나 bandwidth를 주장하지 않았습니다. GTX 1070과 최신 NVIDIA 문서의 기능 범위가 다를 수 있으므로 sm_61에서 지원하지 않는 최신 기능을 현재 구현에 적용했다고 서술하지 않습니다.

**다음 검증 순서**

1. 작은 hand-calculated shape에서 GPU linear와 CPU 결과를 비교합니다.
2. 784→128과 128→10 각 층의 출력을 비교합니다.
3. 10개 reference sample의 hidden linear·ReLU·logits를 비교합니다.
4. 비정렬 출력 크기와 잘못된 shape를 검사합니다.
5. 반복 추론에서 초기화와 kernel·전체 지연을 분리해 측정합니다.
6. 기준 kernel을 보존한 뒤 최적화 하나씩 결과와 시간을 재측정합니다.

전체 순서: [CUDA 출근길 시리즈](/posts/cuda-출근길-시리즈/).
