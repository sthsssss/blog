---
title: "C++ 출근길 부록 — 예제와 어셈블리 검증"
description: "Clang과 GCC의 실행 결과, 복사 생략 비교, LLVM IR과 어셈블리, CUDA 검증 기록과 재현 코드입니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:50+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

본문은 C++20으로 작성했습니다. CPU 실행은 Clang 18.1.3과 GCC 13.3.0, 기계어와 LLVM 패스 관찰은 Clang/LLVM 18.1.3을 사용했습니다. 실행 환경은 x86-64 Linux(WSL)이며 CPU 어셈블리는 Intel 문법입니다. 이 조건의 관찰 결과와 다른 플랫폼에서도 지켜야 하는 언어 규칙을 본문에서 구별했습니다.

**실행과 진단**

새 실행 예제 12개를 각 CPU 컴파일러에서 `-O2 -Wall -Wextra -Wpedantic`으로 빌드하고 실행했습니다. 총 24회 모두 종료 코드 0이며 원본·사본·참조 대상과 관찰된 값을 검사했습니다. 9편의 의도적으로 무효가 된 참조를 만드는 선언에는 GCC가 댕글링 경고를 냈습니다. 그 참조의 대상에 접근하지 않고 생성·소멸 개수로 수명만 확인했습니다.

const 위반, lvalue·rvalue 참조의 잘못된 바인딩, const 원본의 수정 가능 참조 반환, unique_ptr 복사 등 15개 사례는 두 컴파일러에서 각각 오류를 확인했습니다. 총 30개 진단을 보관했습니다. 지역 객체의 참조 반환과 NRVO를 방해하는 `return std::move(local)`는 별도의 경고 사례로 확인했습니다. 잘못된 지역 참조는 사용하지 않았습니다.

13편의 CUDA 코드는 CUDA 12.6(nvcc 12.6.85), GTX 1070(compute capability 6.1), 드라이버 560.94에서 빌드·실행했습니다. 세 원소 모두 CPU 기준값과 일치했고 소유권 이동 후 주소와 빈 상태를 확인했습니다. 이번 예제의 Compute Sanitizer 검사는 수행하지 않았습니다.

**반환 생성 횟수**

11편은 복사·이동 생성자에서 카운터를 증가시키는 타입을 사용합니다. 두 컴파일러에서 각각 `-O0`, `-O2`, 각 옵션에 `-fno-elide-constructors`를 추가한 경우를 실행하여 8회 비교했습니다.

기본 옵션의 결과는 다음과 같았습니다.

```text
direct: copies=0, moves=0
named: copies=0, moves=0
parameter: copies=1, moves=1
```

선택적 생략을 제한한 경우는 다음과 같았습니다.

```text
direct: copies=0, moves=0
named: copies=0, moves=1
parameter: copies=1, moves=1
```

복사·이동 생성자를 삭제한 별도 타입도 prvalue 직접 반환과 초기화에 성공했습니다. 이때에도 `-fno-elide-constructors`를 사용했습니다. 특정 컴파일러의 NRVO 관찰을 모든 구현에 대한 의무로 해석하지 않습니다.

**LLVM과 실제 명령**

프런트엔드 IR은 `-O1 -Xclang -disable-llvm-passes -S -emit-llvm`으로 얻었습니다. 여기에 `opt -passes=mem2reg`와 `opt -passes=sroa`를 각각 적용했습니다. 지역 참조는 mem2reg로, 지역 참조 멤버 객체는 SROA로 저장 공간이 제거됐습니다. 실행 중 참조 대상을 선택한 객체도 SROA로 제거됐고, 본문이 없는 외부 함수에 객체 주소를 제공하는 예제는 저장 공간이 남았습니다.

Clang의 실제 `-O2` 컴파일에서도 SROA 적용 전후를 출력해 같은 제거를 확인했습니다. `-O0`과 `-O2` 어셈블리, raw·최적화 IR을 함께 보관했습니다. 본문의 어셈블리 블록은 함수의 명령을 발췌한 것이며 CFI·정렬·심볼 장식은 생략할 수 있습니다. 추측으로 만든 어셈블리를 실행 결과처럼 제시하지 않았습니다.

파일은 [원본 C++](/downloads/cpp-commute/machine_cases.cpp), [최적화 전 IR](/downloads/cpp-commute/artifacts/raw.ll), [mem2reg 결과](/downloads/cpp-commute/artifacts/mem2reg.ll), [SROA 결과](/downloads/cpp-commute/artifacts/sroa.ll), [최적화 IR](/downloads/cpp-commute/artifacts/optimized.ll), [패스 전후 기록](/downloads/cpp-commute/artifacts/clang_sroa_trace.txt), [O0 어셈블리](/downloads/cpp-commute/artifacts/unoptimized.s), [O2 어셈블리](/downloads/cpp-commute/artifacts/optimized.s)입니다.

CUDA 컴파일러가 생성한 [PTX 원문](/downloads/cpp-commute/artifacts/gpu_buffer.ptx)도 보관했습니다. PTX는 NVIDIA의 가상 명령어 중간 표현이며 GPU에서 실행되는 최종 기계어 자체와는 구별합니다.

**재현과 기록**

검증 스크립트는 [verify.py](/downloads/cpp-commute/verify.py), 실행 출력·진단·소스 해시는 [verification.json](/downloads/cpp-commute/artifacts/verification.json)에 있습니다. 짧은 본문 코드에서 생략한 헤더와 주변 선언은 전체 실행 소스에 있습니다.

Clang/LLVM과 CUDA가 준비된 환경에서 이 노트 폴더를 기준으로 실행합니다. `--clang`과 `--opt`에는 서로 맞는 버전의 실행 파일을 지정할 수 있습니다.

```bash
python3 examples/commute/verify.py --clang clang++-18 --opt opt-18
```

이 기록은 작성한 참고 예제의 검증 범위입니다. 독자의 이해도나 독립적인 구현 성취를 의미하지 않습니다.

전체 순서: [00 - 시리즈 안내](/posts/c-출근길-시리즈/).

공개 다운로드의 IR·진단에서는 로컬 빌드 경로를 상대 표기로 정리했습니다. 소스 코드의 내용과 명령·출력은 유지했습니다.
