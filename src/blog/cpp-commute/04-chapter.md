---
title: "C++ 출근길 04 — const가 제한하는 대상"
description: "객체·포인터·대상·const 멤버 함수. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:10:00+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편의 참조와 포인터는 기존 객체에 접근하게 했습니다. 그라데이션을 그리는 코드는 설정을 읽으면 충분하지만, 편집 코드는 필드를 바꿀 수 있어야 합니다. C++의 `const`는 어느 타입을 수정 불가능하게 다룰지 표현합니다.

```cpp
const Gradient frozen{0, 255};
// frozen.start = 100; // 컴파일 오류
```

`frozen`은 const 객체이며 그 안에 직접 들어 있는 일반 정수 필드도 수정할 수 없습니다. 객체를 다른 것으로 교체하지 못하게 하는 제한뿐 아니라, 객체의 일반 필드를 쓰는 연산까지 제한합니다. [Microsoft Learn: const](https://learn.microsoft.com/en-us/cpp/cpp/const-cpp?view=msvc-170)

이번에는 원본의 타입을 유지하고 참조에 const를 적용합니다.

```cpp
Gradient data{0, 255};
const Gradient& read = data;
// read.start = 100; // 컴파일 오류
data.start = 100;
```

`read`는 같은 `data`에 읽기 전용으로 접근합니다. `data` 자체는 수정 가능한 객체로 만들었으므로 `data.start`에 쓰는 것은 가능합니다. 이후 `read.start`를 읽으면 100입니다. const 참조는 원본의 동결된 사본을 만들거나 다른 모든 별칭의 쓰기를 잠그지 않습니다. [표준 초안: const 접근 경로](https://eel.is/c++draft/dcl.type.cv)

**포인터에서는 주소와 대상의 타입을 각각 읽습니다.**

```cpp
const Gradient* p = &data;
```

이 선언의 `const`는 가리키는 `Gradient`에 붙습니다. 따라서 `p->start`로 수정할 수 없지만 `p = &other`처럼 포인터 자체에 다른 주소를 넣을 수 있습니다. `other`도 살아 있는 `Gradient`라고 가정합니다.

```cpp
Gradient* const fixed = &data;
```

이번에는 포인터 자체가 const입니다. `fixed`에 다른 주소를 넣을 수 없지만, 가리키는 타입은 수정 가능한 `Gradient`이므로 `fixed->start = 120`은 가능합니다. 두 제한을 모두 원하면 `const Gradient* const fixed_read = &data`라고 씁니다. `Gradient const*`는 `const Gradient*`와 같은 뜻이며 본문에서는 후자로 통일합니다. [Microsoft Learn: const 포인터](https://learn.microsoft.com/en-us/cpp/cpp/const-and-volatile-pointers?view=msvc-170)

참조의 연결 대상은 처음부터 대입으로 바꿀 수 없습니다. 따라서 `const Gradient&`의 const는 그 연결을 고정하는 표시가 아니라 원본을 수정할 수 있는지를 정하는 표시입니다.

**구조체 내부에 실제로 들어 있는 데이터와 외부 대상은 다릅니다.**

```cpp
struct Owner { Gradient data; };
struct PointerView { Gradient* target; };
struct ReferenceView { Gradient& target; };
```

`Owner`에는 `Gradient` 객체가 직접 들어 있습니다. const `Owner`의 `data.start`를 수정할 수 없습니다. 반면 `PointerView`와 `ReferenceView`는 외부의 원본에 접근하는 정보만 가집니다.

```cpp
Gradient data{0, 255};
const PointerView pv{&data};
const ReferenceView rv{data};
pv.target->start = 150;
rv.target.start = 180;
```

두 대입 모두 가능합니다. const `pv`의 포인터 필드에 다른 주소를 넣을 수는 없지만 외부 `data`는 그 객체의 하위 객체가 아닙니다. const `rv`의 참조 필드도 외부 원본의 타입을 바꾸지 않습니다. 최종적으로 `data.start`는 180입니다. 외부 대상에 대한 쓰기까지 막으려면 필드 타입을 `const Gradient*` 또는 `const Gradient&`로 정해야 합니다.

**멤버 함수 뒤의 const도 같은 원칙입니다.**

```cpp
struct MeasuredGradient {
    int start;
    int end;
    int width() const { return end - start; }
};
```

`width() const`는 호출된 객체를 const 경로로 다룹니다. 함수 안의 `this`는 이 경우 `const MeasuredGradient*`이며 일반 필드에 쓸 수 없습니다. 따라서 const 객체에서도 `width()`를 호출할 수 있습니다. `this`는 멤버 함수를 호출한 객체의 주소입니다. [표준 초안: this의 타입](https://eel.is/c++draft/expr.prim.this)

이 규칙도 외부 포인터 대상까지 자동으로 불변으로 만들지는 않습니다. C++에는 `mutable`로 특정 필드를 별도로 허용하는 기능이 있지만 여기의 필드에는 사용하지 않았습니다.

기계어에는 이 const 경로를 잠그는 별도 장치가 필요하지 않습니다. `int read_const_reference(const int& value) { return value; }`는 현재 Clang에서 `mov eax, dword ptr [rdi]`와 `ret`로 구현됐습니다. const를 검사하는 일은 컴파일할 때 이루어지고, 실행 중에는 주소에서 정수를 읽습니다. 실제 const 객체의 메모리가 운영체제에 의해 쓰기 방지 영역에 놓이는지는 또 다른 구현상의 선택입니다.

다음 편에서는 이렇게 정한 접근 방식을 함수 인자에 적용합니다. 주소를 값으로 전달하면서도 원본을 수정할 수 있는 이유가 앞 두 편의 구분으로 설명됩니다.

전체 실행 코드: [04_const.cpp](/downloads/cpp-commute/04_const.cpp).

이전: [03 - 참조와 원본 접근](/posts/c-출근길-03-참조와-원본-접근/). 다음: [05 - 함수 인자와 호출 규약](/posts/c-출근길-05-함수-인자와-호출-규약/).
