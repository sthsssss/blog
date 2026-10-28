---
title: "C++ 출근길 03 — 참조와 원본 접근"
description: "바인딩·대입·참조 멤버, 주소를 저장하는 위치. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:10:01+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편에서는 `p->start`로 원본을 수정했습니다. C++의 참조(reference)는 기존 객체에 다른 이름을 붙여, 그 이름으로 필드에 직접 접근하게 합니다. 객체를 복사하는 경우와 달리 같은 필드에 접근합니다.

```cpp
Gradient data{0, 255};
Gradient& alias = data;
alias.start = 100;
```

`Gradient&`는 참조 타입이고, 초기화할 때 `alias`를 `data`에 연결합니다. 이 연결을 바인딩(binding)이라고 합니다. `alias.start`와 `data.start`는 같은 정수이므로 어느 이름으로 읽어도 100입니다. `&alias`를 구하면 원본 `data`의 주소를 얻습니다.

C++는 C의 포인터를 이어받은 뒤 참조를 별도 기능으로 추가했습니다. C++ 설계자인 비야네 스트롭스트룹은 기술 FAQ에서, 사용자 정의 타입의 `+` 같은 연산을 지원하는 연산자 오버로딩이 참조를 도입한 직접적인 이유였다고 설명하고 있습니다. 기존 객체를 복사하지 않으면서 `x + y`처럼 객체를 직접 다루는 식을 작성할 수 있기 때문입니다. [Stroustrup: 포인터와 참조의 도입 배경](https://www.stroustrup.com/bs_faq2.html#pointers-and-references)

**초기화한 뒤의 대입은 원본 값을 바꿉니다.**

초기 상태에서 시작하겠습니다.

```cpp
Gradient data{0, 255};
Gradient other{10, 20};
Gradient& alias = data;
alias = other;
alias.start = 50;
```

첫 초기화에서 참조할 대상은 `data`로 정해집니다. `alias = other`는 그 대상을 교체하지 않고 `data`에 `other`의 필드를 복사 대입합니다. 그 시점의 `data`는 `{10, 20}`입니다. 이어서 `alias.start = 50`도 `data`를 수정하므로 최종값은 `{50, 20}`이고 `other.start`는 10입니다. [표준 초안: 참조와 대입](https://eel.is/c++draft/dcl.init.ref)

`Gradient& second = alias`를 선언하면 `second`도 `data`에 연결됩니다. 반면 `Gradient copy = alias`는 원본을 읽어 새 객체를 복사 초기화합니다. 초기화식에 참조 이름이 있다는 사실보다, 새로 선언하는 것이 객체인지 참조인지가 중요합니다.

**참조 매개변수는 주소로 구현될 수 있습니다.**

```cpp
void set_reference(int& value) {
    value = 100;
}
```

이 함수를 `set_reference(number)`로 호출하면 매개변수 `value`가 호출자의 `number`에 연결됩니다. 이 환경에서 생성된 기계어는 다음과 같았습니다.

```asm
mov dword ptr [rdi], 100
ret
```

`rdi`에는 원본 정수의 주소가 들어옵니다. 함수는 그 주소에 100을 기록합니다. 매개변수의 연결 정보를 메모리에 따로 저장하는 단계는 없습니다. 포인터와 유사한 주소 전달로 구현했지만 C++ 소스에서는 참조가 지정한 객체를 직접 다루는 문법을 제공합니다.

**참조 멤버의 저장 공간은 또 다른 문제입니다.**

```cpp
struct GradientView {
    Gradient& data;
};

Gradient original{0, 255};
GradientView view{original};
GradientView copied_view = view;
```

`view`는 원본을 복제하지 않고 원본에 연결됩니다. 복사 생성한 `copied_view`의 참조 멤버도 같은 `original`에 연결됩니다. 이 타입의 객체를 일반적인 메모리 배치로 보관하려면 어느 원본인지 나타내는 정보가 필요하며, 현재 컴파일 환경에서는 참조 멤버를 주소 하나로 표현합니다.

여기서 함수의 참조 매개변수와 객체 안의 참조 멤버를 구별해야 합니다. 매개변수에 전달하는 주소는 레지스터에 있을 수 있습니다. 메모리에 실제로 존재하는 `view`는 자기 멤버의 연결 정보를 보관할 수 있습니다. 다만 지역 `view`를 통째로 없앨 수 있다면 이 저장 공간도 생략할 수 있습니다. 12편에서는 Clang이 그렇게 바꾸는 과정을 확인합니다. 언어 규칙 자체는 참조에 저장 공간이 필요한지 정해 두지 않고 있습니다. [표준 초안: 참조의 저장 공간](https://eel.is/c++draft/dcl.ref#4)

포인터나 참조를 만들었다는 이유로 원본을 자동으로 유지하거나 해제하지는 않습니다. 지금은 같은 원본을 읽고 쓸 수 있다는 사실에 집중하겠습니다. 다음 편에서는 그 접근 중 쓰기를 제한하는 `const`를 추가합니다.

전체 실행 코드: [03_references.cpp](/downloads/cpp-commute/03_references.cpp). `GradientView`의 기본 복사는 가능하지만 참조 멤버를 가진 타입의 기본 복사 대입은 삭제됩니다. 따라서 `copied_view = view`라는 기존 객체 대입과 위의 복사 초기화는 같은 조건이 아닙니다.

이전: [02 - 포인터와 주소 복사](/posts/c-출근길-02-포인터와-주소-복사/). 다음: [04 - const가 제한하는 대상](/posts/c-출근길-04-const가-제한하는-대상/).
