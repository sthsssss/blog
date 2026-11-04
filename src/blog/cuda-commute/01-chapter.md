---
title: "CUDA 출근길 01 — PTX에서 시작하는 GPU의 역사"
description: "고정 기능 그래픽 장치에서 CUDA까지의 역사와 Rust kernel이 PTX를 거쳐 GTX 1070에서 실행되는 경로를 연결합니다."
author: "Tae Shim"
pubDate: 2026-11-04T08:01:00+09:00
image:
  url: "/images/cuda-commute-series.svg"
  alt: "CUDA 출근길: 한 스레드의 인덱스에서 Rust GPU 추론까지"
tags: ["cuda", "rust", "gpu", "ptx", "cuda-commute"]
---

터미널에서 `cargo run --features cuda --bin cuda-probe`를 실행하면 Rust 함수 `probe_pattern`이 GTX 1070에서 동작합니다. 이 한 문장에는 중요한 중간 단계가 빠져 있습니다. CPU용 Rust 실행 파일과 GPU용 Rust kernel은 서로 다른 processor에서 실행되며, GPU kernel은 **PTX**라는 중간 표현을 거칩니다.

먼저 전체 경로를 놓고 시작하겠습니다.

```text
GPU용 Rust source
    ↓ rustc + LLVM NVPTX backend
PTX module
    ↓ NVIDIA driver의 적재와 변환
GPU 세대에 맞는 machine code
    ↓ kernel launch
GTX 1070의 thread들이 실행
```

