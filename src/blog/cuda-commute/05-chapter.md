---
title: "CUDA 출근길 05 — main에서 커널 실행까지의 CUDA 소프트웨어 구조"
slug: "cuda-출근길-05-simt와-분기"
description: "Toolkit·Runtime API·Driver API의 책임과 컨텍스트·모듈·스트림을 실제 배열 덧셈의 실행 경로로 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:05:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "프로그램의 표현, CUDA 소프트웨어, GPU 하드웨어의 관계"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

CUDA 프로그램도 CPU에서 실행되는 프로세스로 시작합니다. 운영체제가 호스트 실행 파일을 적재하고 CPU가 `main`을 실행합니다. GPU 계산은 이 호스트 코드가 CUDA API를 통해 요청하는 작업입니다.

따라서 실행 경로를 따라갈 때에는 컴파일러부터 다시 시작하지 않습니다. 이미 만들어진 실행 파일과 장치 코드가 있다는 전제에서, 어떤 소프트웨어가 장치 상태를 만들고 어떤 요청을 제출하는지 살펴봅니다.

## CUDA라는 이름 안의 서로 다른 책임

| 구성 요소 | 주된 책임 | 실행 시 항상 필요한가 |
| --- | --- | --- |
| CUDA 프로그래밍 모델 | 커널·스레드 계층·메모리·동기화 계약 정의 | 프로그램의 의미를 결정 |
| CUDA Toolkit | 컴파일러·헤더·개발 도구·라이브러리 공급 | 전체 개발 도구 설치가 모든 실행에 필요한 것은 아님 |
| Runtime API | 장치 선택, 할당, 복사, 커널 제출 등 편의 API | 해당 API로 만든 프로그램에서 사용 |
| Driver API | 컨텍스트·모듈·함수·실행을 더 직접 제어 | NVIDIA 사용자 모드 드라이버 경로 |
| 운영체제와 커널 모드 드라이버 | 장치 접근, 자원·메모리·작업 관리 | 운영 환경에 맞는 구현 필요 |

Runtime API의 함수는 보통 `cuda`로, Driver API의 함수는 `cu`로 시작합니다. `cudaMalloc`과 `cuMemAlloc`이 대표적인 예입니다. 둘은 서로 다른 GPU 하드웨어를 사용하는 API가 아니라 관리 책임을 드러내는 수준이 다른 인터페이스입니다.

Linux에서 `libcudart`는 CUDA 런타임, `libcuda.so`는 드라이버 API 라이브러리입니다. 정적 링크 여부나 운영체제에 따라 파일 형태는 달라질 수 있습니다. `nvcc`는 빌드 도구이지 매 커널 호출을 받아 실행하는 상주 서버가 아닙니다.

## 컨텍스트와 모듈

컨텍스트는 장치 사용과 관련된 실행 상태와 자원을 묶는 관리 단위입니다. CPU의 스택 프레임도 아니고 GPU의 SM 하나도 아닙니다. 호스트의 어떤 스레드가 CUDA API를 호출하는지와 어떤 장치 컨텍스트의 자원을 다루는지는 구분해야 합니다.

모듈은 장치 코드와 관련 심벌을 적재하는 단위입니다. Driver API에서는 모듈을 적재하고 커널 함수를 찾아 인수와 함께 실행하는 구조가 드러납니다. Runtime API는 이 관리의 상당 부분을 감추고, 일반적으로 장치의 primary context를 사용하도록 돕습니다. NVIDIA의 [Driver API와 Runtime API 비교](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-driver-api/driver-vs-runtime-api.html)는 이 책임 분담을 설명합니다.

`Add<<<...>>>`를 쓰면 컴파일러가 준비한 호스트 측 코드와 런타임이 커널 진입점과 인수를 연결합니다. CPU가 GPU 함수의 주소로 일반적인 함수 호출을 하는 것이 아닙니다. 실제 모듈 적재 시점은 지연 적재 설정 등에 따라 달라질 수 있으므로 소스 한 줄과 내부 단계 하나를 일대일로 대응시키지는 않습니다.

## 진입점에서 배열 덧셈 따라가기

전체 소스의 `main`은 장치 0을 선택하고 `VerifyAdd`를 호출합니다. 이 함수는 입력 크기마다 호스트 버퍼 세 개와 장치 버퍼 세 개를 준비하고 하나의 명시적 스트림을 만듭니다. 스트림은 작업의 순서를 표현하는 단위이며 세부 동기화는 다음 문서들에서 설명합니다.

중심 실행 부분은 다음과 같습니다. `Check`는 실패한 CUDA 상태 코드를 예외로 보고하는 보조 함수입니다.

```cpp
Check(cudaMemcpyAsync(da.data, a.data, bytes,
                      cudaMemcpyHostToDevice, stream.value));
Check(cudaMemcpyAsync(db.data, b.data, bytes,
                      cudaMemcpyHostToDevice, stream.value));

Add<<<GridSize(count), 128, 0, stream.value>>>(
    da.data, db.data, dc.data, count);
Check(cudaGetLastError());

Check(cudaMemcpyAsync(c.data, dc.data, bytes,
                      cudaMemcpyDeviceToHost, stream.value));
Check(cudaStreamSynchronize(stream.value));
```

첫 두 요청은 입력을 장치 버퍼로 복사합니다. 커널 요청은 장치 주소 세 개와 원소 수를 전달합니다. 다음 요청은 결과를 호스트 버퍼로 복사합니다. 마지막 대기가 성공한 뒤에 CPU가 결과를 비교합니다.

인수로 포인터를 전달하는 것과 배열 내용을 복사하는 것은 다른 동작입니다. 커널 인수에 `da.data`를 넣는다고 호스트 배열 전체가 암묵적으로 전송되지 않습니다. 앞선 복사 요청으로 채워진 장치 버퍼를 커널이 읽는 것입니다.

## 제출 순서와 장치 실행

위 코드를 호출하는 CPU는 각 요청을 준비하고 제출합니다. GPU에서는 앞서 설명한 블록 배치와 워프 실행이 진행됩니다. 이 사이에는 드라이버의 작업 관리와 장치의 작업 수신 기능이 있습니다.

공개 API만으로 내부 명령 버퍼의 정확한 형태나 모든 제출의 커널 모드 전환 횟수를 단정할 수는 없습니다. 문서에서 보장하는 것은 인수·자원·순서·완료의 계약입니다. 구현 세부는 드라이버와 운영체제에 따라 달라질 수 있습니다.

```text
CPU main
  → CUDA API와 사용자 모드 드라이버
  → 운영체제·장치 드라이버의 자원 및 제출 경로
  → GPU의 작업 처리
  → 블록 배치 → SM의 워프 명령 실행
```

이제 “CUDA가 실행한다”는 표현을 더 구체적으로 나눌 수 있습니다. 컴파일러는 코드를 만들고, 호스트 런타임과 드라이버는 실행을 준비하며, GPU 하드웨어는 명령을 실행합니다. 다음 문서에서는 이 과정에서 오가는 주소가 어떤 저장 공간을 가리키는지 설명합니다.

---

이전: [04 — 컴파일러에서 PTX와 GPU 기계어까지](/posts/cuda-출근길-04-grid-block-warp/) · [시리즈](/posts/cuda-출근길-시리즈/) · 다음: [06 — 주소 공간과 GPU 메모리 계층](/posts/cuda-출근길-06-gpu-메모리-공간/)
