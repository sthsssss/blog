---
title: "C++ 출근길 08 — 참조 바인딩과 const"
description: "T&·const T&·T&&, 이름과 std::move, auto. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:56+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편에서 기존 이름 `data`는 lvalue, 새 결과를 만드는 `make_gradient()`는 prvalue, 같은 원본을 재사용 대상으로 제공하는 `std::move(data)`는 xvalue였습니다. 이번에는 이 식들을 참조 초기화에 넣어 보겠습니다. 모든 예제의 대상 타입은 같은 `Gradient`입니다.

```cpp
Gradient data{0, 255};
Gradient& edit = data;
const Gradient& read = data;
```

수정 가능한 `Gradient&`는 여기서 수정 가능한 lvalue 원본에 연결됩니다. `const Gradient&`는 같은 원본에 읽기 전용으로 연결됩니다. 원본이 처음부터 const이면 `Gradient&`로 연결할 수 없고 const 참조가 필요합니다. 앞의 const 규칙과 값 범주를 함께 적용한 것입니다.

**새 결과나 재사용 대상으로 제공한 객체에는 우측값 참조를 연결할 수 있습니다.**

```cpp
Gradient&& result = make_gradient();
Gradient&& candidate = std::move(data);
```

`Gradient&&`는 우측값 참조(rvalue reference) 타입입니다. 첫 줄은 새 결과 객체에 연결하고 둘째 줄은 기존 `data`에 연결합니다. `candidate.start = 100`은 원본 `data.start`를 바꿉니다. 이 초기화 자체로 새로운 `Gradient`를 이동 생성하지는 않았습니다.

일반 `Gradient&`는 이 prvalue나 xvalue에 연결할 수 없습니다. 반대로 `Gradient&& candidate = data;`처럼 lvalue를 바로 연결할 수도 없습니다. 이 글은 구체적인 타입을 명시한 일반 선언을 다루며 템플릿 추론에서 사용하는 별도 규칙은 포함하지 않습니다. [표준 초안: 참조 초기화](https://eel.is/c++draft/dcl.init.ref)

**const 참조는 읽기 접근을 제공하며 rvalue에도 연결됩니다.**

```cpp
const Gradient& temporary_read = make_gradient();
const Gradient& existing_read = std::move(data);
```

첫 줄은 새 결과를, 둘째 줄은 기존 원본을 읽기 전용으로 사용합니다. 수정 가능한 일반 lvalue 참조로 임시 결과를 편집하려 하지 말고, 편집할 독립 객체가 필요하면 `Gradient value = make_gradient();`로 받으면 됩니다. 임시 객체에 연결한 참조의 수명은 다음 편에서 확인합니다.

`const Gradient frozen{0, 255};`에서 `std::move(frozen)`을 만들면 const가 사라지지 않습니다. 결과는 const 객체를 나타내는 xvalue이므로 수정 가능한 `Gradient&&`에 연결할 수 없습니다. `const Gradient&`는 연결할 수 있습니다. const와 값 범주는 서로 다른 성질이라는 7편의 구분이 여기에도 적용됩니다.

**우측값 참조의 이름을 사용하면 그 표현식은 lvalue입니다.**

```cpp
Gradient&& candidate = std::move(data);
Gradient& edit = candidate;
```

`candidate`의 선언 타입은 우측값 참조이지만 이름 `candidate`는 기존 객체를 나타내는 lvalue 표현식입니다. 그래서 둘째 줄은 가능합니다. 다시 rvalue 대상으로 제공하려면 `std::move(candidate)`라고 작성합니다. 선언 타입과 그 이름을 사용하는 표현식의 범주를 나누어 읽어야 하는 대표적인 경우입니다.

이 차이는 함수 선택에도 사용됩니다. 같은 이름의 함수에 `Gradient&`, `const Gradient&`, `Gradient&&` 매개변수가 각각 있으면 컴파일러가 인수에 맞는 것을 고릅니다. 이를 오버로딩(overloading)이라고 합니다. 첨부 예제에서 `data`는 수정 가능한 lvalue용 함수를, `frozen`은 const 참조 함수를, `make_gradient()`와 `std::move(data)`는 우측값 참조 함수를 선택했습니다. 이름 `candidate`를 그대로 전달하면 다시 lvalue용 함수가 선택됩니다. 선택된 함수가 읽기만 한다면 이 호출로 자원이 이동하지는 않습니다.

**auto는 참조를 자동으로 유지하는 표시가 아닙니다.**

```cpp
const Gradient& read = data;
auto copy = read;
auto& alias = read;
const auto& explicit_read = data;
```

이 예제의 `copy`는 수정 가능한 `Gradient` 객체입니다. 일반 `auto`는 참조와 바깥쪽 const를 그대로 보존하지 않으므로 원본을 읽어 사본을 만듭니다. `alias`는 `const Gradient&`이고 `explicit_read`도 const 참조입니다. `auto&`에 추가한 `&`는 연결할 참조를 만들겠다는 선언이며 원본의 const를 없애지는 않습니다. [Microsoft Learn: auto 추론](https://learn.microsoft.com/en-us/cpp/cpp/auto-cpp?view=msvc-170)

반환 타입이 `const Gradient`인 함수도 `&`가 없으므로 값 반환입니다. 그 결과를 `Gradient copy = function();`로 받으면 const가 아닌 별도 객체를 얻을 수 있습니다. 반면 `const Gradient&` 반환은 기존 객체에 대한 const 접근 경로를 제공합니다. const를 어느 단계에 적용했는지와 객체를 새로 만드는지를 함께 읽어야 합니다.

참조를 연결할 수 있다는 판단은 문법의 유효성을 알려 줍니다. 다음 편에서는 연결한 대상이 마지막 사용까지 살아 있는지 확인합니다. 특히 임시 객체를 const 참조로 받는 두 코드가 모두 컴파일돼도 수명이 달라질 수 있습니다.

전체 실행 코드: [08_binding.cpp](/downloads/cpp-commute/08_binding.cpp). 함수 선택 관찰: [07_categories.cpp](/downloads/cpp-commute/07_categories.cpp).

이전: [07 - 표현식과 값 범주](/posts/c-출근길-07-표현식과-값-범주/). 다음: [09 - 객체의 수명과 임시 객체](/posts/c-출근길-09-객체의-수명과-임시-객체/).
