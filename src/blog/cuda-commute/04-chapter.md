---
title: "CUDA 출근길 04 — 컴파일러에서 PTX와 GPU 기계어까지"
slug: "cuda-출근길-04-grid-block-warp"
description: "CPU와 GPU의 두 컴파일 경로, nvcc·ptxas·링커, PTX·cubin·fatbinary와 드라이버 JIT를 구분합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:04:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "프로그램의 표현, CUDA 소프트웨어, GPU 하드웨어의 관계"
tags: ["cuda", "cpp", "gpu", "cuda-commute"]
---

CUDA C++ 소스에는 CPU에서 실행할 코드와 GPU에서 실행할 코드가 함께 들어갈 수 있습니다. 두 코드는 서로 다른 프로세서의 명령어가 되어야 합니다. 따라서 CUDA 프로그램의 컴파일을 이해하려면 “소스 파일 하나”와 “실행 대상 하나”를 구분해야 합니다.

앞 문서의 `Add` 함수는 장치용 코드입니다. 반면 배열을 준비하고 커널을 제출하는 `main`과 호스트 함수들은 CPU용 코드입니다. GPU가 호스트의 `main`을 실행하거나 CPU가 GPU의 덧셈 명령어를 해석하는 구조가 아닙니다.

## nvcc는 컴파일 과정을 조정한다

`nvcc`는 CUDA 컴파일러 드라이버입니다. 여기서 드라이버는 장치 드라이버가 아니라 여러 컴파일 단계와 도구를 호출하는 조정 프로그램이라는 뜻입니다. 호스트 코드는 지원되는 C++ 컴파일러로 처리하고, 장치 코드는 GPU용 컴파일 경로로 처리합니다.

```text
CUDA C++ 소스
 ├─ 호스트 코드 ── 호스트 C++ 컴파일러 ── CPU 오브젝트 ── 링크 ── 실행 파일
 └─ 장치 코드 ── GPU 컴파일 단계 ── PTX
                                  ├─ ptxas ── cubin ─┐
                                  └─ PTX 보관 ───────┴─ fatbinary로 포함
```

이것은 대표 경로를 나타낸 그림입니다. 분리 컴파일, 장치 링크, LTO를 사용하면 단계가 추가되거나 중간 표현이 달라집니다. 내부 임시 파일명보다 각 단계의 입력과 출력 계약을 먼저 이해하는 것이 중요합니다. NVIDIA의 [nvcc 문서](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-compiler-driver-nvcc/index.html)는 지원되는 컴파일 단계와 옵션을 구분합니다.

## PTX는 물리 GPU의 최종 명령어가 아니다

PTX는 가상 명령어 집합입니다. 레지스터와 메모리 연산, 스레드 인덱스 같은 장치 실행 개념을 표현하지만 특정 칩의 실제 실행 인코딩은 아닙니다. CPU에서 x86-64 오브젝트를 직접 실행하는 경우와 비교하면 GPU 실행 전 변환 가능한 계층이 하나 더 있는 셈입니다.

`Add`에서 사용하는 인덱스는 PTX의 특수 레지스터 읽기와 정수 계산으로 표현할 수 있습니다. 배열을 읽고 더하고 기록하는 동작도 장치 메모리 로드·산술·스토어 명령으로 나타납니다. 여기서 PTX의 가상 레지스터 개수와 SM에 실제로 배정되는 물리 레지스터 개수는 같지 않습니다.

`ptxas`는 이름에 assembler가 들어 있지만 단순한 문자 대체만 수행하지 않습니다. 대상 GPU에 맞는 코드 생성·최적화·레지스터 배정 등을 거쳐 실제 기계 코드를 만듭니다. 이 코드를 담는 ELF 형식의 장치 바이너리가 cubin입니다. 실제 명령어의 디스어셈블 표기는 흔히 SASS라고 부릅니다.

