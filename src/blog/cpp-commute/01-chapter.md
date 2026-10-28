---
title: "C++ 출근길 01 — 객체와 값 복사"
description: "객체·초기화·대입, 언어의 복사와 실제 명령. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:10:03+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

그라데이션 설정을 복사해 다른 색상으로 편집하려면 원본과 사본을 각각 수정할 수 있어야 합니다. C++에서는 값을 저장하는 대상을 객체(object)라고 부릅니다. 정수 하나도 객체이며, 여러 필드를 묶은 구조체도 객체입니다.

```cpp
struct Gradient {
    int start;
    int end;
};

Gradient data{0, 255};
```

`Gradient`는 타입이고 `data`는 그 타입의 객체를 나타내는 이름입니다. `start`와 `end`는 `data` 안에 들어 있는 정수 객체입니다. 여기서 `{0, 255}`는 선언 순서에 따라 두 필드를 초기화합니다. C++의 객체는 `new`로 만들어야만 존재하는 것이 아닙니다.

**사본을 만들면 수정할 대상이 하나 더 생깁니다.**

```cpp
Gradient data{0, 255};
Gradient copy = data;
copy.start = 100;
```

`Gradient copy = data`는 새 객체를 원본으로 복사 초기화합니다. 지금 타입에는 정수 필드만 있으므로 기본 복사 생성자가 두 필드를 복사합니다. 그 뒤 `copy.start`를 수정하면 `copy`는 `{100, 255}`가 되고 `data`는 `{0, 255}`로 남습니다. C++ 언어의 규칙을 기술한 표준 초안에서도 기본 복사 생성의 동작을 멤버별 초기화로 명시하고 있습니다. [표준 초안: 복사 생성자](https://eel.is/c++draft/class.copy.ctor)

이미 만들어진 객체에 같은 값을 넣을 수도 있습니다.

```cpp
Gradient assigned{10, 20};
assigned = data;
assigned.end = 200;
```

첫 줄은 객체를 만들고, 둘째 줄은 이미 있는 객체에 복사 대입합니다. 대입 직후 `assigned`는 `{0, 255}`, 마지막 줄 이후에는 `{0, 200}`입니다. 원본 `data.end`는 계속 255입니다. 생성과 대입은 나중에 다른 함수를 호출할 수 있으므로 지금부터 이름을 구분해 둡니다.

C#에서 클래스 변수를 대입하면 같은 인스턴스를 사용하는 상황이 익숙할 수 있습니다. C++의 `Gradient copy`는 객체를 직접 선언한 것입니다. `struct` 대신 `class`라고 쓰는 것만으로 객체 선언이 참조 변수로 바뀌지는 않습니다. [Microsoft Learn: 클래스와 구조체](https://learn.microsoft.com/en-us/cpp/cpp/classes-and-structs-cpp?view=msvc-170)

**객체 두 개라는 의미가 메모리 쓰기 두 번을 강제하지는 않습니다.**

CPU는 메모리뿐 아니라 레지스터라는 작은 저장 공간으로 값을 계산합니다. 컴파일러는 프로그램이 요구하는 결과를 유지하면서 값을 레지스터에 두거나 불필요한 저장을 없앨 수 있습니다. 다음 함수에서는 정수 하나로 이 차이를 볼 수 있습니다.

```cpp
int copy_int(int original) {
    int copy = original;
    return copy + 1;
}
```

C++ 코드에서 `copy`는 별도의 정수 객체입니다. 하지만 Clang이 최적화한 기계어는 다음과 같았습니다.

```asm
lea eax, [rdi + 1]
ret
```

이 환경에서 정수 인수는 `edi`에 들어오며 `rdi`는 그 레지스터의 64비트 이름입니다. `eax`는 정수 반환값을 담는 레지스터입니다. `lea`는 여기서 덧셈을 수행하고 메모리를 읽지 않습니다. `ret`는 함수를 마칩니다. 32비트 정수 덧셈에 필요한 하위 비트가 반환되므로 입력에 1을 더한 결과를 얻습니다.

`copy`에 해당하는 스택 공간을 만들거나 그곳으로 값을 복사하는 명령은 없습니다. 컴파일러가 이 함수에서 필요한 것은 “원본 값에 1을 더한 결과”뿐이라고 판단했기 때문입니다. 이러한 변환은 관찰 가능한 동작을 유지해야 한다는 언어의 원칙에 따릅니다. [표준 초안: 추상 기계와 as-if 원칙](https://eel.is/c++draft/intro.abstract)

앞의 `Gradient` 예제에서도 먼저 확인할 것은 원본과 사본을 각각 수정할 수 있다는 동작입니다. 물리적인 저장 명령은 전체 사용 방법을 알아야 결정됩니다. 다음 편에서는 사본을 만드는 대신 원본의 위치를 저장해 접근하는 포인터를 살펴봅니다.

전체 실행 코드: [01_objects.cpp](/downloads/cpp-commute/01_objects.cpp). 어셈블리의 원문 소스는 [machine_cases.cpp](/downloads/cpp-commute/machine_cases.cpp)의 `copy_int`입니다.

다음: [02 - 포인터와 주소 복사](/posts/c-출근길-02-포인터와-주소-복사/). 전체 순서: [00 - 시리즈 안내](/posts/c-출근길-시리즈/).