PTX는 NVIDIA GPU가 그대로 읽어 실행하는 물리적 기계어가 아닙니다. **Parallel Thread Execution virtual ISA**, 즉 CUDA 계산 모델을 표현하는 가상 명령어 집합입니다. 실제 chip의 명령어는 GPU 세대에 따라 달라질 수 있고 흔히 SASS라고 부릅니다. PTX를 함께 배포하면 driver가 설치된 GPU에 맞는 code로 JIT compile할 수 있습니다. NVIDIA의 [PTX 설명](https://developer.nvidia.com/blog/understanding-ptx-the-assembly-language-of-cuda-gpu-computing/)과 [PTX ISA 문서](https://docs.nvidia.com/cuda/parallel-thread-execution/)가 “virtual machine ISA”라는 표현을 쓰는 이유입니다.

이 중간층은 왜 필요했을까요. 답은 GPU의 출발점에 있습니다.

## 그래픽 가속기에서 programmable GPU로

초기의 그래픽 가속기는 화면에 삼각형과 pixel을 그리는 정해진 단계를 빠르게 처리했습니다. CPU처럼 임의의 프로그램을 넣는 장치라기보다 rendering pipeline의 일부 기능을 하드웨어로 가속하는 장치에 가까웠습니다. shader가 programmable해지면서 개발자는 vertex와 pixel을 처리하는 작은 프로그램을 작성할 수 있게 되었습니다.

연구자들은 이 계산 능력을 그래픽 밖에도 사용했습니다. 그러나 CUDA 이전의 GPGPU에서는 계산할 배열을 texture로 보이게 만들고, 계산 결과를 pixel 출력처럼 받는 방식이 흔했습니다. 계산 문제가 그래픽 문제인 것처럼 번역되어야 했습니다. NVIDIA가 2004년에 펴낸 *GPU Gems*의 [서문](https://developer.nvidia.com/gpugems/gpugems/foreword)은 이 시기를 고정 기능의 graphics accelerator에서 programmable GPU로 넘어가는 과정으로 기록합니다.

2006년 11월 공개된 G80 기반 GeForce 8800은 vertex와 pixel용 처리기를 따로 두던 이전 구조에서 벗어나, 여러 종류의 shader 작업을 같은 unified processor에 배정했습니다. NVIDIA의 [GTX 200 기술 문서](https://www.nvidia.com/docs/io/55506/geforce_gtx_200_gpu_technical_brief.pdf)는 이 unified shader architecture가 CUDA 계산의 기반이 되었다고 설명합니다. 같은 해 공개된 CUDA는 graphics pipeline을 흉내 내지 않고 thread, address, synchronization이라는 계산 언어로 GPU를 다루게 했습니다.

여기서 역사와 programming model이 만납니다. GPU는 많은 pixel과 vertex에 비슷한 계산을 적용하도록 발전했기 때문에, 소수의 복잡한 thread보다 수많은 비교적 가벼운 thread를 처리하는 구조에 강합니다. CUDA는 이 성질을 `grid → block → thread`라는 형태로 개발자에게 노출했습니다. PTX는 그 thread model과 명령을 특정 GPU 한 세대에 고정하지 않고 표현하는 층입니다.

## Rust kernel은 어디까지 Rust인가

mini-infer의 kernel은 다음처럼 Rust로 작성합니다.

```rust
#![no_std]
#![feature(abi_ptx, stdarch_nvptx)]

#[unsafe(no_mangle)]
pub unsafe extern "ptx-kernel" fn probe_pattern(
    out: *mut u32,
    count: u32,
) {
    // 각 GPU thread가 실행할 본문
}
```

`extern "ptx-kernel"`은 GPU kernel 진입점에 맞는 calling convention을 지정합니다. `no_std`는 운영체제와 일반 Rust 표준 라이브러리가 있는 CPU 프로그램을 전제로 하지 않는다는 뜻입니다. 이 코드는 Rust이지만 CPU용 `main`과 같은 target으로 compile되지 않습니다. 고정된 nightly compiler가 NVPTX target을 향해 PTX를 생성합니다.

PTX를 직접 작성하지 않는다고 PTX가 중요하지 않은 것은 아닙니다. compile error를 읽을 때에는 Rust source와 NVPTX target의 제약을 알아야 하고, module load가 실패할 때에는 PTX version과 driver 지원 범위를 확인해야 합니다. 반대로 PTX가 생성되었다는 사실만으로 GPU 실행이 검증된 것도 아닙니다. driver가 module을 적재하고 kernel을 실제 장치에서 완료해야 합니다.

## PTX module을 실제 GPU 작업으로 연결하기

CUDA 프로그램의 실행 진입점은 CPU입니다. CPU에서 실행되는 **host code**가 GPU를 선택하고, PTX module과 device memory를 준비하고, thread 배치를 정해 kernel을 제출합니다. GPU에서 실행되는 **device code**는 전달받은 주소와 값으로 계산합니다. 양쪽을 모두 Rust로 작성해도 실행 주체와 compile target은 합쳐지지 않습니다.

mini-infer의 probe 진입점은 다음 순서를 사용합니다.

```rust
let context = CudaContext::new(0)?;
let stream = context.default_stream();
let module = context.load_module(Ptx::from_src(include_str!(...)))?;
let kernel = module.load_function("probe_pattern")?;
let mut output = stream.alloc_zeros::<u32>(257)?;
```

`CudaContext`는 선택한 GPU와 driver 작업의 문맥입니다. module은 PTX를 현재 GPU에서 사용할 수 있도록 driver에 적재한 결과이며, `kernel`은 그 module 안의 진입점을 가리킵니다. 이 적재 과정에서 driver는 필요한 경우 PTX를 실제 GPU 명령으로 JIT compile합니다. `output`은 host의 `Vec<u32>`가 아니라 device memory 할당을 관리하는 값입니다.

이 객체들은 host에 존재합니다. `output` 객체가 device memory의 257개 원소를 CPU memory 안에 포함하는 것은 아닙니다. 객체는 장치 할당의 address·length·lifetime 관리 정보를 가지고 있고, 실제 원소는 GPU가 접근할 수 있는 memory에 있습니다.

NVIDIA의 [CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/intro-to-cuda-cpp.html)는 host가 kernel을 launch하면 grid의 여러 thread가 device에서 kernel 본문을 실행하는 모델을 설명합니다. Rust와 cudarc는 그 driver API 경로를 사용하지만 context·module·stream·device memory라는 CUDA 개념 자체가 사라지는 것은 아닙니다.

따라서 `cargo run` 하나가 가리는 층을 세 가지로 나누어 읽어야 합니다.

1. Cargo와 `build.rs`가 host binary와 GPU PTX라는 서로 다른 산출물을 준비합니다.
2. host binary가 CUDA driver를 통해 context, module, device allocation을 만듭니다.
3. launch 이후 GPU thread들이 kernel을 실행하고, host는 synchronization 지점에서 완료와 오류를 관찰합니다.

PTX는 1번과 2번 사이의 계약입니다. CUDA는 2번과 3번을 표현하는 programming model과 API의 묶음입니다. GPU는 그 계약의 최종 실행 장치입니다. 이 셋을 모두 “CUDA code”라고만 부르면 어느 단계에서 문제가 났는지 구분하기 어렵습니다.

다음 편에서는 여러 thread가 같은 kernel 본문을 실행하면서 서로 다른 출력 원소를 고르는 방법을 살펴봅니다. 이것이 그래픽 시대의 “많은 대상에 같은 프로그램을 적용한다”는 구조가 일반 배열 계산으로 바뀌는 첫 지점입니다.

이전: [시리즈 안내](/posts/cuda-출근길-시리즈/). 다음: [02 - kernel과 thread index](/posts/cuda-출근길-02-kernel과-thread-index/).
