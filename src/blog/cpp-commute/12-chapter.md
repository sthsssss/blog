---
title: "C++ 출근길 12 — Clang에서 참조가 사라지는 과정"
description: "IR·SROA·mem2reg·인라이닝·주소의 외부 전달. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:52+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편에서는 중간 객체를 처음부터 요구하지 않는 직접 생성과 NRVO를 보았습니다. 이번에는 소스의 지역 객체를 표현하기 위해 만든 메모리 연산이 일반 최적화로 사라지는 과정을 살펴봅니다. 1편과 3편에서 보았던 “객체나 참조 이름은 있지만 스택 공간이 없는 함수”로 돌아오는 것입니다.

Clang은 C++를 분석해 LLVM IR이라는 중간 표현을 만들고, LLVM은 이 표현을 최적화한 뒤 기계어를 생성합니다. IR에는 C++의 `int&`라는 별도 타입을 그대로 유지하지 않고 이 사례의 참조를 포인터 값과 관련 속성으로 표현합니다.

**지역 참조와 참조 멤버를 같은 계산으로 줄일 수 있습니다.**

```cpp
struct IntView { int& value; };
int member_reference(int x) {
    IntView view{x};
    return view.value + 1;
}
```

주소 관계를 간단히 보기 위해 이번 편에서는 두 필드의 `Gradient` 대신 정수 하나를 참조하는 `IntView`를 사용합니다. 먼저 `-O1 -Xclang -disable-llvm-passes`로 LLVM 최적화 패스를 끄고 프런트엔드가 만든 IR을 관찰했습니다. 중요한 작업은 다음과 같습니다.

```text
x를 저장할 공간 생성
view를 저장할 공간 생성
view.value에 x의 주소 저장
그 주소를 다시 읽음
읽은 주소에서 정수를 읽고 1을 더함
```

IR에서 `alloca`는 지역 저장 공간을 만들고, `store`는 메모리에 쓰며 `load`는 읽습니다. `getelementptr`는 구조체 안의 필드 주소를 계산합니다. 주소를 계산하는 연산 자체가 필드 값을 읽는 것은 아닙니다.

Clang의 실제 SROA 적용 전후를 기록하니, 적용 후에는 다음만 남았습니다.

```llvm
%add = add nsw i32 %x, 1
ret i32 %add
```

`%x`는 함수에 전달된 정수 값입니다. `add`는 덧셈, `ret`는 결과 반환이며 `nsw`는 부호 있는 정수 오버플로가 정상 실행에 포함되지 않는다는 속성입니다. 이 C++ 함수의 일반 정수 덧셈 규칙에서 나온 속성입니다. 지역 메모리 생성과 주소 저장·읽기는 모두 없어졌습니다. 최종 기계어는 `lea eax, [rdi + 1]`과 `ret`였습니다.

**SROA는 구조체를 개별 값으로 다룰 수 있는지 분석합니다.**

