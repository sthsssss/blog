---
title: "C++ 출근길 07 — 표현식과 값 범주"
description: "타입과 표현식, lvalue·prvalue·xvalue·rvalue. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:57+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편에서 `get_ref(data)`는 기존 원본을 나타냈고 `make_gradient()`는 새 결과를 만들었습니다. C++는 이런 표현식을 구별해서 참조를 연결할 수 있는지, 어떤 생성자나 함수를 선택할지 결정합니다. 이 구분이 값 범주(value category)입니다.

타입은 어떤 종류의 객체나 값을 다루는지 설명합니다. 값 범주는 그 표현식이 기존 대상을 나타내는지, 새 값의 계산이나 결과 초기화를 수행하는지 설명합니다. 따라서 타입이 `Gradient`이라는 정보만으로 참조 바인딩과 복사·이동의 선택을 모두 결정할 수는 없습니다. Microsoft Learn에서도 표현식마다 타입과 값 범주를 함께 갖는다고 설명하고 있습니다. [Microsoft Learn: 값 범주](https://learn.microsoft.com/en-us/cpp/cpp/lvalues-and-rvalues-visual-cpp?view=msvc-170)

**기존 객체를 나타내는 이름은 lvalue입니다.**

```cpp
Gradient data{0, 255};
const Gradient frozen{0, 255};
Gradient& alias = data;
```

이후 이름 `data`, `frozen`, `alias`를 사용하는 표현식은 모두 lvalue입니다. lvalue는 이 사례에서 기존 어느 객체를 다루는지 나타냅니다. `alias`라는 이름도 원본 `data`를 나타냅니다. const 객체인 `frozen`도 lvalue이므로 lvalue라고 수정 가능한 것은 아닙니다.

대입문 `copy = data`의 오른쪽에 놓인 `data`도 lvalue입니다. 역사적인 이름의 left/right를 현재 대입문의 위치에 그대로 대응시키면 안 됩니다. `get_ref(data)`처럼 `Gradient&`를 반환하는 함수 호출도 같은 원본을 나타내는 lvalue입니다.

**새 결과를 초기화하거나 값을 계산하는 식은 prvalue일 수 있습니다.**

```cpp
Gradient copy = make_gradient();
int answer = 10 + 20;
```

`make_gradient()`와 `10 + 20`은 각각 prvalue입니다. 첫 호출은 `Gradient` 결과 객체를 초기화하는 데 쓰이고, 둘째 계산은 정수 값 30을 얻는 데 쓰입니다. 여기서 `copy`의 초기화식은 prvalue이지만, 초기화가 끝난 뒤 이름 `copy`를 사용하는 식은 lvalue입니다. 객체가 만들어진 방법이 이후 이름의 값 범주를 바꾸지는 않습니다.

prvalue를 “주소 없는 물건”이라고 단정하지는 않습니다. 클래스 결과에 참조를 연결하는 등 객체가 실제로 필요한 상황에서는 결과를 임시 객체로 구체화할 수 있습니다. 9편에서 그 객체가 언제 사라지는지 확인합니다.

**기존 객체를 자원 재사용 대상으로 제공하는 식은 xvalue입니다.**

```cpp
std::move(data)
```

`std::move`는 `<utility>`에 있는 표준 라이브러리 함수입니다. 여기서는 같은 `data`를 자원을 재사용할 수 있는 대상으로 취급하는 표현식으로 변환합니다. 이 식은 xvalue입니다. 새 `Gradient`를 만들거나 원본을 소멸시키는 연산은 아닙니다. 실제 자원 인계를 수행하는 함수가 선택되는 과정은 10편에서 다룹니다.

`data`와 `std::move(data)`는 같은 객체를 나타내지만 값 범주가 다릅니다. 이 정보로 C++는 기존 객체를 일반적으로 읽는 경우와 재사용 대상으로 제공하는 경우를 구별할 수 있습니다. 함수가 읽기만 하면 `std::move`를 사용했어도 원본 값은 그대로입니다.

**rvalue는 prvalue와 xvalue를 묶는 이름입니다.**

지금까지 나온 기본 분류는 lvalue, prvalue, xvalue 세 가지입니다. rvalue는 뒤의 두 가지를 묶는 이름이며 네 번째로 독립된 기본 종류가 아닙니다. 새 결과를 만드는 경우와 기존 객체를 재사용 대상으로 제공하는 경우 모두 rvalue 참조와 관련된 선택에 참여할 수 있기 때문에 함께 묶어 부릅니다.

표준 문서에서 만나는 glvalue는 lvalue와 xvalue를 묶는 이름입니다. 기존 어느 객체인지 나타낸다는 공통점을 강조할 때 사용합니다. 현재 예제들을 읽을 때는 `data`는 lvalue, `make_gradient()`는 prvalue, `std::move(data)`는 xvalue라는 세 출발점을 먼저 유지하면 됩니다. [표준 초안: 값 범주의 정의](https://eel.is/c++draft/basic.lval)

**값 범주는 실행 중에 메모리에 붙는 표지가 아닙니다.**

컴파일러가 소스 표현식을 분석할 때 사용하는 성질입니다. lvalue 객체가 항상 메모리에 있고 prvalue가 항상 레지스터에 있는 식으로 대응하지 않습니다. 1편의 지역 객체는 lvalue 이름으로 사용했지만 최적화 후 저장 공간이 없었습니다. 반대로 prvalue 결과를 읽을 객체가 필요하면 메모리에 구체화될 수 있습니다.

다음 편에서는 이 분류를 실제 선언에 적용합니다. 어떤 식에 `Gradient&`를 연결하고, 어떤 식에 `Gradient&&`를 연결하는지 보면 값 범주가 필요한 이유가 드러납니다.

검증 코드: [07_categories.cpp](/downloads/cpp-commute/07_categories.cpp). 첨부 파일의 타입 검사와 출력용 함수들은 이 분류 및 다음 편의 바인딩을 컴파일러로 확인하기 위한 코드입니다.

이전: [06 - 함수 반환과 결과 객체](/posts/c-출근길-06-함수-반환과-결과-객체/). 다음: [08 - 참조 바인딩과 const](/posts/c-출근길-08-참조-바인딩과-const/).
