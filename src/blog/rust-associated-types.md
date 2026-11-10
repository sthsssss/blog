---
title: "Rust의 연관 타입: Iterator<T>와 Iterator의 Item은 무엇이 다른가"
slug: "rust-associated-types"
pubDate: 2026-11-11
description: "같은 Counter와 next 호출을 유지한 채 제네릭 매개변수와 연관 타입을 비교합니다. 타입 추론 오류, 구현의 식별, 제네릭 함수의 계약을 거쳐 Future<Output = u32>까지 연결합니다."
author: "Tae Shim"
image:
  url: "/images/rust-associated-types.svg"
  alt: "제네릭 타입 인수는 구현 선택에 참여하고 연관 타입은 선택된 구현에서 결정되는 관계"
tags: ["rust", "traits", "generics", "async"]
---

Rust에서 `trait Iterator<T>`와 `trait Iterator { type Item; }`는 모두 여러 종류의 원소를 다루는 인터페이스를 표현할 수 있습니다. 숫자를 반환하는 구현을 하나만 작성해 보면 둘의 동작도 거의 같아 보입니다. 그 단계에서는 “왜 타입 이름을 굳이 trait 안에 선언해야 하는가”라는 의문이 자연스럽게 남습니다.

차이를 확인하려면 값을 반환하는 코드보다 **그 코드를 사용하는 쪽에서 무엇을 알아야 하는지**를 살펴봐야 합니다. `counter.next()`라는 한 줄을 컴파일하려면 컴파일러는 어떤 구현을 호출할지, 그 호출의 결과 타입은 무엇인지 알아야 합니다. 타입 매개변수와 연관 타입은 이 정보를 연결하는 방식이 다릅니다.

이 글에서는 동일한 `Counter`와 `next`를 사용합니다. 먼저 결과 타입을 직접 적는 구현에서 출발하고, 결과 타입을 제네릭 매개변수로 바꾼 뒤, 연관 타입으로 바꿉니다. 마지막에는 이 차이를 비동기 함수의 `Future<Output = u32>`에 적용합니다. 예제의 `GenericIterator`와 `AssociatedIterator`는 비교를 위한 사용자 정의 trait입니다. 표준 라이브러리의 `Iterator`와 이름이 충돌하지 않도록 이름을 구분했습니다.

## 1. 원래 반환 타입은 메서드 선언에 있습니다

우선 제네릭도 연관 타입도 없는 작은 프로그램을 보겠습니다.

```rust
struct Counter {
    current: u32,
}

impl Counter {
    fn next(&mut self) -> Option<u32> {
        self.current += 1;
        Some(self.current)
    }
}

fn main() {
    let mut counter = Counter { current: 0 };
    let value = counter.next();
    println!("{value:?}");
}
```

실행 결과는 `Some(1)`입니다. `Option<u32>`는 값이 있으면 `Some(u32)`, 없으면 `None`으로 표현하는 타입입니다. 여기서는 타입 관계에 집중하기 위해 종료 조건을 생략했습니다. 카운터의 범위를 넘어가도록 반복 실행하는 용도의 구현은 아닙니다.

`let value`에 타입을 적지 않아도 컴파일됩니다. 컴파일러는 `counter`가 `Counter`라는 사실로부터 `Counter::next`를 찾고, 그 선언에 있는 `Option<u32>`를 `value`의 타입으로 사용할 수 있습니다. 프로그램은 실행 전에 이미 반환 타입이 정해져 있습니다.

이제 숫자 외에 다른 원소를 생산하는 타입도 공통 인터페이스로 다루고 싶다고 하겠습니다. 공통 동작의 이름은 `next`로 유지하되, 반환하는 원소 타입은 구현마다 달라져야 합니다. 이 요구를 표현하는 방법으로 제네릭 매개변수와 연관 타입을 비교할 수 있습니다.

## 2. 제네릭 매개변수로 원소 타입을 지정합니다

원소 타입을 `T`라는 매개변수로 받는 trait을 선언합니다.

```rust
trait GenericIterator<T> {
    fn next(&mut self) -> Option<T>;
}
```

`GenericIterator<u32>`를 구현한다는 것은 이 선언의 `T`를 `u32`로 사용하여 메서드를 제공한다는 뜻입니다. 다음 프로그램에는 구현이 하나만 있습니다.

