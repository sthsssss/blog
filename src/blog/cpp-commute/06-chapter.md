---
title: "C++ 출근길 06 — 함수 반환과 결과 객체"
description: "반환식·반환 타입·받는 선언, 주소 반환과 값 반환. 같은 예제를 따라 동작을 확인하고 실제 컴파일 결과와 연결합니다."
author: "Tae Shim"
pubDate: 2026-10-28T09:09:58+09:00
image:
  url: "/images/cpp-commute-series.svg"
  alt: "C++ 출근길: 객체에서 기계어까지"
tags: ["cpp", "systems", "cpp-commute"]
---

앞 편에서는 매개변수의 타입으로 사본을 만들거나 원본에 연결했습니다. 반환에서도 같은 구분을 사용합니다. 함수가 어떤 결과를 제공하는지와, 호출자가 그 결과로 무엇을 선언하는지는 별도의 단계입니다.

```cpp
Gradient get_copy(const Gradient& source) {
    return source;
}
```

`source`는 기존 원본에 연결된 읽기 전용 참조입니다. 하지만 반환 타입은 `Gradient`이므로 함수는 그 원본을 읽어 별도의 결과 객체를 복사 초기화합니다. `Gradient copy = get_copy(original);`로 받으면 원본과 별개인 객체를 얻습니다. `source`의 선언에 `&`가 있다는 이유로 함수의 반환 타입까지 참조가 되지는 않습니다. [표준 초안: return 문과 결과의 초기화](https://eel.is/c++draft/stmt.return)

**같은 본문에 참조 반환 타입을 사용하면 원본에 연결합니다.**

```cpp
Gradient& get_ref(Gradient& source) {
    return source;
}

Gradient original{0, 255};
Gradient& alias = get_ref(original);
alias.start = 100;
```

새 `Gradient`를 만들지 않고 반환한 참조를 원본에 연결합니다. 호출자의 `alias`도 같은 객체를 나타내므로 `original.start`가 100이 됩니다. 함수가 끝나서 매개변수 이름 `source`가 사라져도 원본은 바깥에서 살아 있습니다. 참조를 “source라는 지역 변수에 연결된 또 다른 참조”로 읽지 않습니다.

함수는 그대로 두고 받는 선언만 바꿀 수 있습니다. 다음은 다시 초기 상태입니다.

```cpp
Gradient original{0, 255};
Gradient copy = get_ref(original);
copy.start = 100;
```

`get_ref`는 여전히 원본에 대한 참조를 반환합니다. 호출자는 `Gradient` 객체를 선언했으므로 그 원본을 읽어 새 객체를 복사 초기화합니다. 최종적으로 원본 시작값은 0, 사본 시작값은 100입니다. 참조를 반환받았다는 사실과 참조 변수로 받았다는 사실은 다릅니다.

**const 참조 반환은 원본에 대한 읽기 경로를 제공합니다.**

```cpp
const Gradient& get_readonly(const Gradient& source) {
    return source;
}

const Gradient& read = get_readonly(original);
Gradient copy = get_readonly(original);
```

`read`를 통한 필드 수정은 금지되지만 `original`이 수정 가능한 객체라면 원본 이름으로는 바꿀 수 있습니다. 이후 `read`로 새 값이 보입니다. 반면 `copy`는 독립된 객체이며 수정 가능합니다. 복사는 원본을 읽으면 되므로 const 참조가 제공한 원본에서도 만들 수 있기 때문입니다.

복사본 자체도 수정하지 않으려면 `const Gradient frozen_copy = get_copy(original);`라고 선언합니다. `frozen_copy`는 복사 시점의 값이고 `read`는 원본의 현재 값을 읽는 경로라는 차이가 있습니다.

**직접 가진 멤버도 참조로 반환할 수 있습니다.**

```cpp
struct Owner {
    Gradient data{0, 255};
    Gradient& get_ref() { return data; }
    const Gradient& get_ref() const { return data; }
};
```

`data`는 참조 필드가 아니라 `Owner` 안에 들어 있는 실제 객체입니다. 반환 타입이 참조이므로 멤버에 대한 참조를 제공합니다. 첫 함수는 수정 가능한 `Owner`에, 둘째 함수는 const `Owner`에도 호출할 수 있습니다. 함수 뒤의 const가 호출 대상 객체에 적용되므로, const 경로의 멤버를 수정 가능하게 제공하지 않도록 반환 타입도 const 참조로 정했습니다.

반대로 멤버가 외부 원본에 연결된 참조여도 반환 타입을 `Gradient`로 선언하면 그 원본을 복사할 수 있습니다. 반환식이 어느 객체를 나타내는지와 반환 타입이 무엇인지가 판단 기준입니다.

**기계어에서도 주소 반환과 값 반환이 다릅니다.**

현재 두 정수 `Gradient`를 `get_copy` 형태로 반환하는 함수는 다음처럼 구현됐습니다.

```asm
mov rax, qword ptr [rdi]
ret
```

`rdi`는 원본 주소이고 `[rdi]`에서 두 필드의 8바이트 내용을 읽어 반환합니다. 참조를 반환하는 `get_ref` 형태는 다음과 같습니다.

```asm
mov rax, rdi
ret
```

여기서는 원본의 주소만 결과 레지스터로 전달합니다. `ret`가 값 반환과 참조 반환을 구분해 주는 것이 아니라, 그 전에 결과 레지스터에 무엇을 준비했는지가 다릅니다. 반환받은 호출자는 자기 선언에 따라 필드를 복사하거나 원본에 접근합니다. 현재의 작은 타입과 ABI에서 확인한 결과이며 모든 타입의 반환이 레지스터 하나로 이루어지는 것은 아닙니다.

새 설정을 만드는 함수도 작성할 수 있습니다. `Gradient make_gradient() { return Gradient{0, 255}; }`의 결과를 `Gradient made = make_gradient();`로 받으면 새 객체를 얻습니다. 같은 함수 호출 결과를 참조로 받을 수 있는 조건은 다음 두 편에서 설명합니다. 기존 객체를 나타내는 식과 새 결과를 만드는 식을 구분하는 언어 규칙이 먼저 필요합니다.

전체 실행 코드: [06_returns.cpp](/downloads/cpp-commute/06_returns.cpp). 값 반환과 주소 반환의 관찰 대상은 [machine_cases.cpp](/downloads/cpp-commute/machine_cases.cpp)의 `copy_gradient`와 `ref_gradient`입니다.

이전: [05 - 함수 인자와 호출 규약](/posts/c-출근길-05-함수-인자와-호출-규약/). 다음: [07 - 표현식과 값 범주](/posts/c-출근길-07-표현식과-값-범주/).
