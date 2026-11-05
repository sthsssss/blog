---
title: "CUDA 출근길 07 — 전송, stream, 동기화"
description: "입력 복사, 커널 및 결과 복사의 순서를 스트림과 이벤트로 표현합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:07:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA의 배경, 실행 모델 및 애플리케이션 구성"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

스트림은 CUDA 작업의 실행 순서를 표현합니다. 같은 스트림에 제출한 작업은 그 순서에 따라 실행되지만, 호스트가 작업을 제출한 뒤 다음 명령으로 진행하는 시점과 GPU 작업이 완료되는 시점은 다를 수 있습니다.

이 문서에서는 입력 복사, 커널 실행 및 결과 복사를 하나의 처리 과정으로 구성합니다. 먼저 완료를 명확히 기다리는 경로를 설명하고, 그다음 여러 스트림을 사용할 때 추가로 필요한 관계를 살펴봅니다.

## 입력과 결과의 저장 위치

CPU에서 준비한 배열과 `cudaMalloc`으로 할당한 장치 배열은 별도의 저장 공간입니다. 입력을 GPU에서 사용하려면 이 예제에서는 호스트 배열의 내용을 장치 배열로 복사합니다. GPU가 계산한 결과를 CPU에서 검사할 때에는 반대 방향으로 복사합니다.

```text
호스트 입력 ──복사──▶ 장치 입력
                         │
                       커널
                         │
호스트 결과 ◀──복사── 장치 출력
```

여기서는 일반적인 명시적 장치 할당을 사용합니다. CUDA가 제공하는 관리형 메모리나 호스트 메모리 매핑을 사용하면 접근 방식이 달라질 수 있습니다. 그런 기능을 사용하더라도 물리적 데이터 이동과 실행 순서를 고려할 필요가 사라지는 것은 아닙니다.

## 하나의 스트림으로 순서 표현

다음 코드는 유한한 실수 배열에 ReLU를 적용하는 경로입니다. ReLU는 음수를 0으로 바꾸고 나머지는 유지하는 함수입니다. `hostInput`과 `hostOutput`은 `cudaMallocHost`로 할당한 페이지 고정 메모리이며, 장치 버퍼도 미리 할당되어 있다고 가정합니다.

```cpp
Check(cudaMemcpyAsync(
    deviceInput, hostInput, bytes,
    cudaMemcpyHostToDevice, stream));

Relu<<<gridSize, blockSize, 0, stream>>>(
    deviceInput, deviceOutput, count);
Check(cudaGetLastError());

Check(cudaMemcpyAsync(
    hostOutput, deviceOutput, bytes,
    cudaMemcpyDeviceToHost, stream));

Check(cudaStreamSynchronize(stream));
```

세 작업은 같은 `stream`에 제출됩니다. 입력 복사가 완료된 뒤 커널이 입력을 사용하고, 커널의 출력이 준비된 뒤 결과 복사가 그 값을 읽습니다. 호스트가 각 작업 사이에서 별도로 대기할 필요는 없습니다.

마지막의 `cudaStreamSynchronize`가 성공하면 그 스트림에 앞서 제출한 작업들이 완료된 상태입니다. 따라서 그 이후에 호스트가 결과 배열을 읽거나 입력·출력 버퍼를 재사용할 수 있습니다.

다음은 커널 본문입니다.

```cpp
__global__ void Relu(
    const float* input,
    float* output,
    unsigned int count)
{
    unsigned int index =
        blockIdx.x * blockDim.x + threadIdx.x;

    if (index < count)
    {
        output[index] = fmaxf(input[index], 0.0f);
    }
}
```

입력이 `[-2, 0, 3]`이면 결과는 `[0, 0, 3]`입니다. 각 스레드가 한 원소만 읽고 쓰므로 커널 내부에 배리어가 필요하지 않습니다. 입력 전송과 결과 전송의 순서는 스트림이 표현합니다.

## 비동기 API와 실제 겹침

비동기 호출은 호스트가 완료를 기다리지 않고 진행할 수 있도록 하는 인터페이스입니다. 이름에 `Async`가 있다고 해서 모든 호출이 어떤 조건에서도 즉시 반환하거나, 다른 작업과 반드시 겹쳐 실행되는 것은 아닙니다.

호스트 메모리의 종류는 중요한 조건입니다. 페이지 고정 메모리는 운영체제가 해당 메모리를 임의로 페이징하지 않도록 관리한 메모리입니다. 호스트와 장치 사이의 비동기 전송 및 계산과의 겹침을 설계할 때 사용합니다. 일반 페이지 가능 메모리는 내부 준비나 동기화가 필요할 수 있습니다.

또한 같은 스트림의 작업은 앞 작업과 순서가 있으므로, 서로 의존하는 입력 복사와 해당 커널을 단순히 동시에 수행할 수는 없습니다. 겹침을 활용하려면 서로 독립적인 작업이나 다른 입력 묶음이 필요합니다.

NVIDIA Runtime API의 [동기화 동작 설명](https://docs.nvidia.com/cuda/cuda-runtime-api/api-sync-behavior.html)은 전송 방향과 메모리 종류에 따른 조건을 구분합니다. 이 조건을 확인하지 않고 API 이름만으로 실행 시간을 해석하지 마세요.

## 여러 스트림 사이의 의존성

스트림을 두 개 만들었다고 해서 한 스트림이 다른 스트림의 완료를 자동으로 기다리지는 않습니다. 예를 들어 스트림 A가 만든 결과를 스트림 B에서 읽으려면 그 관계를 표현해야 합니다.

```cpp
Check(cudaEventRecord(ready, streamA));
Check(cudaStreamWaitEvent(streamB, ready, 0));
```

`ready` 이벤트는 스트림 A에서 그 앞의 작업이 완료되는 지점을 나타냅니다. 스트림 B의 대기는 이후 작업이 그 지점을 통과하기 전에 시작하지 않도록 합니다. 호스트 전체를 멈추는 대신 장치 작업 사이의 관계를 표현할 수 있습니다.

일부 기본 스트림 모드에는 추가적인 암묵적 동기화 규칙이 있습니다. 예제는 이러한 차이에 의존하지 않도록 명시적으로 만든 스트림을 사용합니다.

다음 문서에서는 실행 순서가 맞더라도 잘못된 주소나 실행 설정으로 오류가 발생하는 경우를 설명합니다. 특히 제출 오류와 비동기 실행 오류를 어디에서 확인해야 하는지 구분합니다.

## 다음 단계

[시리즈 안내](/posts/cuda-출근길-시리즈/) · [이전 문서](/posts/cuda-출근길-06-gpu-메모리-공간/) · [다음 문서](/posts/cuda-출근길-08-unsafe와-오류-경계/)
