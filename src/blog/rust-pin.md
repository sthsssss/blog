---
title: "Rust의 Box, Pin과 poll: Future의 소유권과 실행을 연결하기"
slug: "rust-pin"
pubDate: 2026-11-11
description: "Box의 소유권과 역참조에서 빌림·복사·이동이 갈리는 이유를 Future의 생성, Pin의 위치 계약, poll의 실행과 Drop까지 연결합니다. 실행 예제와 컴파일 오류를 함께 검증합니다."
author: "Tae Shim"
image:
  url: "/images/rust-pin.svg"
  alt: "이동할 수 있는 Pin 포인터와 같은 위치에 유지되는 Future 값의 구분"
tags: ["rust", "async", "memory", "ownership"]
---

Future는 아직 완료되지 않은 작업의 상태를 나타내는 값이고, `poll`은 그 값을 빌려 작업을 진행하는 메서드입니다. `Pin`은 그 과정에서 필요한 저장 위치의 계약을 표현합니다. 세 요소를 함께 보면 `hello()`를 호출한 뒤 왜 `pin!`을 거쳐 `poll`을 호출하는지, 각 줄이 무엇을 소유하고 무엇을 실행하는지 구분할 수 있습니다.

이 글은 먼저 한 번에 완료되는 비동기 함수를 직접 실행합니다. 그 호출에서 실제로 사용한 `poll`의 선언을 읽고, 왜 일반 가변 참조 대신 고정된 참조가 필요한지 메모리 관계로 설명합니다. 이후 작업이 중단되는 경우로 확장해 같은 Future의 상태가 어떻게 이어지고, 실행기는 언제 다시 poll해야 하는지 연결합니다. 예제는 외부 런타임 없이 실행하므로, 평소 `.await`와 실행기가 처리하는 역할을 직접 관찰할 수 있습니다.

2026-11-14 개정: Future 생성과 poll, Waker와 Drop에 이어 Box의 기본 동작과 역참조의 빌림·복사·이동을 보강했습니다. Box에서 Future를 꺼내 고정한 뒤 실행하는 전체 예제도 추가했습니다.

## 1. Future를 만드는 호출과 본문을 실행하는 호출

다음은 출력하고 숫자 42로 완료되는 함수입니다. `async fn hello() -> u32`의 `u32`는 작업의 완료 결과 타입입니다. `hello()` 자체는 그 작업을 나타내는 Future 값을 반환합니다. `future` 변수는 이미 초기화된 상태이며, 나중에 42가 채워질 빈 공간이 아닙니다.

```rust
use std::future::Future;
use std::pin::pin;
use std::task::{Context, Poll, Waker};

async fn hello() -> u32 {
    println!("hello 본문 실행");
    42
}

fn main() {
    let future = hello();
    println!("1. Future 생성");

    let mut pinned = pin!(future);
    println!("2. 고정된 참조 준비");

    let mut cx = Context::from_waker(Waker::noop());
    println!("3. poll 호출 직전");
    let result = pinned.as_mut().poll(&mut cx);
    println!("4. poll 반환: {result:?}");
    assert_eq!(result, Poll::Ready(42));
}
```

실행 결과는 다음과 같습니다.

```text
1. Future 생성
2. 고정된 참조 준비
3. poll 호출 직전
hello 본문 실행
4. poll 반환: Ready(42)
```

본문의 출력은 Future를 만들 때도, 고정된 참조를 마련할 때도 발생하지 않습니다. `poll`을 호출하는 동안 본문이 실행되고 42로 완료됩니다. `poll`은 이 결과를 `Poll::Ready(42)`로 감싸 반환하며, `result`가 그 반환값을 소유합니다. 기존 Future 변수가 숫자로 변하는 것은 아닙니다.

이 예제의 poll은 main을 실행 중인 스레드의 평범한 메서드 호출입니다. 새 스레드로 작업을 보내는 코드가 없습니다. “비동기 함수의 본문을 실행한다”는 사실과 “다른 스레드에서 실행한다”는 사실은 별개입니다.

또한 Future를 반환하는 모든 일반 함수의 본문이 지연되는 것은 아닙니다. `fn make() -> impl Future<Output = u32>`로 선언한 일반 함수는 호출할 때 본문을 실행해 Future를 만듭니다. 이 예제에서 본문이 지연되는 근거는 함수가 `async fn`으로 선언되어 있다는 점입니다. 호출 표현식만으로 구분되지 않으면 함수 선언과 반환 타입을 확인해야 합니다.

아직 세 줄의 준비 코드가 남아 있습니다. `pin!`은 작업 본체에 접근하는 참조를 마련하고, `Context`는 재실행 알림 수단을 전달하며, `as_mut()`은 이번 호출 동안만 사용할 참조를 다시 빌립니다. 각 역할은 poll의 선언에서 출발합니다.

## 2. poll은 상태 조회가 아니라 작업을 진행하는 메서드입니다

