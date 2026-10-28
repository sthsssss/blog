---
title: "C++ 출근길 10 — 값 의미론과 복사 및 이동"
description: "멤버별 복사·소유권·RAII·이동 생성. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:54+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편까지는 원본에 접근하는 방법과 수명을 살펴봤습니다. 이번에는 객체가 별도의 메모리를 관리하는 경우입니다. 저장 공간을 확보한 객체가 그것을 해제할 책임까지 맡는다면, 단순히 주소를 복사하는 것으로 객체 전체를 올바르게 복사할 수 있는지 생각해야 합니다.

`std::vector<int>`는 길이가 바뀔 수 있는 정수 배열을 관리하는 표준 라이브러리 타입입니다. vector 객체와 실제 원소를 저장하는 공간은 구분됩니다. 객체는 그 원소 저장 공간을 관리하고, 자원을 보유한 상태로 소멸할 때 정리합니다. 이 책임을 소유권(ownership)이라고 부릅니다. 객체의 수명에 정리를 연결하는 방식이 RAII입니다.

**vector의 복사본은 원본과 별개로 수정할 수 있습니다.**

```cpp
std::vector<int> a{10, 20, 30};
std::vector<int> b = a;
b[0] = 99;
```

vector의 복사 생성자는 원소들을 별도 저장 공간에 복사합니다. 따라서 `a[0]`은 10, `b[0]`은 99입니다. 객체가 표현하는 값을 복사한 뒤 각각 독립적으로 사용할 수 있게 하는 설계가 값 의미론(value semantics)입니다.

구조체의 필드가 vector이면 기본 복사 생성도 그 멤버의 복사 생성자를 사용합니다. 반대로 필드가 포인터이면 주소를 복사하고, 참조이면 같은 원본에 연결합니다. 기본 복사가 멤버별로 수행된다는 규칙은 같지만 멤버 타입의 동작이 다릅니다.

비야네 스트롭스트룹과 허브 서터가 편집하는 C++ Core Guidelines에서도 이 차이를 설명하고 있습니다. C.61에서는 복사한 값들을 독립적으로 사용하는 경우와, 복사한 포인터들이 공유 원본에 접근하는 경우를 구분하고 있습니다. 어떤 동작이 적절한지는 타입이 제공하려는 값의 의미에 따라 결정합니다. [Core Guidelines C.61](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-copy-semantic)

값 전달은 함수 매개변수를 초기화하는 방법이고 값 의미론은 타입의 복사·수정 동작에 관한 설계입니다. 5편의 포인터도 값으로 전달했지만 대상까지 복제하지는 않았습니다.

**이동 생성은 기존 자원을 인계할 수 있는 경로입니다.**

```cpp
std::vector<int> source{10, 20, 30};
int* previous_address = source.data();
std::vector<int> destination = std::move(source);
```

`data()`는 vector의 원소 저장 공간 주소를 제공합니다. 이 예제의 일반적인 vector 이동 생성자는 기존 저장 공간을 `destination`이 관리하도록 합니다. 따라서 `destination.data()`와 `previous_address`는 같고 원소를 새 배열로 복제하지 않습니다. 별도 allocator 인수를 받는 생성자 등은 다른 조건을 가질 수 있으며 여기에는 사용하지 않았습니다.

8편에서 `Gradient&& candidate = std::move(data)`는 참조만 연결했습니다. 지금은 왼쪽에 새 vector 객체를 선언했습니다. `std::move(source)`라는 xvalue를 이용해 그 객체의 이동 생성자를 선택하고, 생성자가 실제 인계를 수행합니다. 같은 표현식이라도 새 객체를 만드는 연산이 있는지를 함께 읽어야 합니다.

복사·이동 생성자의 핵심 매개변수 형태는 `T(const T& other)`와 `T(T&& other)`입니다. 생성자는 객체가 만들어질 때 초기 상태를 구성하는 함수입니다. 기존 lvalue를 제공하면 복사 생성이, 수정 가능한 xvalue를 제공하면 가능한 경우 이동 생성이 선택됩니다. 실제 이동 경로가 없으면 복사가 선택되거나 초기화가 허용되지 않을 수도 있으므로 타입의 제공 연산도 중요합니다.

**std::move 자체가 자원을 이동시키지는 않습니다.**

우측값 참조를 받는 함수라도 본문이 원소 개수만 읽으면 저장 공간은 그대로입니다. `std::move`가 하는 일은 표현식의 변환이고, 실제 작업은 선택된 함수나 생성자의 구현입니다. 정수 두 개뿐인 `Gradient`의 기본 이동은 필드 값을 복사하는 것과 같은 결과를 낼 수 있습니다. 모든 이동이 주소 인계이거나 항상 더 빠른 것은 아닙니다. [표준 초안: std::move](https://eel.is/c++draft/forward)

const vector에 `std::move`를 적용해도 const는 유지됩니다. 수정 가능한 `vector&&` 이동 생성자에 연결할 수 없으므로 이 경우에는 `const vector&` 복사 생성자가 선택됩니다. 8편에서 확인한 바인딩 규칙이 복사 비용에 직접 연결된 것입니다.

이동한 원본 객체는 자동으로 사용 금지 변수가 되지 않습니다. 표준 라이브러리 타입의 이동 후 상태는 별도 보장이 없으면 유효하지만 구체적인 값은 정해지지 않습니다. 예전 원소가 그대로 있다고 가정해 접근하지 않고, `source = {7};`처럼 새 값을 대입해 다시 사용할 수 있습니다. [표준 초안: 이동 후 상태](https://eel.is/c++draft/lib.types.movedfrom)

**소유권은 원시 주소와 별도로 표현합니다.**

```cpp
std::unique_ptr<Gradient> owner =
    std::make_unique<Gradient>(Gradient{0, 255});
Gradient* observer = owner.get();
std::unique_ptr<Gradient> next = std::move(owner);
```

`unique_ptr<Gradient>`는 단일 객체의 해제 책임을 맡는 표준 타입입니다. `get()`은 원본 주소를 제공하지만 소유권을 주지는 않습니다. 이동 후 `next`가 같은 객체를 관리하고 `owner`는 비어 있습니다. 대상 객체의 주소는 그대로이므로 `observer`도 여전히 같은 원본을 가리킵니다. 단, 새 소유자가 원본을 해제한 뒤에는 사용할 수 없습니다. [Microsoft Learn: 스마트 포인터와 RAII](https://learn.microsoft.com/en-us/cpp/cpp/smart-pointers-modern-cpp?view=msvc-170)

이 타입은 복사를 허용하지 않습니다. 주소만 복사해 두 객체가 각각 같은 원본을 해제하게 만드는 동작을 제공하지 않는 것입니다. vector는 값의 독립성을 제공하기 위해 복사를 구현했고 unique_ptr는 단독 해제 책임을 나타내기 위해 복사를 제한했습니다.

지금까지는 복사와 이동이 선택됐을 때의 동작을 설명했습니다. 다음 편에서는 아예 두 객체를 따로 만들지 않는 반환을 살펴봅니다. 이 경우 생성자 호출을 줄이는 언어 규칙과, 나중에 기계어를 줄이는 일반 최적화를 구별해야 합니다.

전체 실행 코드: [10_semantics.cpp](/downloads/cpp-commute/10_semantics.cpp).

이전: [09 - 객체의 수명과 임시 객체](/posts/c-출근길-09-객체의-수명과-임시-객체/). 다음: [11 - 복사 생략과 반환 최적화](/posts/c-출근길-11-복사-생략과-반환-최적화/).