PTX의 명세는 [PTX ISA 문서](https://docs.nvidia.com/cuda/archive/12.6.0/parallel-thread-execution/index.html)에 있습니다. PTX를 읽으면 소스가 어떤 병렬 연산으로 표현되었는지 확인할 수 있지만, 실제 스케줄링과 자원 사용을 판단하려면 최종 코드도 봐야 합니다.

## 실행 파일에 무엇을 넣는가

fatbinary는 여러 장치 코드 이미지를 담는 컨테이너입니다. 서로 다른 GPU 대상의 cubin과, 나중에 컴파일할 PTX를 함께 넣을 수 있습니다. 모든 실행 파일이 항상 둘을 모두 포함하는 것은 아니며 빌드 옵션에 따라 달라집니다.

실행 시 호환되는 cubin이 있으면 그 코드를 사용할 수 있습니다. 적절한 바이너리가 없고 지원 가능한 PTX가 있으면 드라이버의 JIT 컴파일 경로가 사용될 수 있습니다. GPU가 PTX 텍스트를 한 줄씩 해석하며 실행하는 것은 아닙니다.

이 경로는 호환성의 범위를 넓히지만 무제한 호환성을 보장하지 않습니다. 드라이버가 PTX 버전을 이해해야 하고, 장치가 필요한 기능을 지원해야 합니다. GPU 드라이버 버전, Toolkit 버전, PTX 버전, compute capability를 하나의 “CUDA 버전”으로 취급하면 원인을 구별하기 어렵습니다.

## 산출물을 직접 확인하기

예제 파일을 내려받은 디렉터리에서 다음 명령을 실행할 수 있습니다. 이 명령은 CUDA Toolkit 12.6의 Pascal 대상 예입니다.

```bash
nvcc -std=c++17 -O2 -arch=compute_61 --ptx examples.cu -o examples.ptx
nvcc -std=c++17 -O2 -arch=sm_61 --cubin examples.cu -o examples.cubin
cuobjdump --dump-sass examples.cubin

nvcc -std=c++17 -O2   -gencode arch=compute_61,code=sm_61   -gencode arch=compute_61,code=compute_61   examples.cu -o cuda-examples

cuobjdump --list-elf cuda-examples
cuobjdump --dump-ptx cuda-examples
```

첫 명령의 결과는 장치용 PTX입니다. 두 번째 결과는 장치용 바이너리이며 CPU에서 실행할 `main`이 있는 독립 실행 파일이 아닙니다. 마지막 빌드는 CPU 실행 파일에 지정한 GPU 바이너리와 PTX를 함께 포함합니다. `compute_61`은 가상 대상, `sm_61`은 실제 코드 생성 대상을 나타냅니다.

이 예제의 장치는 오래된 세대이므로 최신 Toolkit이 같은 대상을 지원한다고 가정하지 않습니다. 실제 확인한 도구와 결과는 검증 부록에 기록합니다. 산출물 도구의 역할은 NVIDIA의 [CUDA Binary Utilities](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-binary-utilities/index.html)에서 확인할 수 있습니다.

## 같은 덧셈을 두 표현으로 확인하기

검증 환경에서 생성한 PTX의 덧셈 부분은 다음과 같습니다. 앞에서 주소와 인덱스를 계산하는 명령들은 생략했습니다.

```text
ld.global.f32  %f1, [%rd8];
ld.global.f32  %f2, [%rd6];
add.f32        %f3, %f2, %f1;
st.global.f32  [%rd10], %f3;
```

입력 두 개를 가상 레지스터로 읽고 더한 뒤 전역 주소에 저장합니다. 같은 커널의 `sm_61` 디스어셈블에서는 `LDG.E`, `FADD`, `STG.E`를 확인했습니다. 실제 레지스터는 `R0` 같은 이름으로 표시됩니다. 소스의 한 줄이 주소 계산과 경계 검사를 포함한 여러 명령으로 내려가는 과정입니다.

두 출력의 명령어 수나 레지스터 이름이 같을 필요는 없습니다. PTX는 병렬 계산의 중간 표현이고, 최종 코드는 대상 GPU에서 실행할 형태라는 구분이 여기에서 드러납니다.

## 소스 언어가 달라져도 남는 경계

다른 언어의 컴파일러가 PTX를 생성하더라도 GPU 쪽의 실행·메모리 계약은 남습니다. CUDA C++은 CUDA를 사용하는 대표적인 언어 확장이지만 CUDA 플랫폼 자체와 동일한 대상은 아닙니다. 라이브러리를 통해 이미 컴파일된 GPU 코드를 호출하는 애플리케이션도 있습니다.

소스와 실행 파일 사이의 관계는 이제 설명할 수 있습니다. 다음 단계는 CPU 프로세스가 시작된 뒤 이 코드를 어떤 컨텍스트에 적재하고 어떤 API로 실행시키는지입니다.

---

이전: [03 — 스레드 모델과 하드웨어의 대응](/posts/cuda-출근길-03-launch-크기와-경계-검사/) · [시리즈](/posts/cuda-출근길-시리즈/) · 다음: [05 — main에서 커널 실행까지의 CUDA 소프트웨어 구조](/posts/cuda-출근길-05-simt와-분기/)