Rust 표준 라이브러리의 [Future 문서](https://doc.rust-lang.org/std/future/trait.Future.html)는 실행기와 Future 구현이 따라야 하는 인터페이스를 정의합니다. 필요한 import를 제외한 trait 선언은 다음과 같습니다.

```rust
pub trait Future {
    type Output;

    fn poll(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
    ) -> Poll<Self::Output>;
}
```

`Self`는 이 trait을 구현하는 구체 타입입니다. hello의 경우 컴파일러가 생성한 상태 머신 타입이 해당합니다. `Self::Output`은 그 구현의 완료 결과 타입이며, 이 예제에서는 u32입니다. `poll`은 `self: Pin<&mut Self>`로 작업 본체를 빌리고, `cx`로 현재 실행의 알림 정보를 받으며, 이번 호출의 결과를 `Poll<u32>`로 반환합니다.

| 선언의 부분 | hello 예제에서 뜻하는 것 |
| --- | --- |
| `Self` | hello의 실행 상태를 보관하는 Future 타입 |
| `Pin<&mut Self>` | 그 Future를 고정 계약 아래에서 가변으로 빌리는 접근 |
| `&mut Context<'_>` | 현재 호출에서 사용할 Context의 가변 빌림. `'_`는 여기서 추론하는 수명 |
| `Self::Output` | 완료 결과 타입 u32 |
| `Poll<Self::Output>` | 이번 시도가 미완료인지, 완료 결과를 얻었는지 나타내는 반환값 |

Poll의 핵심 구조는 다음과 같습니다.

```rust
pub enum Poll<T> {
    Pending,
    Ready(T),
}
```

`Ready(T)`에는 완료 결과가 들어 있습니다. `Pending`에는 완료 결과가 없습니다. 하지만 Pending이 나왔다고 해서 아무 작업도 하지 않았다는 뜻은 아닙니다. Future는 일부 계산을 수행하고, I/O 대기를 등록하거나 내부 상태를 갱신한 다음 아직 끝낼 수 없어 Pending을 반환할 수 있습니다. 따라서 poll을 단순히 완료 여부를 읽는 조회 메서드로 이해하면 본문이 실행되는 시점을 놓치게 됩니다.

Pending은 오류도 아닙니다. 작업이 실패할 수 있다면 Output을 `Result<T, E>`로 정할 수 있으며, 오류로 완료한 경우는 `Poll::Ready(Err(error))`입니다. Ready는 그 작업이 완료됐다는 뜻이지, 업무 결과가 항상 성공했다는 뜻은 아닙니다.

한 번의 poll이 반드시 코드 한 줄이나 await 하나만 처리하는 것도 아닙니다. 즉시 완료되는 await를 여러 번 지나 마지막까지 진행할 수 있습니다. 기다려야 하는 지점에 도달하면 Pending으로 돌아옵니다. 호출자는 그 반환을 받은 뒤 다른 작업을 실행할 수 있습니다. poll 구현이 내부에서 긴 계산이나 blocking I/O를 계속하면 호출 스레드도 그동안 돌아오지 못하므로, 실행기는 작업들 사이에서 제어를 나눌 수 없습니다.

이제 실행할 대상을 빌리는 인자에 주목할 수 있습니다. `&mut Self`만 받아도 상태는 변경할 수 있는데, Future는 왜 `Pin`까지 요구할까요? 이 질문에는 소유권과 저장 위치를 나누어 답해야 합니다.

## 3. `let a = future`는 무엇을 옮기는가

다음 코드에서 `hello()`는 새로운 Future 값을 만들고, `future`가 그 값을 소유합니다.

```rust
async fn hello() {
    println!("hello");
}

fn main() {
    let future = hello();
    let a = future;
    drop(a);
}
```

이 프로그램은 아무것도 출력하지 않습니다. Future를 만들고 소유권을 `a`로 옮긴 뒤 버렸으며, 본문을 실행하는 `poll`은 한 번도 호출하지 않았기 때문입니다. `let a = future`는 Future를 하나 더 만드는 호출이 아닙니다. 원래 `future` 변수는 이동 이후 사용할 수 없습니다.

여기서 소유권 이동은 어느 변수를 통해 값을 계속 사용할 수 있는지 정하는 언어 규칙입니다. 실제 실행 코드에서 값의 바이트가 다른 주소로 복사되는지는 컴파일러 최적화와 저장 방식에 따라 달라질 수 있습니다. 따라서 `let a = future`가 있다고 해서 반드시 서로 다른 주소 두 개가 관측되는 것은 아닙니다. 반대로, 소유권을 옮겨도 주소가 우연히 같게 나왔다고 해서 주소 유지가 언어적으로 보장되는 것도 아닙니다.

`Pin`이 필요한 코드는 이 우연에 의존할 수 없습니다. 나중에 컴파일러 설정이 달라져도, 실행기가 작업을 보관하는 방식을 바꿔도, 특정 값의 주소가 유지된다는 계약이 필요합니다. 그러려면 먼저 “이동하는 값이 무엇인가”를 정확히 구분해야 합니다.

## 4. Box는 힙의 값과 그 저장 공간을 소유합니다

Future의 주소를 논하기 전에, Box가 무엇을 저장하고 소유하는지 확인하겠습니다. 다음 코드는 숫자 하나를 힙에 저장합니다.

```rust
fn main() {
    let mut owner = Box::new(42_u32);
    println!("처음 값: {}", *owner);

    *owner = 100;
    let borrowed: &u32 = &*owner;
    println!("빌려서 읽은 값: {borrowed}");

    let other = owner;
    println!("새 소유자로 읽은 값: {}", *other);
}
```

출력은 `처음 값: 42`, `빌려서 읽은 값: 100`, `새 소유자로 읽은 값: 100`입니다. Box::new는 숫자를 저장할 힙 공간을 마련하고, 그 숫자와 할당을 소유하는 Box 값을 반환합니다. owner 변수에 들어 있는 것은 이 Box 값입니다.

```text
owner: Box<u32> ──→ 힙에 저장된 u32 값
```

`*owner = 100`은 힙의 숫자를 바꿉니다. `&*owner`는 그 숫자를 빌리는 참조를 만듭니다. borrowed는 할당을 소유하지 않으며, 이 참조의 마지막 사용이 끝나도 숫자는 그대로 남습니다. 그 뒤 `let other = owner`는 Box의 소유권을 옮깁니다. owner는 더 이상 사용할 수 없고, other가 같은 힙 할당을 소유합니다.

other의 수명이 끝나면 소유하던 값을 정리하고 할당을 해제합니다. 값의 타입에 Drop 구현이 있다면 그 정리도 수행합니다. u32에는 사용자 정의 정리 동작이 없지만 할당은 해제됩니다. 따라서 Box와 빌린 참조는 둘 다 대상을 가리키더라도 수명 관리 책임이 다릅니다.

이 예제에서 `let other = owner`는 숫자를 복사한 것이 아닙니다. 숫자가 Copy인지와 별개로 대입문의 오른쪽 값은 Box<u32>이며, Box는 Copy가 아닙니다. 반대로 오른쪽을 `*owner`로 쓰면 대상이 숫자로 바뀝니다. 이 차이를 다음 절에서 확인합니다.

## 5. 포인터를 옮겨도 포인터가 가리키는 값은 그대로일 수 있습니다

`Box<T>`는 힙에 저장된 `T`를 소유하는 포인터입니다. 아래 프로그램에서 이동하는 것은 Box 값입니다.

```rust
struct Buffer {
    bytes: [u8; 3],
}

fn main() {
    let owner = Box::new(Buffer { bytes: [10, 20, 30] });
    let before: *const Buffer = &*owner;

    let new_owner = owner;
    let after: *const Buffer = &*new_owner;

    assert_eq!(before, after);
    assert_eq!(new_owner.bytes[0], 10);
    println!("힙의 배열 주소 유지: {}", before == after);
}
```

출력은 `힙의 배열 주소 유지: true`입니다. `new_owner`로 Box의 소유권을 옮겨도 배열을 포함한 Buffer는 같은 힙 할당 안에 남아 있습니다. Buffer에는 Copy를 구현하지 않았으므로, 뒤에서 본체를 꺼내는 예제와 단순 복사를 구분할 수 있습니다. 이 예제는 주소를 비교할 뿐, 원시 포인터를 역참조하지 않습니다.

```text
이동 전: owner     ──→ 힙의 배열 [10, 20, 30]
이동 후: new_owner ──→ 같은 힙의 배열 [10, 20, 30]
```

그렇다면 Box만 사용하면 충분할 것 같습니다. 하지만 Box가 제공하는 것은 소유권과 힙 할당이며, 안의 값을 꺼내거나 교체하는 연산을 금지하지는 않습니다. 예를 들어 `let buffer = *new_owner;`처럼 Box 내부의 Buffer 값을 밖으로 옮길 수 있습니다. 힙에 놓았다는 사실과 그 값이 거기에서 계속 살아 있어야 한다는 계약은 다릅니다.

Future를 힙에 저장하는 실행기에서도 이 구분이 중요합니다. 실행기가 보관하는 포인터를 다른 큐로 옮기는 것은 괜찮아야 합니다. 그러나 이미 실행되어 자신의 주소에 의존하는 상태를 가진 Future 본체를 할당 밖으로 꺼내 옮기는 것은 막아야 할 수 있습니다.

## 6. 역참조는 저장 위치를 나타내며, 사용 문맥이 빌림과 이동을 결정합니다

`let data = *other;`를 이해하려면 `*other`와 그것을 사용하는 let 선언을 나눠 읽어야 합니다. `*other`는 포인터가 가리키는 값의 저장 위치를 나타냅니다. 그 위치를 빌릴 수도 있고, 내용을 변경할 수도 있으며, 값을 읽어 새 변수의 초기값으로 사용할 수도 있습니다.

Rust의 언어 규칙을 정리한 [Rust Reference의 표현식 설명](https://doc.rust-lang.org/reference/expressions.html#place-expressions-and-value-expressions)에서는 이런 저장 위치를 나타내는 표현식을 place expression으로 구분합니다. 변수 이름, 필드 접근, 역참조가 여기에 해당합니다. `*`만 보고 이동이라고 판단하지 않고, 그 표현식이 어디에 사용됐는지 봐야 합니다.

다음 프로그램은 같은 Box 안의 Data를 먼저 빌려 읽고 수정한 다음, 마지막에 밖으로 옮깁니다. Data는 Copy를 구현하지 않았습니다. 필드가 u32라고 해서 구조체 자체가 자동으로 Copy가 되지는 않습니다.

```rust
struct Data {
    value: u32,
}

fn main() {
    let mut other = Box::new(Data { value: 42 });

    {
        let borrowed: &Data = &*other;
        println!("공유 빌림: {}", borrowed.value);
    }
    {
        let borrowed_mut: &mut Data = &mut *other;
        borrowed_mut.value = 100;
    }
    println!("빌림 이후 Box로 읽기: {}", other.value);

    let data: Data = *other;
    println!("이동한 값: {}", data.value);
}
```

실행 결과는 다음과 같습니다.

```text
공유 빌림: 42
빌림 이후 Box로 읽기: 100
이동한 값: 100
```

`&*other`는 Data를 이동하지 않고 공유 참조를 만듭니다. `&mut *other`도 이동하지 않고 가변 참조를 만듭니다. 각 빌림이 끝나면 원래 소유자인 Box를 통해 값을 계속 사용할 수 있습니다. 반면 `let data: Data = *other`는 그 위치의 Data 값을 새 변수의 초기값으로 가져옵니다. Data는 Copy가 아니므로 이 연산은 이동입니다.

따라서 마지막 이동 뒤에 `println!("{}", other.value);`를 추가하면 E0382가 발생합니다. other가 가리키던 Data는 이미 꺼냈으므로 같은 값이 여전히 들어 있다고 취급할 수 없습니다. 이는 컴파일러가 사용을 막는 것이지 포인터를 null로 바꾸거나 실행 중 유효성을 검사하는 방식이 아닙니다. 새로운 값으로 다시 초기화하는 별도 동작 없이 예전 값을 읽을 수 없다는 뜻입니다.

| 표현식 | 대상에 수행하는 일 | 기존 대상 값 |
| --- | --- | --- |
| `&*other` | 공유 빌림 | 그대로 존재 |
| `&mut *other` | 가변 빌림 | 그대로 존재하며 빌린 쪽에서 변경 가능 |
| `let data = *other`에서 Data가 비-Copy | 값 이동 | 꺼내졌으므로 기존 위치에서 다시 읽을 수 없음 |
| `let n = *number_box`에서 대상이 u32 | 값 복사 | 기존 숫자도 그대로 존재 |

마지막 행의 경우를 실행해 보겠습니다.

```rust
fn main() {
    let number_box = Box::new(42_u32);
    let n = *number_box;

    println!("복사한 숫자: {n}");
    println!("Box 안의 숫자: {}", *number_box);
}
```

두 출력 모두 42입니다. 대입문 오른쪽은 Box가 아니라 그 안의 u32이며, u32는 Copy이므로 값이 복사됩니다. `*` 문법이 같아도 대상 타입의 Copy 여부와 주변 문맥에 따라 결과가 달라집니다.

## 7. 빌린 참조에서는 왜 같은 이동을 할 수 없는가

이번에는 Box를 일반 참조로 바꿉니다. 다음은 의도적으로 컴파일에 실패하는 전체 예제입니다.

```rust
struct Data {
    value: u32,
}

fn main() {
    let original = Data { value: 42 };
    let reference = &original;
    let data = *reference;
    println!("{}", data.value);
}
```

이 코드는 E0507로 거절됩니다. `reference`는 Data를 빌려서 가리킬 뿐, 원래 소유자의 값을 가져갈 권한은 없기 때문입니다. 가변 참조 `&mut Data`라도 비-Copy Data를 `let data = *reference`로 직접 꺼내 원래 위치를 비워 둘 수는 없습니다. 내용을 바꿀 권한과 원래 값을 꺼내 위치를 비워 둘 권한은 다릅니다.

반면 Box는 대상 값을 소유하며, Rust는 Box의 역참조 위치에서 값을 이동시키는 동작을 특별히 지원합니다. [Rust Reference의 Box 설명](https://doc.rust-lang.org/reference/special-types-and-traits.html#boxt)에는 이 동작이 언어 차원에서 지원된다고 명시되어 있습니다. 모든 스마트 포인터가 Box와 같은 이동을 허용하는 것은 아닙니다. 단지 Deref를 구현한 사용자 정의 포인터라고 해서 Box처럼 값을 꺼낼 수 있다고 일반화해서는 안 됩니다.

일반 참조를 통해서도 Copy 값은 복사할 수 있습니다. 또한 `&mut T`로 기존 값을 새 값으로 교체하면서 꺼내는 방법은 있습니다. 교체는 원래 위치에 유효한 새 값을 남기므로, 위치를 비우는 직접 이동과 조건이 다릅니다. 이 구분은 바로 다음 mem::replace 예제로 이어집니다.

## 8. 일반적인 `&mut T`는 값을 바꾸는 것뿐 아니라 꺼내는 것도 허용합니다

가변 참조를 받으면 그 위치의 필드를 수정할 수 있습니다. 더 나아가 기존 값을 다른 값으로 교체하고, 기존 값을 반환받을 수도 있습니다.

```rust
use std::mem;

#[derive(Debug)]
struct State {
    count: u32,
}

fn replace_state(slot: &mut State) -> State {
    mem::replace(slot, State { count: 99 })
}

fn main() {
    let mut state = State { count: 1 };
    let old = replace_state(&mut state);

    println!("꺼낸 값: {}", old.count);
    println!("원래 위치의 값: {}", state.count);
}
```

실행 결과는 다음과 같습니다.

```text
꺼낸 값: 1
원래 위치의 값: 99
```

`mem::replace`는 참조가 가리키는 위치에 새 값을 넣고, 그 자리에 있던 값을 반환합니다. 이 동작은 메모리 안전하며 일반적인 자료구조에는 유용합니다. 그러나 기존 값이 “내가 지금 이 주소에 있다”는 사실에 의존하고 있다면, 값 전체를 꺼내는 동작은 그 전제를 깨뜨릴 수 있습니다.

따라서 “잠시 빌려주는 동안 다른 코드가 접근하지 못한다”는 `&mut T`의 독점성만으로는 충분하지 않습니다. 그 참조를 받은 코드 자신이 안전한 `mem::replace`를 호출할 수 있기 때문입니다. 주소에 의존하는 타입에는 **상태를 진행시키는 접근은 제공하면서, 값 전체를 꺼내는 접근은 제한하는 인터페이스**가 필요합니다.

## 9. 값이 자기 내부를 가리키면 주소가 의미를 갖습니다

이제 주소가 바뀌면 문제가 되는 상태를 가정해 보겠습니다. 어떤 작업 값 안에 바이트 배열이 있고, 같은 값 안의 포인터가 그 배열의 원소를 가리킵니다. 아래 주소는 설명용 숫자이며 Rust 타입의 실제 레이아웃을 나타내지 않습니다.

```text
작업 값 A: 주소 0x1000
┌────────────────────────────────┐
│ 배열: [10, 20, 30]              │ ← 배열 시작 주소를 0x1010이라고 가정
│ 내부 포인터: 0x1010             │ ──→ 자기 배열
└────────────────────────────────┘
```

이 상태를 주소 `0x2000`으로 옮기면서 저장된 포인터 값을 그대로 복사하면 문제가 생깁니다.

```text
옮겨진 작업 값 A: 주소 0x2000
┌────────────────────────────────┐
│ 배열: [10, 20, 30]              │ ← 이제 배열 시작은 0x2010
│ 내부 포인터: 0x1010             │ ──→ 여전히 예전 위치
└────────────────────────────────┘
```

일반적인 바이트 이동은 내부 포인터에 저장된 숫자를 새 배열 주소로 자동 수정하지 않습니다. 예전 위치가 무효화된 뒤 그 포인터를 사용하면 잘못된 접근이 됩니다. 이처럼 자기 내부를 가리키는 상태를 자기 참조라고 합니다.

보통의 안전한 Rust 코드가 이런 위험한 구조체를 마음대로 만들 수 있다는 뜻은 아닙니다. 빌림 검사가 많은 경우를 거절합니다. 여기서는 컴파일러가 만드는 비동기 상태 머신이나, 별도의 안전성 조건을 지키며 작성하는 저수준 자료구조가 왜 추가 계약을 필요로 하는지 설명하고 있습니다. 위 그림은 위험한 포인터를 실제로 역참조하는 실험이 아닙니다.

비동기 함수에는 이와 관련된 자연스러운 상황이 있습니다. 지역 배열을 빌린 뒤 다른 작업을 기다리고, 기다림이 끝나면 그 참조를 다시 사용하는 경우입니다.

```rust
// 상태 관계를 설명하는 발췌 코드입니다.
async fn inspect() -> u8 {
    let bytes = [10_u8, 20, 30];
    let first = &bytes[0];

    wait_once().await;

    *first
}
```

`wait_once()`가 아직 완료되지 않으면 `inspect`도 실행을 잠시 멈춥니다. 재개한 뒤 `*first`를 읽으려면 배열과 참조에 필요한 상태를 보존해야 합니다. 지역 변수가 일반 함수처럼 호출이 끝나면서 사라지지 않고, 중단을 견디는 Future 상태의 일부가 되는 것입니다. 실제 생성 레이아웃은 컴파일러가 결정하지만, Rust는 이런 코드도 안전하게 지원할 수 있는 실행 계약을 필요로 합니다.

Future가 생성된 직후에는 이런 실행 중 상태가 아직 만들어지지 않았을 수 있습니다. 그래서 처음의 `let a = future`처럼 고정하기 전에 소유권을 옮길 수 있습니다. 실행을 시작하기 전에 최종 저장 위치를 정하고, 그 뒤 주소에 의존할 수 있도록 약속하는 것이 필요한 순서입니다.

## 10. `Pin`은 포인터를 감싸고, 그 대상에 대한 접근을 제한합니다

이제 `Pin<&mut F>`를 읽을 수 있습니다. `F`는 Future 본체의 타입이고, `&mut F`는 그 본체를 가리키는 가변 참조입니다. `Pin`은 이 포인터를 감싸는 타입입니다. 위치 보장이 필요한 `F`에 대해서는 이 포인터를 통해 값을 꺼내 옮길 수 있는 안전한 접근을 제공하지 않습니다.

```text
변수 pinned
┌─────────────────────┐          고정된 저장 위치
│ Pin<&mut F>         │ ──────→ ┌──────────────────┐
│ Future를 가리키는 참조│         │ Future 본체 F    │
└─────────────────────┘         │ 실행 상태와 데이터│
                                └──────────────────┘
```

중요한 것은 `pinned` 변수의 위치와 Future 본체의 위치가 다르다는 점입니다. 포인터를 다른 변수로 옮겨도 그 포인터가 가리키는 본체가 함께 옮겨지는 것은 아닙니다. `Pin`은 포인터 변수의 주소를 영구히 고정하는 기능이 아닙니다.

고정은 읽기 전용이라는 뜻도 아닙니다. Future는 실행되면서 진행 상태를 변경합니다. 다만 위치 보장이 필요한 타입에서 제한 없는 `&mut T`를 꺼내 주면 값 전체를 옮기는 연산까지 가능해지므로, 고정 계약을 유지하는 메서드를 통해 필요한 변경을 수행합니다. 구조체 필드에 대한 고정된 접근을 설계하는 문제는 별도의 projection 규칙을 필요로 하며, 이 글의 실험에서는 직접 구현하지 않습니다.

또한 Pin에는 메모리를 특별히 잠그는 런타임 장치가 없습니다. 안전한 생성 방법과 접근 API, 그리고 저수준 코드가 지켜야 하는 계약을 결합합니다. `unsafe` 코드가 약속을 어기면 Pin이 실행 중에 감지하고 복구해 주지 않습니다. 따라서 단지 타입을 억지로 만들어 붙이는 것만으로 안전해지지는 않습니다.

이 계약은 “지금 잠깐 주소가 같다”보다 강합니다. 위치 보장이 필요한 값을 고정했다면 그 값은 그 자리에서 파괴될 때까지 유효하게 유지되어야 하며, 저장 공간을 먼저 무효화해서는 안 됩니다. 포인터를 한 번 사용한 뒤 버렸다고 해서 고정된 본체를 다시 자유롭게 옮겨도 되는 것은 아닙니다. 이 수명 전체의 조건을 지키도록 안전한 고정 API가 설계되어 있습니다.

## 11. `Unpin`은 고정 해제 명령이 아니라 타입의 성질입니다

모든 타입이 자신의 주소에 의존하지는 않습니다. `u32`는 숫자 값 자체가 중요하며, 주소를 바꾸더라도 숫자의 의미는 유지됩니다. 이런 타입에도 Pin 인터페이스를 사용할 수 있어야 하므로 Rust에는 `Unpin`이라는 표시 trait이 있습니다.

`T: Unpin`은 T가 Pin의 위치 보장에 의존하지 않는다는 뜻입니다. 이 조건이 있으면 `Pin<&mut T>`에서 일반 `&mut T`를 안전하게 얻어 값의 교체 등을 할 수 있습니다. 이름과 달리 어떤 값의 고정을 해제하는 함수나 실행 중 상태 전환이 아닙니다. 표준 라이브러리의 [`Unpin` 문서](https://doc.rust-lang.org/std/marker/trait.Unpin.html)는 이 예외가 타입의 계약임을 설명합니다.

```rust
use std::pin::Pin;

fn main() {
    let mut number = 10_u32;
    let pinned = Pin::new(&mut number);

    let ordinary: &mut u32 = pinned.get_mut();
    let old = std::mem::replace(ordinary, 20);

    println!("꺼낸 숫자: {old}, 현재 숫자: {number}");
}
```

이 프로그램은 `꺼낸 숫자: 10, 현재 숫자: 20`을 출력합니다. `u32: Unpin`이므로 일반 가변 참조를 얻는 것이 허용됩니다. 따라서 “Pin에 넣었으니 어떤 타입이든 절대 이동할 수 없다”는 설명은 정확하지 않습니다.

반대로 `!Unpin`은 Unpin을 구현하지 않는다는 뜻의 표기입니다. 일반적인 `async fn`과 `async` 블록이 생성하는 Future는 Unpin이라고 가정할 수 없습니다. 주소 의존성이 없는 단순한 본문이라도 직접 `Pin::new(&mut future)`를 사용하면 Unpin 제약 때문에 거절될 수 있습니다. 그런 Future에는 `pin!`이나 `Box::pin`처럼 실제 위치 보장을 마련하는 경로를 사용합니다.

`!Unpin`이라는 성질 자체가 생성 순간부터 모든 이동을 금지하지는 않습니다. 고정하기 전의 값은 옮길 수 있습니다. 고정된 뒤 그 보장을 이용해 접근하는 단계에서 제한이 중요해집니다. 또한 모든 Future가 `!Unpin`인 것도 아닙니다. 직접 구현한 Future 중에는 주소 보장이 필요 없어 Unpin인 타입도 있습니다.

## 12. 직접 구현한 poll에서 상태 변경을 확인합니다

Unpin인 타입은 Pin을 통해 일반 가변 참조를 얻을 수 있습니다. 이 성질을 이용하면 컴파일러가 만든 Future 대신 작은 구조체로 poll의 동작을 직접 확인할 수 있습니다. 아래 OneStep은 남겨 둔 숫자를 한 번 반환하는 작업입니다.

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll, Waker};

struct OneStep {
    value: Option<u32>,
}

impl Future for OneStep {
    type Output = u32;

    fn poll(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<u32> {
        let state: &mut OneStep = self.get_mut();
        let value = state.value.take().expect("완료된 작업을 다시 poll함");
        println!("poll 내부: 결과를 꺼내 상태를 None으로 변경");
        Poll::Ready(value)
    }
}

fn main() {
    let mut task = OneStep { value: Some(42) };
    let mut cx = Context::from_waker(Waker::noop());
    let result = Pin::new(&mut task).poll(&mut cx);

    assert_eq!(result, Poll::Ready(42));
    assert_eq!(task.value, None);
    println!("반환값: {result:?}, 남은 상태: {:?}", task.value);
}
```

출력은 다음과 같습니다.

```text
poll 내부: 결과를 꺼내 상태를 None으로 변경
반환값: Ready(42), 남은 상태: None
```

OneStep은 주소에 의존하는 필드를 갖지 않으며 자동으로 Unpin입니다. 그래서 `Pin::new(&mut task)`와 `self.get_mut()`을 사용할 수 있습니다. `get_mut()`이 반환한 참조는 기존 task를 가리킵니다. 그 참조를 통해 `Option::take()`를 호출하면 Some 안의 값을 얻고 원래 필드는 None이 됩니다. poll이 반환한 결과와 작업 객체의 상태가 별도로 존재한다는 사실이 여기서 드러납니다.

이 코드는 Pin이 있으면 상태 변경이 금지된다는 해석도 바로잡습니다. 상태는 실제로 변했습니다. 위치 보장이 필요한 타입에 대해 제한 없는 가변 접근을 꺼내 주지 않는 것이 Pin의 역할이며, Unpin인 OneStep은 그 제한이 필요하지 않습니다. 컴파일러가 생성한 async Future에 이 코드를 그대로 적용해 get_mut을 호출할 수 있다고 일반화해서는 안 됩니다.

OneStep은 한 번 완료된 뒤 다시 poll하면 명시적으로 panic하도록 작성했습니다. 이는 이 예제의 선택입니다. 모든 Future가 완료 뒤 같은 방식으로 동작하는 것은 아니므로 실행기는 Ready를 받은 작업을 다시 poll하지 않아야 합니다.

## 13. `pin!(future)`에서 값과 참조는 어떻게 바뀌는가

앞의 Future를 직접 실행하기 위해 다음 코드를 작성한다고 하겠습니다.

```rust
let future = hello();
let mut pinned = std::pin::pin!(future);
```

여기서 `!`는 매크로 호출 표시입니다. `Pin`은 타입의 이름이고, `pin!`은 로컬 저장 공간을 사용하는 코드를 구성하는 매크로입니다. 이름이 비슷하지만 하나는 접근 계약을 나타내는 타입이고 다른 하나는 그 접근을 마련하는 생성 수단입니다.

첫 줄의 `future`는 Future 본체를 소유합니다. 둘째 줄은 그 값을 매크로가 마련하는 로컬 저장 위치로 이동하고, 그곳에 놓인 Future를 가리키는 `Pin<&mut F>`를 만듭니다. `pinned`가 직접 소유하는 것은 이 참조를 감싼 값이며, Future 본체는 로컬 저장 위치에서 관리됩니다. 기존 `future` 변수는 이미 이동했으므로 다시 사용할 수 없습니다.

```text
hello()         → 새 Future 값 생성
pin!(future)    → 로컬 저장 위치에 Future를 두고 고정된 가변 참조 생성
pinned          → 그 참조를 보관
```

표준 라이브러리의 [`pin!` 문서](https://doc.rust-lang.org/std/pin/macro.pin.html)는 이 작업을 로컬 고정이라고 설명합니다. 매크로 자체는 새 힙 할당을 하지 않습니다. 일반 함수의 지역 저장 공간은 보통 스택에 있지만, 비동기 함수에서 중단을 넘어 유지되는 지역 상태는 바깥 Future에 포함될 수 있으므로 무조건 스택 고정이라고 부르면 범위를 잘못 이해하기 쉽습니다.

호출부에서 관찰할 수 있는 관계는 아래와 같습니다. 컴파일러가 생성하는 내부 변수 이름이나 정확한 매크로 확장을 그대로 나타낸 표는 아닙니다.

| 시점 | Future 본체의 저장과 소유 | 사용자가 가진 접근 |
| --- | --- | --- |
| `let future = hello()` 뒤 | future 바인딩이 본체를 소유 | 아직 고정하지 않은 Future 값 |
| `let mut pinned = pin!(future)` 뒤 | 매크로가 마련한 로컬 저장 공간에서 본체 관리 | pinned는 `Pin<&mut F>`를 소유 |
| `pinned.as_mut().poll(...)` 중 | 본체는 그 로컬 위치에 유지 | 이번 호출을 위한 짧은 고정된 가변 재빌림 |
| poll 반환 뒤 | 완료 여부와 별개로 본체는 아직 존재 | result에는 Pending 또는 Ready에 담긴 결과가 있음 |

`drop(pinned)`를 호출하면 참조 래퍼를 버리는 것이지, 그것만으로 로컬 Future 본체를 파괴하는 것은 아닙니다. 본체는 자신을 보관하는 로컬 저장 공간의 수명이 끝날 때 그 자리에서 정리됩니다. 반면 `Pin<Box<F>>`는 Box가 본체를 소유하므로, 그 소유자를 drop하면 본체를 제자리에서 파괴하고 할당을 해제합니다. Ready를 반환하는 것과 Future 객체를 drop하는 것도 별도의 사건입니다. 실행기는 완료를 확인한 뒤 더 이상 필요 없는 Future를 정리할 수 있습니다.

이 수명 차이는 Drop에 출력문을 넣어 관찰할 수 있습니다. 다음 hold는 인수로 받은 Resource를 Future 안에 보관합니다. 이번 실험에서는 Future를 한 번도 poll하지 않습니다.

```rust
use std::pin::pin;

struct Resource;

impl Drop for Resource {
    fn drop(&mut self) {
        println!("Resource 정리");
    }
}

async fn hold(resource: Resource) {
    drop(resource);
}

fn main() {
    {
        let pinned = pin!(hold(Resource));
        drop(pinned);
        println!("Pin 참조를 버린 뒤");
    }
    println!("로컬 저장 범위를 벗어난 뒤");
}
```

출력은 `Pin 참조를 버린 뒤`, `Resource 정리`, `로컬 저장 범위를 벗어난 뒤` 순서입니다. 첫 drop은 참조 래퍼만 소비합니다. 블록 끝에서 로컬 Future가 정리될 때 그 Future가 소유하던 Resource도 정리됩니다. hold의 본문을 실행한 결과가 아닙니다. 따라서 실행하지 않은 Future도 소유한 자원을 가질 수 있으며, 그 자원의 정리는 실행 완료와 별개로 소유자의 수명에 따릅니다.

그 참조는 본체의 로컬 저장 수명을 넘어서 사용할 수 없습니다. 함수가 끝나 사라질 로컬 값을 `pin!`으로 고정한 뒤 그 참조를 반환하는 방식은 사용할 수 없습니다. 호출자에게 소유권을 넘길 고정된 Future가 필요하다면 힙 할당을 소유하는 `Pin<Box<F>>`가 다른 선택지입니다.

두 타입의 관계는 다음과 같습니다.

| 타입 | 무엇을 통해 Future에 접근하는가 | Future 저장 공간의 수명 |
| --- | --- | --- |
| `Pin<&mut F>` | 고정된 Future를 빌리는 가변 참조 | 참조만으로 소유하지 않으며, 별도 저장 공간의 수명에 제한됨 |
| `Pin<Box<F>>` | Future의 힙 할당을 소유하는 Box | 소유하는 Box가 관리 |

`Pin::new`와 `pin!`도 다릅니다. 일반 참조에 쓰는 안전한 `Pin::new`는 대상 타입이 Unpin이라는 조건을 요구합니다. `pin!`은 Unpin이 아닌 값에도 위치 보장을 마련하므로 생성된 async Future에 사용할 수 있습니다.

## 14. Context와 Waker는 다음 실행을 연결합니다

첫 hello 예제에서는 한 번에 완료되므로 재실행 알림을 사용하지 않았습니다. 하지만 Pending을 받은 실행기는 언제 이 작업을 다시 시도할지 알아야 합니다. 매번 모든 작업을 쉬지 않고 poll하면 대기 중에도 CPU를 소비합니다.

실행기는 재실행을 요청할 수 있는 Waker를 마련하고 Context에 담아 poll로 전달합니다. Future가 대기해야 한다면, 자신이 기다리는 이벤트 쪽에서 그 Waker를 사용할 수 있도록 등록하는 식으로 다음 실행을 연결합니다. 이벤트가 발생하면 Waker를 통해 작업을 다시 실행하도록 알립니다. Waker는 현재 함수를 재귀 호출하는 이름이 아니라, 작업의 실행기에 전달하는 알림 수단입니다. 이 책임 분담은 [표준 라이브러리의 Waker 문서](https://doc.rust-lang.org/std/task/struct.Waker.html)에 설명되어 있습니다.

```text
실행기 → Future.poll(Context)
             │ 아직 대기 필요: 알림 경로를 마련하고 Pending 반환
             ↓
         실행기는 다른 작업을 수행하거나 대기
             ↑
이벤트 발생 → Waker를 통해 재실행 요청
             ↓
실행기 → 같은 Future를 다시 poll
```

이벤트 알림이 왔다고 바로 Ready가 보장되는 것은 아닙니다. 다시 시도했을 때 여전히 Pending일 수 있습니다. Future는 그 상황에서도 필요한 다음 알림 경로를 유지해야 합니다. 실제 I/O 코드에서는 준비 상태 확인과 알림 등록 사이에 이벤트를 놓치지 않도록 동기화하는 문제도 다루어야 합니다.

`Waker::noop()`은 알림을 무시하는 Waker입니다. 스레드를 깨우거나 작업 큐에 작업을 넣지 않습니다. 따라서 이것을 사용한 실험은 즉시 완료되거나, 작성자가 다음 시도 시점을 직접 정할 수 있는 작업으로 한정합니다. 다음 예제는 바로 그 제한 아래에서 두 번의 poll을 수동으로 연결합니다.

## 15. 같은 Future를 두 번 poll하면서 참조를 유지해 봅니다

다음 프로그램은 외부 라이브러리 없이 실행할 수 있습니다. 한 번은 Pending을 반환하고 다음에는 완료되는 작은 대기 작업을 만들어, 배열의 참조가 중단을 넘어 사용되는 상황을 관찰합니다.

```rust
use std::future::{poll_fn, Future};
use std::pin::pin;
use std::task::{Context, Poll, Waker};

async fn inspect() -> u8 {
    let bytes = [10_u8, 20, 30];
    let first = &bytes[0];
    let mut yielded = false;

    poll_fn(|cx| {
        if yielded {
            Poll::Ready(())
        } else {
            yielded = true;
            println!("inspect: 잠시 중단");
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    })
    .await;

    println!("inspect: 참조로 읽은 값 = {}", *first);
    *first
}

fn main() {
    let future = inspect();
    println!("Future 생성 완료");

    let mut pinned = pin!(future);
    let mut cx = Context::from_waker(Waker::noop());

    let first_poll = pinned.as_mut().poll(&mut cx);
    println!("첫 poll: {first_poll:?}");
    assert!(first_poll.is_pending());

    let second_poll = pinned.as_mut().poll(&mut cx);
    println!("둘째 poll: {second_poll:?}");
    assert_eq!(second_poll, Poll::Ready(10));
}
```

실행 결과는 다음과 같습니다.

```text
Future 생성 완료
inspect: 잠시 중단
첫 poll: Pending
inspect: 참조로 읽은 값 = 10
둘째 poll: Ready(10)
```

`poll_fn`은 클로저의 동작으로 Future를 만드는 표준 함수입니다. 여기서는 `yielded`가 false인 첫 호출에서 true로 바꾸고 재실행 알림을 요청한 뒤 Pending을 반환합니다. 다음 호출에서는 이미 true이므로 Ready를 반환합니다. 이것은 실제 네트워크나 타이머를 기다리는 코드가 아니라 중단과 재개를 두 단계로 분리하는 실험 장치입니다.

`Waker::noop()`은 알림을 받아도 아무 동작도 하지 않습니다. 이 프로그램은 실험 대상이 두 번째 poll에서 준비된다는 것을 알고 main에서 직접 다시 호출합니다. 실제 실행기에서는 깨우기 알림을 받아 실행 가능한 작업을 다시 스케줄해야 합니다. 이 코드를 모든 Future에 사용할 수 있는 실행기로 일반화해서는 안 됩니다.

첫 poll에서 `inspect`의 본문이 시작되고 배열, 참조와 대기 상태가 마련됩니다. 내부 작업이 Pending을 반환하면 바깥 inspect도 Pending을 반환합니다. 둘째 poll에서는 대기 작업이 완료되어 참조를 읽고 10으로 끝납니다. 그동안 Future 본체를 같은 위치에 유지한다는 계약이 있습니다. 이 실험이 컴파일러의 특정 필드 배치나 최적화 결과를 증명하는 것은 아니며, 중단을 넘는 빌림을 포함한 코드를 안전한 API로 실행한 것입니다.

`poll`은 `self: Pin<&mut Self>`를 받습니다. [`Future`의 표준 계약](https://doc.rust-lang.org/std/future/trait.Future.html)에 이 인자 타입이 포함되어 있으므로, 이 실험에서도 먼저 고정된 참조를 만들어 전달합니다. 어떤 Future는 실제로 고정을 필요로 하고 다른 Future는 그렇지 않더라도, 호출 인터페이스는 두 경우를 모두 처리합니다.

## 16. 왜 `pinned.as_mut()`을 매번 호출하는가

앞의 프로그램에서 `pinned`의 타입은 `Pin<&mut F>`입니다. `poll`의 self 인자는 이 참조 래퍼 값을 받습니다. `pinned.poll(&mut cx)`처럼 직접 호출하면 참조 래퍼를 소비하여, 다음 호출에서 같은 `pinned` 변수를 재사용할 수 없습니다.

`pinned.as_mut()`은 기존 고정된 참조로부터 더 짧게 빌리는 `Pin<&mut F>`를 만들어 줍니다. poll에는 이 짧은 재빌림을 전달합니다. 호출이 끝나면 원래 `pinned`를 다시 빌려 다음 poll을 할 수 있습니다.

```text
pinned.as_mut() → 이번 호출 동안만 사용할 고정된 가변 재빌림
               → poll이 그 재빌림을 받음
               → 호출 종료 후 pinned를 다음 호출에 다시 사용
```

이 과정은 Future를 복제하지도, 새 Future를 만들지도 않습니다. 두 번의 poll 모두 같은 Future 본체를 대상으로 합니다. `as_mut()`은 내부 값을 꺼내는 메서드도 아니며, 고정 계약을 유지한 채 참조를 다시 빌리는 메서드입니다.

둘째 poll이 Ready를 반환한 뒤에는 세 번째 poll을 하지 않습니다. 완료한 Future를 다시 poll하는 것은 Future 계약에서 허용된 사용 방식이 아닙니다. 고정되어 있다는 사실은 재실행이나 재사용을 보장하지 않습니다.

## 17. Pin을 다른 변수로 옮겨도 되는 이유

첫 실험의 `let a = future`로 돌아가 보겠습니다. 고정하기 전에는 Future 본체를 옮겼습니다. 고정한 뒤에는 포인터 래퍼를 옮길 수 있습니다. 다음 프로그램은 그 구분을 주소 비교로 확인합니다.

```rust
use std::future::Future;
use std::task::{Context, Poll, Waker};

async fn hello() -> u32 {
    42
}

fn main() {
    let pinned = Box::pin(hello());
    let before = pinned.as_ref().get_ref() as *const _;

    let mut a = pinned;
    let after = a.as_ref().get_ref() as *const _;
    assert_eq!(before, after);

    let mut cx = Context::from_waker(Waker::noop());
    assert_eq!(a.as_mut().poll(&mut cx), Poll::Ready(42));
    println!("Pin<Box<F>> 이동 후에도 Future 주소 유지");
}
```

`let mut a = pinned`는 `Pin<Box<F>>`의 소유권 이동입니다. 이 포인터 래퍼가 힙의 Future를 소유하므로 그 소유권도 함께 넘어갑니다. 그러나 힙의 Future 본체는 같은 위치에 남아 있습니다. 따라서 포인터 래퍼의 이동과 고정 계약이 충돌하지 않습니다.

`pin!`으로 만든 `Pin<&mut F>`도 참조 래퍼 자체를 다른 변수로 옮길 수 있습니다. 다만 그 참조가 Future 본체의 저장 공간을 소유하는 것은 아니므로, 본체의 수명 제약을 그대로 받습니다.

반대로 `Pin<Box<F>>`에서 Box를 무조건 꺼낸 뒤 Future를 이동하게 해서는 안 됩니다. 안전한 `Pin::into_inner`는 대상 타입의 Unpin 제약을 확인합니다. 일반적인 async Future에 이 경로를 적용하면 컴파일러가 거절합니다. Box가 할당을 소유한다는 것과, 그 할당의 내용을 자유롭게 꺼낼 권한이 있다는 것은 구분됩니다.

이와 관련된 `Box::pin`, `Pin::as_mut`, `Pin::into_inner`의 API 조건은 각각 [Box의 고정 생성자](https://doc.rust-lang.org/std/boxed/struct.Box.html#method.pin)와 [Pin의 메서드 문서](https://doc.rust-lang.org/std/pin/struct.Pin.html)에 명시되어 있습니다. 안전한 API가 어떤 접근을 허용하는지 확인할 때에는 타입 이름뿐 아니라 메서드의 trait 제약도 함께 읽어야 합니다.

## 18. Box에서 Future를 꺼내는 것과 Future를 실행하는 것은 별개입니다

Data에서 확인한 이동 규칙을 Future에도 그대로 적용할 수 있습니다. 다음 프로그램은 아직 고정하지 않은 Future를 Box에 저장했다가 꺼내고, 로컬 위치에 고정한 다음 실행합니다.

```rust
use std::future::Future;
use std::pin::pin;
use std::task::{Context, Poll, Waker};

async fn hello() -> u32 {
    println!("hello 본문 실행");
    42
}

fn main() {
    let boxed = Box::new(hello());
    println!("1. Future를 Box에 저장");

    let future = *boxed;
    println!("2. Future 본체를 Box 밖으로 이동");

    let mut pinned = pin!(future);
    let mut cx = Context::from_waker(Waker::noop());
    let result = pinned.as_mut().poll(&mut cx);
    println!("3. 완료 결과: {result:?}");
    assert_eq!(result, Poll::Ready(42));
}
```

출력은 다음 순서입니다.

```text
1. Future를 Box에 저장
2. Future 본체를 Box 밖으로 이동
hello 본문 실행
3. 완료 결과: Ready(42)
```

`Box::new(hello())`는 새 Future를 힙에 저장할 뿐 본문을 실행하지 않습니다. `let future = *boxed`도 본문 실행이나 완료 결과 추출이 아닙니다. 아직 실행하지 않은 Future 본체의 소유권을 옮깁니다. hello가 반환한 Future는 Copy가 아니므로 boxed를 통해 그 본체를 다시 읽을 수 없습니다. 마지막 poll에서야 본문이 실행되어 결과 42가 나옵니다.

이 Future는 Unpin이 아니지만 아직 고정되지 않았으므로 꺼내 이동할 수 있습니다. 반대로 처음부터 `Box::pin(hello())`로 만들면 `Pin<Box<F>>`가 됩니다. 일반적인 async Future에 대해 그 핀 포인터를 역참조해서 본체를 직접 꺼내는 코드는 허용되지 않습니다. 고정한 이후의 주소 계약을 깨뜨릴 수 있기 때문입니다. 이 사례에서는 시도한 직접 이동이 E0507로 거절됩니다.

| 코드 | 이동하거나 얻는 대상 | hello 본문 실행 |
| --- | --- | --- |
| `let a = boxed` | Box 소유권 | 없음 |
| `let future = *boxed` | 고정 전 Future 본체 | 없음 |
| `let a = pinned_box` | `Pin<Box<F>>` 소유권, 본체는 같은 위치 | 없음 |
| `pinned.as_mut().poll(&mut cx)` | 본체를 빌려 실행하고 Poll 결과를 받음 | 이 예제에서는 있음 |

이 비교를 통해 Box와 Pin이 나누어 맡는 역할이 드러납니다. Box는 저장과 소유를 담당하며, Pin은 위치 보장이 필요한 본체를 꺼내 이동하는 접근을 제한합니다. poll은 그 본체를 빌려 실행 상태를 진행합니다. 이 셋을 같은 종류의 포장이나 호출로 보면 언제 값이 옮겨지고 언제 코드가 실행되는지 구분하기 어렵습니다.

## 19. `hello().await`에는 왜 pin!이 보이지 않는가

일반적인 비동기 코드에서는 `hello().await`라고 쓰며 매번 직접 pin!을 호출하지 않습니다. `.await`는 단순한 일반 메서드 호출이 아니라 컴파일러가 처리하는 언어 문법입니다. 컴파일러는 바깥 비동기 상태 머신 안에서 내부 작업을 진행시키는 데 필요한 고정된 접근을 구성합니다. 바깥 Future 자체도 실행기가 poll하기 전에 적절한 위치에 고정합니다.

따라서 직접 poll하는 실험에서 보이는 준비 코드가 모든 애플리케이션 호출부에 노출되는 것은 아닙니다. 우리가 실행기를 만들려 하므로 평소 컴파일러와 런타임이 담당하던 경계가 드러난 것입니다. `.await`가 내부 Future를 어떤 방식으로 처리하는지에 대한 언어 규칙은 [Rust Reference의 await 표현식 설명](https://doc.rust-lang.org/reference/expressions/await-expr.html)에 정리되어 있습니다.

Pin은 Future를 실행하지도, 다른 스레드로 보내지도 않습니다. 다른 스레드로 소유권을 보낼 수 있는지는 `Send` 등의 조건이 다룹니다. 고정은 위치의 문제이고, 실행은 poll과 스케줄링의 문제입니다. `Pin<Box<F>>`처럼 포인터를 옮기면서 본체 위치를 유지할 수 있기 때문에 두 요구는 함께 만족할 수 있습니다.

실행기를 읽을 때에는 작업을 저장하는 위치, 그 위치를 소유하는 객체, poll에 전달하는 참조를 따로 찾아보면 됩니다. `pin!`은 로컬 위치에서 고정된 참조를 마련하고, `Box::pin`은 힙 할당을 소유하는 고정 포인터를 마련하며, `as_mut()`은 그 대상으로 잠시 다시 빌리는 접근을 제공합니다. 각각의 코드가 어느 값을 옮기고 어느 값을 그대로 유지하는지 확인하면 Pin 관련 문법이 같은 메모리 모델 안에서 연결됩니다.

## 검증 기록과 재현 자료

2026-11-14 개정본의 정상 실행 프로그램 13개를 Rust 1.95.0, edition 2024에서 컴파일하고 출력과 assert를 확인했습니다. 단일 poll의 실행 순서, 직접 구현한 Future의 상태 변경, Pin 참조와 로컬 Future의 정리 시점, `&mut`를 통한 값 교체, Unpin 타입의 접근, 중단을 넘는 빌림과 두 번의 poll, 고정 포인터를 옮긴 뒤의 주소 유지가 검증 대상입니다. 주소 비교 예제에는 원시 포인터 역참조가 없습니다.

추가로 Box에서 값을 꺼낸 뒤의 재사용, 공유·가변 참조를 통한 비-Copy 값의 직접 이동, 고정된 async Future 본체의 직접 이동을 E0382/E0507로 거절하는 것을 확인했습니다. async Future에 `Pin::new`를 적용하는 경우, 고정된 async Future에서 `get_mut`나 `into_inner`를 통해 제한 없는 접근을 얻으려는 경우의 E0277 오류를 확인했습니다. `pin!` 뒤에 원래 변수를 사용하거나 재빌림 없이 같은 Pin 참조를 두 번 소비하는 경우는 E0382로 거절되는 것을 확인했습니다. 이는 컴파일러가 API의 제약을 확인하는 실험이며, 임의의 unsafe 구현의 안전성을 검증한 결과는 아닙니다.

[전체 실행 예제와 컴파일 실패 검사 스크립트](/examples/rust-pin/verify.py)를 저장한 뒤 `python3 verify.py`로 재현할 수 있습니다. Rust 컴파일러가 PATH에 있어야 합니다. 스크립트는 임시 디렉터리에 소스를 만들고 컴파일하며, Rust 버전에 따라 오류 메시지의 상세 문구는 달라질 수 있습니다.

관련 글: [연관 타입과 Future::Output](/posts/rust-associated-types/), [Box의 소유권과 dyn](/posts/rust의-box와-dyn-값의-소유권은-어떻게-이동하고-정리되는가/).
