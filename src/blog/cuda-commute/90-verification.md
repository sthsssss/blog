---
title: "CUDA 출근길 부록 — 실행 검증과 참고 자료"
slug: "cuda-출근길-부록-검증-기록"
description: "배열 덧셈의 GPU 실행, PTX·cubin·fatbinary 검증과 실제 확인 범위를 기록하고 한국어 설명 자료와 기술 근거를 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:13:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "프로그램의 표현, CUDA 소프트웨어, GPU 하드웨어의 관계"
tags: ["cuda", "cpp", "gpu", "cuda-commute", "verification"]
---

이 부록은 문서의 예제를 재현하는 방법과 실제로 확인한 범위를 기록합니다. 전체 프로그램은 [examples.cu](/downloads/cuda-commute/examples.cu)에서 내려받을 수 있습니다. 설명을 위해 일부만 보여 준 본문 코드와 달리, 전체 파일에는 헤더·오류 처리·자원 정리·결과 비교와 CPU의 진입점이 포함되어 있습니다.

## 실행 진입점과 검증 대상

`main`은 장치 0을 선택하고 검증 함수를 순서대로 호출합니다. 배열 덧셈 검사는 pinned 호스트 버퍼와 장치 버퍼를 만들고, 명시적 스트림에서 입력 복사·커널·결과 복사를 실행한 뒤 CPU에서 기대값과 비교합니다.

| 검사 | 입력과 조건 | 확인한 내용 |
| --- | --- | --- |
| 배열 덧셈 | 0, 1, 127, 128, 129, 257, 1,048,576개 | 빈 입력은 제출 생략, 나머지는 모든 원소 비교 |
| 패턴 기록 | 0, 1, 127, 128, 129, 257개 | 인덱스별 `3 * i + 7` 일치 |
| 스트림 | 257개 ReLU, 별도 스트림의 이벤트 대기 | 완료 뒤 결과 및 생산·소비 의존성 |
| 공유 메모리 | 257개의 1, 블록 크기 128 | 부분 합 `[128, 128, 1]` |
| 선형 계층 | 입력 2개, 출력 2개와 129개 | `[8.5, 0.5]` 및 반복된 기대값 |
| 이벤트 시간 | 준비 실행 뒤 커널 100회 | API 성공과 유한한 비음수 시간 |

배열 덧셈의 입력값은 작은 정수에서 변환한 FP32 값입니다. 이 범위에서 정확히 표현되는 결과를 비교한 것이며, 모든 부동소수점 입력의 수치 조건을 검증한 것은 아닙니다.

## 실제 실행 환경과 결과

2026년 11월 8일 다음 환경에서 다시 컴파일하고 실행했습니다.

| 항목 | 값 |
| --- | --- |
| GPU | NVIDIA GeForce GTX 1070 |
| 드라이버 | 560.94 |
| nvcc | CUDA 12.6, V12.6.85 |
| GPU 대상 | `sm_61` |
| 언어 | C++17 |

```bash
nvcc -std=c++17 -O2 -arch=sm_61 examples.cu -o cuda-examples
./cuda-examples
```

종료 코드 0으로 다음 결과를 확인했습니다.

```text
PASS add: 0, 1, 127, 128, 129, 257, 1048576
PASS pattern: 0, 1, 127, 128, 129, 257
PASS stream: ReLU and event dependency
PASS shared memory: [128, 128, 1]
PASS linear: [8.5, 0.5] and 129 outputs
PASS event timing: completed 100 launches (not a benchmark)
```

최신 Toolkit이 이 구형 GPU의 코드 생성을 지원한다고 가정하지 않습니다. 다른 장치에서는 지원 대상과 도구 버전을 확인해야 합니다.

## 컴파일 산출물 확인

4편의 명령으로 PTX와 cubin을 각각 생성하고, cubin과 PTX를 함께 포함한 호스트 실행 파일을 빌드했습니다. PTX에는 `.version 8.5`, `.target sm_61`, `Add`의 진입점과 전역 메모리 로드·덧셈·스토어가 포함되어 있었습니다.

`cuobjdump`로 장치 바이너리의 `Add` 함수를 디스어셈블하여 `S2R`, `LDG.E`, `FADD`, `STG.E` 등의 명령을 확인했습니다. 이는 실제 생성된 코드의 관찰이며 다른 도구 옵션이나 GPU에서도 같은 명령열이 나온다는 보장은 아닙니다.

호스트 실행 파일의 ELF 이미지 목록과 PTX 덤프에서도 장치 코드와 PTX의 포함을 확인했습니다. 같은 파일을 일반 실행했을 때 앞의 결과 비교가 통과했습니다.

PTX가 포함된 같은 실행 파일을 다음과 같이 실행하여 드라이버의 PTX JIT 경로도 확인했습니다. 모든 출력 비교가 다시 통과했습니다.

```bash
CUDA_FORCE_PTX_JIT=1 ./cuda-examples
```

