---
title: "C++ 출근길 02 — 포인터와 주소 복사"
description: "포인터 값과 대상, 역참조, 배열. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:10:02+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편의 `Gradient copy = data`는 수정할 객체를 하나 더 만들었습니다. 이번에는 화면에서 사용 중인 원본을 다른 코드에서도 수정하려고 합니다. 원본이 있는 위치를 저장하면 그 객체를 다시 찾아갈 수 있습니다. 객체의 주소를 저장하는 타입이 포인터(pointer)입니다.

```cpp
Gradient data{0, 255};
Gradient* p = &data;
p->start = 100;
```

`data`에는 두 정수가 있고 `p`에는 `data`의 주소가 있습니다. `Gradient*`는 포인터 타입을 선언하는 표기입니다. 오른쪽의 `&data`는 주소를 구하는 연산입니다. `p->start`는 그 주소의 객체를 찾아 `start` 필드에 접근합니다. 따라서 마지막 줄은 `data.start`를 100으로 바꿉니다. [Microsoft Learn: 원시 포인터](https://learn.microsoft.com/en-us/cpp/cpp/raw-pointers?view=msvc-170)

같은 접근을 `(*p).start`라고 써도 됩니다. 표현식의 `*p`는 포인터가 지정한 객체를 나타내며, 이 연산을 역참조(dereference)라고 합니다. 선언의 `Gradient*`와 표현식의 `*p`는 위치에 따라 역할이 다릅니다.

**포인터를 복사하면 원본을 찾는 경로가 하나 더 생깁니다.**

다음은 초기 상태에서 시작합니다.

```cpp
Gradient data{0, 255};
Gradient* p = &data;
Gradient* q = p;
q->start = 100;
```

`q`는 새 포인터 객체이고 초기화할 때 주소 값을 복사합니다. 새로운 `Gradient`는 만들지 않습니다. 따라서 `q->start`, `p->start`, `data.start`는 모두 같은 정수를 나타냅니다.

```text
p에 저장된 주소 ─┐
                 ├─→ data {100, 255}
q에 저장된 주소 ─┘
```

이어서 `Gradient other{10, 20}; q = &other;`를 실행하면 `q`가 저장한 주소만 바뀝니다. 그 뒤 `q->start = 200`은 `other.start`를 수정하고, `p`는 여전히 `data`를 가리킵니다. `q = ...`는 주소 값에 대입하고 `*q = ...`는 그 주소의 객체에 대입한다는 차이입니다.

**주소를 전달하는 명령과 대상을 읽는 명령은 다릅니다.**

```cpp
int* pointer_identity(int* p) { return p; }
int read_pointer(int* p) { return *p; }
```

첫 함수는 주소 자체를 반환하고 둘째 함수는 그 주소에서 읽은 정수를 반환합니다. Clang의 최적화 결과는 각각 다음과 같았습니다.

```asm
; pointer_identity
mov rax, rdi
ret

; read_pointer
mov eax, dword ptr [rdi]
ret
```

포인터 인수는 64비트 레지스터 `rdi`, 포인터 반환값은 `rax`로 전달됩니다. `mov rax, rdi`는 레지스터 사이에서 주소 값만 복사합니다. 대괄호가 있는 `[rdi]`는 그 주소의 메모리에 접근합니다. `dword ptr`는 여기서 4바이트 정수를 읽는다는 크기 표시입니다.

첫 함수에 포인터 변수가 있다고 해서 메모리에 포인터 저장 공간을 따로 만들지는 않았습니다. 주소 값도 정수 값처럼 레지스터에서 사용할 수 있습니다. 반면 둘째 함수는 호출자가 지정한 원본을 읽어야 하므로 메모리 읽기가 남았습니다.

**배열에서는 주소와 길이를 함께 생각합니다.**

```cpp
int values[]{10, 20, 30};
int* first = values;
first[1] = 99;
```

이 초기화에서 `values`는 첫 원소의 주소로 변환됩니다. `first[1]`은 그 시작 위치에서 `int` 원소 하나만큼 떨어진 두 번째 원소를 나타내므로 배열은 `{10, 99, 30}`이 됩니다. 포인터 자체에는 원소 개수가 들어 있지 않습니다. 범위를 관리하려면 개수를 따로 전달하거나, 뒤에서 소개할 주소와 길이를 묶는 타입을 사용해야 합니다. [표준 초안: 배열에서 포인터로의 변환](https://eel.is/c++draft/conv.array)

`nullptr`는 지정한 객체가 없는 포인터 값입니다. 그 상태로 역참조할 수 없습니다. 또한 주소 값이 남아 있어도 원본이 이미 소멸했다면 접근할 수 없습니다. 수명은 9편에서 원본이 사라지는 순서로 확인합니다.

다음 편에서는 원본에 접근하면서도 포인터를 직접 역참조하는 문법 없이 사용할 수 있는 참조를 살펴봅니다. 포인터의 주소 교체와 참조를 통한 값 대입이 어떻게 달라지는지 같은 예제로 비교합니다.

전체 실행 코드: [02_pointers.cpp](/downloads/cpp-commute/02_pointers.cpp). 기계어 소스: [machine_cases.cpp](/downloads/cpp-commute/machine_cases.cpp).

이전: [01 - 객체와 값 복사](/posts/c-출근길-01-객체와-값-복사/). 다음: [03 - 참조와 원본 접근](/posts/c-출근길-03-참조와-원본-접근/).