```rust
trait GenericIterator<T> {
    fn next(&mut self) -> Option<T>;
}

struct Counter {
    current: u32,
}

impl GenericIterator<u32> for Counter {
    fn next(&mut self) -> Option<u32> {
        self.current += 1;
        Some(self.current)
    }
}

fn main() {
    let mut counter = Counter { current: 0 };
    let value = counter.next();
    println!("{value:?}");
}
```

이 프로그램도 `Some(1)`을 출력합니다. 여기서도 `value`의 타입 표기는 필요하지 않습니다. 이 예제의 메서드 탐색에서 일치하는 구현이 하나이므로 컴파일러가 `T = u32`를 추론할 수 있기 때문입니다. **제네릭 trait이라는 이유만으로 모든 호출에 타입 인수를 직접 적어야 하는 것은 아닙니다.**

지금까지는 일반 메서드와 비교해 큰 차이가 없습니다. 차이가 나타나는 지점은 같은 `Counter`에 두 번째 구현을 추가할 때입니다.

## 3. 같은 Counter에 문자열 구현을 추가하면 호출에 정보가 더 필요합니다

앞 프로그램의 `main` 위에 다음 구현을 추가할 수 있습니다.

```rust
impl GenericIterator<String> for Counter {
    fn next(&mut self) -> Option<String> {
        self.current += 1;
        Some(self.current.to_string())
    }
}
```

이제 컴파일러가 사용할 수 있는 구현은 두 개입니다.

| 구현 대상 | 구현하는 trait | 메서드 반환 타입 |
| --- | --- | --- |
| `Counter` | `GenericIterator<u32>` | `Option<u32>` |
| `Counter` | `GenericIterator<String>` | `Option<String>` |

두 구현은 모두 `Counter`의 `current`를 증가시킵니다. 첫 번째 구현은 그 숫자를 반환하고, 두 번째 구현은 숫자를 문자열로 변환해 반환합니다. 두 trait 인스턴스는 타입 인수가 다르므로 두 구현을 함께 정의할 수 있습니다.

하지만 기존 `main`의 다음 줄은 이제 모호합니다.

```rust
let value = counter.next();
```

`counter`의 타입이 `Counter`라는 사실은 여전히 같습니다. 그런데 그 정보만으로는 두 구현 중 하나를 고를 수 없습니다. 뒤의 `println!("{value:?}")`도 선택에 도움이 되지 않습니다. `Option<u32>`와 `Option<String>`은 모두 디버그 출력이 가능하기 때문입니다. 이 변형을 Rust 1.95.0으로 컴파일하면 타입 정보가 더 필요하다는 E0283 오류가 발생합니다.

반환할 타입을 지정하면 모호함이 사라집니다. 기존 `main`을 다음으로 바꾸면 됩니다.

```rust
fn main() {
    let mut counter = Counter { current: 0 };

    let number: Option<u32> = counter.next();
    let text: Option<String> = counter.next();

    println!("{number:?}");
    println!("{text:?}");
}
```

실행 결과는 다음과 같습니다.

```text
Some(1)
Some("2")
```

첫 번째 호출은 결과가 `Option<u32>`여야 하므로 숫자 구현을 사용합니다. 두 번째 호출은 결과가 `Option<String>`이어야 하므로 문자열 구현을 사용합니다. 두 호출은 같은 `counter`를 수정하므로 두 번째 결과의 숫자는 2입니다.

이 선택은 실행 중 반환값을 보고 수행하는 변환이 아닙니다. **컴파일러가 주변의 타입 정보를 이용해 호출할 구현을 결정합니다.** 어떤 구현을 호출하는지 직접 적으면 다음과 같습니다.

```rust
let number = <Counter as GenericIterator<u32>>::next(&mut counter);
let text = <Counter as GenericIterator<String>>::next(&mut counter);
```

`<Counter as GenericIterator<u32>>`는 “Counter에 제공된 GenericIterator<u32> 구현”을 지정합니다. `next`는 `&mut self`를 받으므로 이 표기에서는 `&mut counter`를 명시적으로 전달합니다. 이 두 줄은 앞의 두 호출을 대체하는 표현입니다. 뒤에 덧붙여 실행하면 카운터도 추가로 증가합니다.

여기까지의 설계에서는 결과 타입이 구현을 선택하는 데 참여합니다. “어떤 객체인가”에 더하여 “어떤 원소 타입의 인터페이스를 사용할 것인가”까지 알아야 호출이 확정됩니다.

