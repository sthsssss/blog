---
title: "CUDA 출근길 08 — 드라이버와 운영체제의 경계"
slug: "cuda-출근길-08-unsafe와-오류-경계"
description: "CUDA·Direct3D·WDDM·WSL의 관계, GPU 커널과 커널 모드 드라이버의 차이, 비동기 오류의 관찰을 설명합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:08:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "프로그램의 표현, CUDA 소프트웨어, GPU 하드웨어의 관계"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

CUDA가 PTX나 장치 바이너리를 생성한다고 해서 운영체제의 장치 관리를 우회하는 것은 아닙니다. 컴파일은 실행할 명령어를 준비하는 과정이고, 장치 접근·주소 매핑·작업 관리는 실행 환경의 책임입니다. 이 두 계층을 분리해야 CUDA와 Direct3D의 관계도 설명할 수 있습니다.

CUDA 커널과 커널 모드 드라이버는 이름에 같은 단어가 있지만 전혀 다른 대상입니다. CUDA 커널은 GPU에서 실행할 함수이고, 커널 모드 드라이버는 운영체제의 특권 영역에서 장치를 관리하는 소프트웨어입니다.

## API가 달라도 하위 자원은 공유할 수 있다

CUDA와 Direct3D는 애플리케이션이 사용하는 API와 셰이더·커널 컴파일 경로가 다릅니다. CUDA 커널이 Direct3D 셰이더를 거쳐 실행되는 것은 아닙니다. 하지만 같은 GPU를 사용하면 계산 자원과 메모리, 운영체제의 관리 기능을 공유할 수 있습니다.

```text
애플리케이션
 ├─ CUDA API ── NVIDIA의 CUDA 사용자 모드 경로
 └─ Direct3D API ── 그래픽스 런타임·사용자 모드 드라이버 경로
                 ↓ 플랫폼에 맞는 장치 관리
       운영체제의 GPU 관리 + 제조사 커널 모드 드라이버
                 ↓
                 GPU
```

이 그림은 책임 구분이며, 모든 호출이 같은 함수를 통과한다는 호출 스택은 아닙니다. 공개 문서로 확인하지 않은 명령 버퍼 구조나 제출 패킷을 일반 규칙처럼 단정하지 않습니다.

Windows의 WDDM 환경에서는 운영체제가 GPU 스케줄링과 비디오 메모리 관리에 참여합니다. Microsoft의 [WDDM 아키텍처 설명](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/windows-vista-and-later-display-driver-model-architecture)은 사용자 모드·커널 모드 구성 요소와 Dxgkrnl의 관계를 보여 줍니다. CUDA가 Direct3D API에 종속되지 않는다는 사실과 Windows GPU 관리 계층의 영향을 받는다는 사실은 양립합니다.

## Linux와 WSL을 구분하기

일반 Linux 환경에서는 Linux용 드라이버와 장치 접근 경로를 사용합니다. Windows에서 사용하는 WDDM 구성 요소를 그대로 Linux의 구조로 설명하면 안 됩니다.

WSL 2는 다시 구분해야 합니다. Linux 사용자 공간에서 CUDA를 사용하지만 GPU 지원은 Windows 호스트의 NVIDIA 드라이버와 연결됩니다. NVIDIA의 [CUDA on WSL 안내](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)는 WSL 내부에 일반 Linux용 GPU 드라이버를 별도로 설치하는 접근과 이 구성을 구별합니다.

따라서 환경 문제를 조사할 때에는 셸이 Linux처럼 보이는지만 확인하지 않습니다. 실제 운영 환경, 드라이버 경로, GPU 제품과 도구 버전을 함께 기록해야 합니다. 컴파일러가 설치되어 있다는 사실도 장치 실행 가능성을 보장하지 않습니다.

## 메모리 계약은 누가 확인하는가

배열 덧셈의 인수는 포인터 세 개와 원소 수입니다. 컴파일러가 함수 인수 타입을 확인하더라도 각 포인터가 실제로 `count`개의 원소를 가리키는지 증명하지는 못합니다. 잘못된 길이를 전달하면 커널의 경계 검사도 잘못된 전제를 사용합니다.

호스트는 할당 크기, 인수의 표현, 접근 가능한 장치·컨텍스트, 완료 전 수명과 충돌하는 접근의 부재를 보장해야 합니다. Driver API로 커널 인수를 직접 구성하면 ABI와 인수 저장 방식도 주의해야 합니다.

Rust의 일부 래퍼가 커널 제출을 `unsafe`로 제공하는 이유도 이 외부 실행 계약과 연결됩니다. 그러나 키워드가 없는 C++에서도 계약은 존재합니다. 언어가 다르더라도 GPU의 메모리 접근과 비동기 수명이라는 경계는 남습니다.

## 제출 오류와 실행 오류

```cpp
Add<<<gridSize, blockSize, 0, stream>>>(da, db, dc, count);
Check(cudaGetLastError());
Check(cudaStreamSynchronize(stream));
```

첫 검사는 실행 구성 등 제출 근처에서 확인할 수 있는 오류를 관찰합니다. 두 번째 검사는 해당 스트림의 완료를 기다리며 장치 실행 중 발생한 오류를 보고할 수 있습니다. CUDA는 앞선 비동기 오류를 이후 API에서 보고할 수도 있으므로 반환한 함수 이름만으로 원인이 발생한 위치를 확정하지 않습니다.

`cudaGetLastError`는 조회한 마지막 오류 상태를 초기화합니다. 그렇다고 이미 발생한 GPU의 잘못된 메모리 접근을 복구하는 것은 아닙니다. 심각한 실행 오류 뒤에는 프로세스나 컨텍스트를 재생성해야 하는 상황도 있습니다. NVIDIA의 [오류 처리 API](https://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__ERROR.html)는 상태 조회의 의미를 설명합니다.

## 정상 종료와 정답은 다르다

잘못된 인덱스로 유효한 메모리에 값을 기록하면 API 오류 없이 잘못된 결과가 나올 수 있습니다. 반대로 정답 비교가 통과한 몇 개 입력만으로 모든 경합과 범위 오류가 없다고 증명할 수도 없습니다.

검증은 빌드 성공, API 성공, 수치 결과, 메모리·동기화 검사, 성능을 나누어 수행합니다. 이 시리즈의 예제는 실행 결과를 비교하지만, 실행하지 않은 sanitizer 검사나 다중 GPU 검증을 했다고 보고하지 않습니다.

지금까지 누가 코드를 만들고, 작업을 제출하고, 어느 메모리에 접근하며, 언제 결과를 읽는지 연결했습니다. 다음 문서에서는 이 구조로 “왜 느린가”를 설명합니다.

---

이전: [07 — 스트림과 비동기 실행의 시간 모델](/posts/cuda-출근길-07-전송-stream-동기화/) · [시리즈](/posts/cuda-출근길-시리즈/) · 다음: [09 — 메모리 요청에서 성능 모델까지](/posts/cuda-출근길-09-coalescing/)
