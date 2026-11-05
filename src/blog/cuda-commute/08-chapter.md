---
title: "CUDA 출근길 08 — unsafe와 오류 경계"
description: "포인터·크기·수명 계약, 제출 오류와 비동기 오류 및 드라이버 계층을 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:08:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA의 배경, 실행 모델 및 애플리케이션 구성"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

CUDA 커널을 안전하게 실행하려면 전달한 주소, 배열 크기, 실행 구성 및 자원 수명이 서로 일치해야 합니다. 소스가 컴파일되었다는 사실만으로 이 조건을 모두 확인한 것은 아닙니다. 잘못된 주소 계산이나 동기화 누락은 GPU가 실행하는 동안 오류나 잘못된 결과를 만들 수 있습니다.

이 문서에서는 커널 호출의 조건과 오류를 관찰하는 위치를 설명합니다. 또한 CUDA의 실행 드라이버와 운영체제의 GPU 관리 계층을 구분합니다. 제목의 `unsafe`는 마지막 절에서 다른 언어가 같은 계약을 표현하는 사례로 다룹니다.

## 포인터와 원소 수의 계약

다음 호출은 `deviceOutput` 주소와 `count` 값을 커널에 전달합니다.

```cpp
FillPattern<<<gridSize, blockSize>>>(deviceOutput, count);
```

커널은 포인터 자체에서 할당 길이를 알아낼 수 없습니다. `count`개의 원소가 실제로 존재하는지는 호스트가 보장해야 합니다. 커널이 `index < count`를 검사하더라도 잘못된 `count`를 전달하면 범위를 벗어날 수 있습니다.

호스트 측에서 확인할 조건은 다음과 같습니다.

| 조건 | 확인할 대상 |
| --- | --- |
| 주소 유효성 | 현재 작업에서 사용할 수 있는 장치 메모리인가 |
| 크기 | 커널이 접근할 모든 원소가 할당에 포함되는가 |
| 인수 표현 | 커널이 기대하는 타입과 순서로 인수를 전달하는가 |
| 수명 | 마지막 장치 접근이 끝날 때까지 메모리가 유지되는가 |
| 동시 접근 | 다른 작업과 충돌하는 읽기·쓰기가 없는가 |

CUDA C++의 직접 호출 구문은 선언된 함수 매개 변수에 대한 타입 검사를 제공합니다. Driver API로 모듈의 함수를 찾아 인수를 구성하는 경우에는 프로그램이 별도로 맞춰야 할 부분이 더 많습니다. 어느 경로에서도 배열 전체의 접근 범위가 자동으로 증명되는 것은 아닙니다.

## 오류 확인 함수

전체 예제는 다음 보조 함수를 사용합니다.

```cpp
void Check(cudaError_t status)
{
    if (status != cudaSuccess)
    {
        throw std::runtime_error(cudaGetErrorString(status));
    }
}
```

이 함수는 CUDA의 상태 코드를 검사하고 실패 원인을 C++ 예외로 보고합니다. 예외가 발생하면 호스트 프로그램은 실패 경로로 이동합니다. 이때 이미 할당한 메모리와 만든 스트림도 정리되어야 하므로, 전체 소스는 소멸자를 가진 자원 래퍼를 사용합니다.

오류 문자열을 출력하는 것과 GPU 계산의 정답을 검증하는 것은 다릅니다. API가 성공해도 잘못된 인덱스에 유효한 값을 기록한 프로그램은 수치 결과가 틀릴 수 있습니다. 따라서 API 상태와 출력값을 각각 확인해야 합니다.

## 제출과 완료를 구분하여 검사

커널 제출 직후와 작업 완료 시점에 오류를 확인합니다.

```cpp
FillPattern<<<gridSize, blockSize>>>(deviceOutput, count);
Check(cudaGetLastError());
Check(cudaDeviceSynchronize());
```

첫 번째 검사는 잘못된 실행 구성처럼 즉시 확인할 수 있는 오류를 관찰합니다. 두 번째 검사는 앞선 장치 작업이 끝날 때까지 기다리며, 실행 중 발생한 오류를 보고할 수 있습니다. 특정 스트림만 기다려야 한다면 `cudaStreamSynchronize`를 사용할 수 있습니다.

CUDA API는 앞서 발생한 비동기 오류를 이후 호출에서 보고할 수도 있습니다. 따라서 오류가 반환된 함수 이름만 보고 문제가 반드시 그 함수에서 시작되었다고 판단하지 마세요. 개발 중에는 작업 경계를 좁혀 검사하면 원인이 되는 커널을 찾기 쉽습니다.

NVIDIA Runtime API의 [오류 처리 문서](https://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__ERROR.html)는 마지막 오류 조회와 오류 상태의 의미를 설명합니다. 실행 완료를 기다리는 API의 계약과 함께 읽어야 합니다.

## Direct3D와 드라이버 계층

CUDA 커널은 Direct3D 셰이더로 변환되어 실행되지 않습니다. CUDA와 Direct3D는 애플리케이션이 사용하는 API와 컴파일 경로가 다릅니다. 다만 같은 GPU를 사용하면 아래쪽의 장치 자원과 운영체제 관리 계층을 공유할 수 있습니다.

Windows의 WDDM 환경에서는 운영체제가 GPU 스케줄링과 비디오 메모리 관리에 참여합니다. Microsoft의 [WDDM 아키텍처 문서](https://learn.microsoft.com/ko-kr/windows-hardware/drivers/display/windows-vista-and-later-display-driver-model-architecture)는 사용자 모드 구성 요소, Dxgkrnl 및 제조사의 커널 모드 드라이버가 수행하는 역할을 설명합니다.

여기서 GPU 커널 함수와 커널 모드 드라이버의 “커널”은 다른 뜻입니다. 전자는 GPU에 제출하는 계산 함수이고, 후자는 운영체제의 커널 모드에서 동작하는 장치 드라이버입니다. PTX를 생성했다고 해서 운영체제의 메모리 관리나 장치 접근 경로를 우회하는 것은 아닙니다.

또한 WSL 2에서 CUDA를 사용하는 경우에는 일반 Linux의 드라이버 설치 경로와 구분해야 합니다. NVIDIA의 [CUDA on WSL 안내](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)는 Windows 호스트 드라이버를 사용하는 구성을 설명합니다. “Linux에서 실행했으므로 Windows GPU 관리 계층과 무관하다”는 결론을 WSL에 적용할 수는 없습니다.

## 다른 언어에서 같은 계약 표현

Rust의 일부 CUDA 래퍼는 커널 실행을 `unsafe` 함수로 제공합니다. 이는 다른 대상용으로 컴파일된 커널의 메모리 접근을 Rust 타입 검사기가 모두 확인할 수 없기 때문입니다.

C++에 같은 키워드가 없다고 해서 해당 조건이 없는 것은 아닙니다. 반대로 Rust에서 `unsafe` 블록을 작성했다고 조건이 충족되는 것도 아닙니다. 실제 근거는 올바른 할당 크기, 인수 구성, 경계 검사 및 완료 전 자원 유지입니다.

안전 조건을 확보한 다음에는 같은 계산의 메모리 접근 효율을 검토할 수 있습니다. 다음 문서에서는 스레드별 주소가 전역 메모리 요청으로 묶이는 방식을 설명합니다.

## 다음 단계

[시리즈 안내](/posts/cuda-출근길-시리즈/) · [이전 문서](/posts/cuda-출근길-07-전송-stream-동기화/) · [다음 문서](/posts/cuda-출근길-09-coalescing/)