## 4. 연관 타입은 선택한 구현 안에서 원소 타입을 정합니다

이제 같은 역할을 연관 타입으로 표현하겠습니다. 앞의 프로그램과 별개로 실행할 수 있는 전체 예제입니다.

```rust
trait AssociatedIterator {
    type Item;

    fn next(&mut self) -> Option<Self::Item>;
}

struct Counter {
    current: u32,
}

impl AssociatedIterator for Counter {
    type Item = u32;

    fn next(&mut self) -> Option<Self::Item> {
        self.current += 1;
        Some(self.current)
    }
}

fn main() {
    let mut counter = Counter { current: 0 };
    let value = counter.next();
    println!("{value:?}");
}
```

이 프로그램도 `Some(1)`을 출력합니다. `type Item;`은 객체에 저장하는 필드가 아닙니다. trait을 구현할 때 정의할 **타입의 이름**을 선언합니다. `type Item = u32;`는 이번 구현에서 그 이름이 뜻하는 타입을 정합니다. 따라서 이 구현에서 `Option<Self::Item>`은 `Option<u32>`입니다.

이때 컴파일러가 확인하는 관계는 다음과 같습니다.

| 구현 대상 | 구현하는 trait | 그 구현 안에 정의된 타입 |
| --- | --- | --- |
| `Counter` | `AssociatedIterator` | `Item = u32` |

`Counter`의 `AssociatedIterator` 구현을 찾으면 그 안에 `Item = u32`가 있습니다. 결과 타입은 그 구현에서 따라 나옵니다. `Item`에 무엇을 넣을지 호출자가 별도로 선택하지 않습니다.

문자열용 두 번째 구현을 추가하려고 하면 이 차이가 드러납니다.

```rust
// 기존 숫자 구현과 함께 작성하면 컴파일 오류입니다.
impl AssociatedIterator for Counter {
    type Item = String;

    fn next(&mut self) -> Option<Self::Item> {
        self.current += 1;
        Some(self.current.to_string())
    }
}
```

이 변형은 E0119, 상충하는 구현 오류로 거절됩니다. 두 `impl`의 머리 부분이 모두 `impl AssociatedIterator for Counter`이기 때문입니다. 본문에 쓴 `Item`의 정의를 바꿔도 서로 다른 구현으로 구별되지 않습니다.