이 확인은 PTX를 강제로 사용했을 때 실행 가능한지를 검사한 것입니다. JIT 캐시를 삭제하지 않았으므로 첫 컴파일의 지연 시간이나 매번 재컴파일했다는 사실을 측정한 것은 아닙니다.

## 검증에 포함되지 않은 것

이번 검증은 Compute Sanitizer의 메모리·경합 검사, Nsight 프로파일링, Tensor Core 실행, 다중 GPU, MIG·MPS와 성능 가속률 측정을 포함하지 않습니다. 이벤트 검사는 시간 API의 동작 확인이며 성능 보고가 아닙니다.

실행 성공만으로 모든 주소 범위와 동시성 조건을 증명하지 않습니다. 예제의 32비트 인덱스와 제한된 입력 크기, 고정된 공유 메모리 블록 크기는 일반 라이브러리의 계약과 다릅니다. 외부 입력을 받는 제품에서는 크기 곱셈의 오버플로, 실행 한도, 오류 복구도 추가로 다뤄야 합니다.

이 코드는 문서용 CUDA C++ 예제입니다. mini-infer의 Rust 학습용 커널을 구현하거나 사용자의 GPU 추론 완료를 검증한 것이 아닙니다.

## 한국어 설명 자료를 읽는 방법

개인 블로그는 익숙한 개념에서 새로운 구조로 넘어가는 설명 방식을 살펴보는 데 유용합니다. 다만 글의 특정 세대 수치나 간결한 비유를 보편적인 하드웨어 규칙으로 가져오지는 않았습니다. 기술적 계약은 다음 절의 공식 문서와 구분합니다.

- pangyoalto의 [CPU 서버 개발자를 위한 GPU 아키텍처](https://pangyoalto.com/gpu-architecture/)는 CPU의 메모리 대기 문제를 출발점으로 삼습니다. 이 시리즈에서도 비교할 공통 문제를 먼저 세우되 CPU와 GPU 모두 캐시와 병렬성을 사용한다는 점을 유지했습니다.
- Soeun’s Dots의 [CUDA와 NVIDIA GPU 아키텍처](https://ddoddii.github.io/post/cs/mgp/cuda-programming-3/)는 스레드 계층과 하드웨어의 관계를 별도로 다룹니다. 논리적 작업 단위와 물리적 자원을 나누어 그리는 데 참고했습니다.
- Eraser’s StudyLog의 [SM 마이크로아키텍처](https://sirzzang.github.io/cs/CS-GPU-SM-Microarchitecture/)는 내부 구성과 제품 성능 수치를 연결합니다. 본문에서는 해당 세대의 구체적인 구성을 일반 규칙과 분리했습니다.
- [GPU driver, CUDA, 라이브러리 셋팅하기](https://tkayyoo.tistory.com/17)는 설치 요소와 호환성을 구별하는 관점을 제공합니다. 본문에서는 Toolkit·런타임·드라이버와 코드 대상의 책임을 각각 설명했습니다.
- New Sight의 [CUDA Programming](https://newsight.tistory.com/135)은 실행 절차와 메모리·스레드 개념을 함께 살펴볼 수 있는 개인 학습 기록입니다. 작성 시점이 오래된 글이므로 현재 API의 보장과 세대별 조건은 별도로 확인해야 합니다.

## 기술 근거와 확장 읽기

NVIDIA의 [CUDA C++ Programming Guide 12.6](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-c-programming-guide/index.html)는 실행·메모리·동기화 모델의 기준입니다. [nvcc 문서](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-compiler-driver-nvcc/index.html), [PTX ISA](https://docs.nvidia.com/cuda/archive/12.6.0/parallel-thread-execution/index.html), [Binary Utilities](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-binary-utilities/index.html)는 소스에서 실행 코드까지의 각 경계를 설명합니다.

마이크로아키텍처는 제품별 백서와 튜닝 가이드가 필요합니다. [Pascal 가이드](https://docs.nvidia.com/cuda/pascal-tuning-guide/index.html)에서조차 GP100과 GP104가 구분됩니다. “한 세대의 GPU”라는 이름만으로 자원 수와 기능을 확정하지 않는 이유입니다.

Microsoft의 [WDDM 아키텍처](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/windows-vista-and-later-display-driver-model-architecture)는 운영체제와 드라이버의 경계를 설명하는 자료입니다. 한국어 [WPF 스레딩 모델](https://learn.microsoft.com/ko-kr/dotnet/desktop/wpf/advanced/threading-model)은 GPU의 기술 근거가 아니라 구성 요소의 책임과 실행 흐름을 연결하는 서술 방식의 참고 자료입니다.

역사는 당시 공시와 연구 논문으로, API 계약은 명세로, 제품 내부 구조는 아키텍처 문서로, 예제 결과는 실제 실행으로 확인했습니다. 서로 다른 종류의 근거를 같은 의미의 “검증”으로 합치지 않습니다.

---

이전: [12 — GPU 세대와 서비스 아키텍처로 확장하기](/posts/cuda-출근길-12-자원-재사용과-측정/) · [시리즈](/posts/cuda-출근길-시리즈/)