SROA는 Scalar Replacement of Aggregates의 약자입니다. LLVM 프로젝트의 공식 패스 문서에서는 구조체·배열의 지역 저장 공간을 분석하고, 가능한 부분을 개별 값의 SSA 표현으로 바꾼다고 설명하고 있습니다. SSA는 중간 계산 결과에 이름을 붙여 직접 연결하는 표현 방식입니다. 물리적인 CPU 레지스터 배치를 이미 정했다는 뜻은 아닙니다. [LLVM: SROA](https://llvm.org/docs/Passes.html#sroa-scalar-replacement-of-aggregates)

이 함수에서는 참조 멤버에 주소를 넣은 뒤, 외부 코드가 그 저장 내용을 변경하거나 읽을 기회 없이 같은 필드를 읽습니다. 컴파일러는 읽은 주소를 처음 넣었던 `x`의 주소로 대체할 수 있습니다. 그 뒤 정수 읽기도 인수 `%x`를 직접 쓰는 것으로 바꿀 수 있으므로 별도 `view`가 필요하지 않습니다.

단순한 `int& r = x; return r + 1;`은 mem2reg만 적용해도 제거됐습니다. mem2reg는 직접적인 읽기·쓰기로 사용되는 지역 저장 공간을 SSA 값으로 바꾸는 패스입니다. 반면 위 구조체는 mem2reg만으로 남았고 SROA로 제거됐습니다. 이 차이를 실제 IR 파일에 함께 남겼습니다. [LLVM: mem2reg의 적용 조건](https://llvm.org/docs/tutorial/MyFirstLanguageFrontend/LangImpl07.html#memory-in-llvm)

**참조 대상을 실행 전에 확정해야 하는 것은 아닙니다.**

```cpp
int dynamic_reference(bool choose_a, int& a, int& b) {
    IntView view{choose_a ? a : b};
    return view.value;
}
```

컴파일러는 조건 값이나 두 주소의 숫자를 미리 알지 못합니다. 그래도 “조건에 따라 선택한 주소”라는 값을 IR에서 표현할 수 있습니다. 그 주소를 메모리의 `view`에 써 넣었다가 다시 읽는 단계가 필요하지 않은 것입니다. SROA 직후에는 분기에서 선택된 주소가 SSA 값으로 남았습니다.

최종 기계어에서는 첫 인수 `edi`로 조건을 검사하고 두 번째·세 번째 인수인 `rsi`, `rdx` 중 주소를 선택했습니다.

```asm
test edi, edi
cmove rsi, rdx
mov eax, dword ptr [rsi]
ret
```

`cmove`는 조건이 맞으면 레지스터 값을 교체하는 명령입니다. 여기서는 조건이 false이면 `b`의 주소를 선택합니다. 참조 연결 정보는 실행 중에도 필요하지만 레지스터로 유지됩니다. 원본 정수의 메모리 읽기는 남고 참조 멤버의 메모리 저장은 사라졌습니다.

**외부 코드가 객체 메모리를 읽어야 하면 그 배치를 제공합니다.**

```cpp
void observe(const IntView&); // 이 파일에서 본문을 모름
void materialize_for_call(int& x) {
    IntView view{x};
    observe(view);
}
```

이 호출은 기존 ABI에 따라 `IntView` 객체의 주소를 전달해야 합니다. 호출받은 함수는 그 주소에서 참조 멤버를 읽을 수 있어야 하므로 현재 컴파일러는 실제 저장 공간을 만들었습니다.

```asm
push rax
mov qword ptr [rsp], rdi
mov rdi, rsp
call observe@PLT
pop rax
ret
```

`rsp`는 스택 위치를 나타냅니다. 여기서 `push`와 `pop`은 8바이트 공간의 확보·해제에 사용되고, 그 사이 `mov [rsp], rdi`가 원본 주소를 기록합니다. 다음 명령은 이 `View` 저장 공간의 주소를 함수 인수로 준비합니다. 함수 밖에서 주소를 영구 보관해야만 생기는 현상은 아닙니다. 이번 호출 중 객체를 읽을 수 있게 하는 것만으로도 공간이 필요했습니다.

반대로 함수 본문을 알고 인라이닝하면 호출 대신 연산을 가져와 분석할 수 있습니다. `return read_existing(view) + 1;`에서 `read_existing`의 본문이 `return view.value;`라면 이번 Clang은 호출을 인라인한 뒤 `x + 1`만 남겼습니다. 별도로 생성된 `read_existing(const IntView&)`의 본문에는 기존 객체에서 주소를 읽고 원본 정수를 읽는 두 접근이 남았습니다. 호출 지점에서 함수 본문을 볼 수 있는지에 따라 분석할 수 있는 정보가 다릅니다.

그 두 접근을 주소 예시로 확인하겠습니다. `read_existing`에 전달된 `rdi`가 `0x1000`이고, 그곳의 참조 멤버에 원본 정수의 주소 `0x2000`이 저장되어 있다고 가정합니다. 원본 정수 값은 42입니다.

```asm
mov rax, qword ptr [rdi] ; 0x1000에서 원본 주소 0x2000을 읽음
mov eax, dword ptr [rax] ; 0x2000에서 정수 42를 읽음
ret
```

함수는 `int`를 반환하므로 반환값은 주소 `0x2000`이 아니라 정수 42입니다. 매개변수 `const IntView& view`의 연결 정보는 처음부터 `rdi`에 있으므로, 그 매개변수를 위한 별도 메모리는 필요하지 않습니다. 메모리에 있는 것은 호출자가 제공한 `IntView` 객체의 참조 멤버입니다. 함수 매개변수를 보관하는 위치와, 그 매개변수로 찾아간 객체의 내부 배치를 구별하면 두 설명이 동시에 성립합니다.

`IntView`를 값으로 받는 작은 함수도 확인했습니다. 이 ABI에서는 구조체 내용을 이루는 주소 하나가 레지스터로 전달되어, 함수는 바로 원본 정수를 읽었습니다. 참조 멤버가 있다는 사실이나 `sizeof(IntView) == 8`이라는 배치 크기만으로 매 호출에 8바이트 스택 공간이 있다고 판단할 수 없습니다.

최적화 후에도 레지스터가 부족하면 값을 잠시 스택에 저장하는 spill이 생길 수 있습니다. 이는 소스의 참조 멤버를 위해 객체 배치를 유지하는 이유와 다릅니다. 포인터로 같은 코드를 작성해도 이 예제에서는 동일한 제거가 일어났으며, const 참조라고 모든 별칭이 사라지거나 원본 메모리 읽기를 무조건 없앨 수 있는 것도 아닙니다.

다음 편에서는 지금까지의 구분을 GPU 버퍼에 적용합니다. 주소 값의 전달, 원소의 실제 복사, 자원 관리 객체의 이동을 같은 “복사”라는 말로 뭉뚱그리지 않고 읽을 수 있게 됩니다.

실행 검증: [12_optimizer.cpp](/downloads/cpp-commute/12_optimizer.cpp). 원문: [최적화 전 IR](/downloads/cpp-commute/artifacts/raw.ll), [mem2reg 후](/downloads/cpp-commute/artifacts/mem2reg.ll), [SROA 후](/downloads/cpp-commute/artifacts/sroa.ll), [Clang 실제 패스 기록](/downloads/cpp-commute/artifacts/clang_sroa_trace.txt), [최종 어셈블리](/downloads/cpp-commute/artifacts/optimized.s).

이전: [11 - 복사 생략과 반환 최적화](/posts/c-출근길-11-복사-생략과-반환-최적화/). 다음: [13 - GPU 버퍼로 전체 흐름 연결하기](/posts/c-출근길-13-gpu-버퍼로-전체-흐름-연결하기/).