Rust의 언어 규칙을 정리한 [Rust Reference의 연관 항목 설명](https://doc.rust-lang.org/reference/items/associated-items.html#associated-types)은 trait 안의 연관 타입 선언과 구현 안의 타입 정의를 구분하고 있습니다. 여기서 `Item`은 바로 그 구현에 연결된 타입 정의입니다.

## 5. 타입을 넣는 자리가 아니라, 구현을 구별하는 조건이 달라집니다

두 프로그램 모두 원소 타입을 바꿀 수 있다는 점에서는 비슷합니다. 그러나 구현의 머리 부분을 비교하면 차이가 명확해집니다.

```rust
impl GenericIterator<u32> for Counter
impl GenericIterator<String> for Counter
```

제네릭 버전에서는 두 머리 부분이 다릅니다. 반면 연관 타입 버전에서는 원소 타입이 머리 부분에 포함되지 않습니다.

```rust
impl AssociatedIterator for Counter
```

이 구현을 식별한 다음 그 내부의 `Item`을 확인합니다. 이를 표로 압축하면 다음과 같습니다.

| 설계 | 구현을 구별하는 데 쓰이는 타입 정보 | 해당 구현에 연결된 정보 |
| --- | --- | --- |
| `GenericIterator<T>` | `Self`와 `T` | 메서드 구현 |
| `AssociatedIterator` | `Self` | `Item`과 메서드 구현 |

`Self`는 trait을 구현하는 타입이며 예제에서는 `Counter`입니다. 이 표는 현재 두 trait의 구체적인 구현을 비교하기 위한 것입니다. 일반적인 Rust 구현은 포괄 구현과 겹침 여부 등 추가 규칙도 따릅니다. 이 예제처럼 타입 인수가 서로 다른 구체 구현들은 함께 정의할 수 있습니다.

따라서 “연관 타입을 써야만 iterator를 만들 수 있다”는 주장은 맞지 않습니다. `Iterator<T>`라는 설계도 충분히 가능합니다. 그 설계는 같은 구체 타입에 여러 원소 타입의 iterator 구현을 허용합니다. 실제 표준 라이브러리의 `Iterator`는 한 구체 iterator 타입에 원소 타입 하나를 연결하는 계약을 제공합니다.

Rust 공식 교재인 [The Rust Programming Language의 Advanced Traits 장](https://doc.rust-lang.org/book/ch20-02-advanced-traits.html#defining-traits-with-associated-types)도 가상의 `Iterator<T>`와 실제 `Iterator`를 비교하고 있습니다. 두 문법의 표현력이 겹치는 부분을 인정한 다음, 같은 타입에 여러 구현을 둘 수 있는지를 구별합니다. 이것은 실행 속도의 우열이나 메모리 할당 방식의 차이를 말하는 규칙이 아닙니다.

## 6. 사용하는 함수에서도 차이가 드러납니다

연관 타입의 효과는 iterator를 받는 함수를 작성할 때 더 분명해집니다. 특정 iterator에서 원소 하나를 얻어 반환하는 함수가 필요하다고 하겠습니다.

제네릭 trait 버전의 함수는 다음과 같습니다. 이 코드는 앞의 `GenericIterator` 선언과 함께 사용합니다.

```rust
fn take_one<I, T>(iter: &mut I) -> Option<T>
where
    I: GenericIterator<T>,
{
    iter.next()
}
```

함수는 iterator 타입 `I`와 원소 타입 `T`를 매개변수로 받습니다. 같은 `I`에 여러 `GenericIterator<T>` 구현이 있다면 `T`에 따라 호출할 구현이 달라질 수 있습니다. 두 구현을 가진 앞의 `Counter`에 적용하면 `let n: Option<u32> = take_one(&mut counter);`처럼 결과 타입으로 선택할 수 있습니다. 타입 인수는 컴파일할 때 사용하는 정보이며 런타임 함수 인수 두 개가 추가된다는 뜻은 아닙니다.

연관 타입 버전에서는 다음과 같이 쓸 수 있습니다. 이 코드는 `AssociatedIterator` 선언과 함께 사용합니다.

```rust
fn take_one<I>(iter: &mut I) -> Option<I::Item>
where
    I: AssociatedIterator,
{
    iter.next()
}
```

이 함수는 iterator 타입 `I`만 매개변수로 받습니다. 결과에 필요한 타입은 `I`의 `AssociatedIterator` 구현에서 얻는 `I::Item`으로 표현합니다. 단순히 글자가 줄어든 것보다 중요한 점은 **“이 함수의 반환 원소 타입은 입력 iterator의 원소 타입이다”라는 관계가 선언에 직접 들어간다는 것**입니다.

`I::Item`은 여기처럼 해당 trait의 제약이 명확할 때 사용하는 표기입니다. 관계를 완전히 풀어 적으면 `<I as AssociatedIterator>::Item`입니다. 이는 “I가 AssociatedIterator를 구현하면서 정한 Item 타입”을 가리킵니다.

제네릭 버전에서도 제약을 사용해 필요한 관계를 표현할 수 있습니다. 연관 타입의 가치는 모든 관계를 새로 표현하게 만드는 데만 있는 것이 아니라, 한 구현에 종속되는 타입을 API의 계약으로 고정하고 그 타입을 이름으로 참조하게 하는 데 있습니다.

## 7. `Item = u32`는 구현을 바꾸는 대입이 아닙니다

이제 다음 함수의 문법을 읽을 수 있습니다.

```rust
fn take_number<I>(iter: &mut I) -> Option<u32>
where
    I: AssociatedIterator<Item = u32>,
{
    iter.next()
}
```

이 함수는 모든 iterator를 받지 않습니다. 이미 `AssociatedIterator`를 구현하고 있고, **그 구현의 `Item`이 `u32`인 타입만** 받습니다. `<Item = u32>`는 기존 구현의 원소 타입을 바꾸지 않습니다. 함수가 받아들일 수 있는 타입을 제한하는 동등성 제약입니다.

구현 내부의 `type Item = u32;`와 비교하면 역할이 구분됩니다. 구현 안에서는 `Item`을 정의하고, 함수의 제약에서는 그 정의가 `u32`인지 요구합니다. 그래서 타입 인수를 쓰는 꺾쇠괄호 안에 `=`가 나타나더라도 값을 변경하는 대입문으로 읽으면 안 됩니다.

타입 이름 두 개를 모두 제네릭 매개변수로 선언한 `trait Some<T, Output>`과, `trait Some<T> { type Output; }`도 같은 기준으로 구분됩니다. 전자는 `Self`, `T`, `Output`을 함께 사용해 구현을 구별합니다. 후자는 `Self`와 `T`로 정해지는 구현에서 `Output`을 정의합니다. 따라서 후자도 서로 다른 `T`에 대해서는 서로 다른 `Output`을 정의할 수 있습니다. “연관 타입은 한 타입 전체에 영원히 하나뿐이다”라는 뜻은 아닙니다.

## 8. Future의 Output과 async 함수로 돌아갑니다

`Iterator::Item`은 반복에서 내놓는 원소 타입입니다. `Future::Output`은 비동기 작업이 완료됐을 때 내놓는 결과 타입입니다. 역할의 이름이 달라졌지만 구현에 결과 타입을 연결한다는 구조는 같습니다.

```rust
async fn answer() -> u32 {
    42
}
```

이 함수를 호출할 때 곧바로 받는 것은 `42`가 아니라 컴파일러가 생성한 Future 값입니다. 그 구체적인 Future 타입의 구현에는 `Output = u32`라는 관계가 있습니다. 타입 관계를 명시적으로 드러내면 다음과 같은 함수로 이해할 수 있습니다.

```rust
use std::future::Future;

fn answer() -> impl Future<Output = u32> {
    async { 42_u32 }
}
```

`impl Future`는 함수가 실제로 반환하는 구체 타입의 이름을 공개하지 않으면서 Future 계약을 보장하는 반환 타입 문법입니다. `Output = u32`는 그 구현의 완료 결과 타입을 추가로 보장합니다. `impl`이라는 값을 반환하는 것도, `u32`를 Future에 런타임 인수로 전달하는 것도 아닙니다. 반환 위치의 `impl Trait`에 대한 언어 규칙은 [Rust Reference의 impl Trait 설명](https://doc.rust-lang.org/reference/types/impl-trait.html#abstract-return-types)에 정리되어 있습니다.

여기서 타입 관계만 검사하는 작은 프로그램을 만들 수 있습니다.

```rust
use std::future::Future;

async fn answer() -> u32 {
    42
}

fn accepts_u32_future<F: Future<Output = u32>>(_: F) {}

fn main() {
    let future = answer();
    accepts_u32_future(future);
    println!("Future<Output = u32> 확인");
}
```

이 프로그램은 컴파일되고 확인 문구를 출력합니다. `accepts_u32_future`의 제약을 만족한다는 사실을 확인한 것입니다. Future를 실행하거나 결과 `42`를 얻은 것은 아닙니다. 함수는 받은 Future를 실행하지 않고 함수가 끝날 때 버립니다.

작업을 진행하려면 실행기가 Future의 `poll`을 호출해야 합니다. 이 예제의 Future는 실행되면 `Poll::Ready(42)`로 완료 결과를 전달합니다. 실제 실행 규약은 [표준 라이브러리의 Future 문서](https://doc.rust-lang.org/std/future/trait.Future.html)가 정의합니다. 제네릭과 연관 타입의 문법은 그 실행 과정에서 어떤 결과 타입을 다루는지 컴파일러가 확인하도록 해 줍니다.

`Iterator<T>`를 읽을 때는 T도 구현을 선택하는 조건이라는 점을, `Iterator<Item = T>`를 읽을 때는 이미 선택할 iterator 구현의 Item에 조건을 붙인다는 점을 보면 됩니다. 두 표기의 차이를 판단하는 질문은 “어디에 타입을 적었는가”보다 “이 타입이 구현 선택의 조건인가, 선택한 구현에서 따라 나오는 타입인가”입니다.

## 예제 검증 범위

본문의 일반 메서드, 단일 제네릭 구현, 두 제네릭 구현의 명시적 선택, 연관 타입 구현과 제네릭 보조 함수, Future 타입 제약 예제를 Rust 1.95.0에서 컴파일하고 실행했습니다. 모호한 `next()` 호출은 E0283으로, 연관 타입만 바꾼 중복 구현은 E0119로 실패하는 것을 별도로 확인했습니다. 이러한 실패는 본문에서 설명한 계약의 차이를 확인하기 위한 것입니다.

이 검증은 타입 관계와 예제 출력에 대한 확인입니다. 비동기 실행기나 I/O 처리는 구현하지 않았으며, Future 예제도 작업 완료를 검증하는 실행기 테스트는 아닙니다.
