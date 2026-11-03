---
title: "Rust의 Box와 dyn: 값의 소유권은 어떻게 이동하고 정리되는가"
pubDate: 2026-11-04T09:00:00+09:00
description: "값과 저장 위치에서 출발해 Box의 소유권 이동, Drop과 힙 해제, dyn의 동적 디스패치와 구체 타입 정리를 연결합니다. Rust 1.95.0으로 예제를 실행해 확인했습니다."
author: "Tae Shim"
image:
  url: "/images/rust-box-dyn.svg"
  alt: "Box의 단독 소유권과 dyn의 데이터 포인터·메타데이터"
tags: ["rust", "ownership", "memory", "systems"]
---

`Box<T>`는 값과 그 값을 저장한 힙 할당을 소유하는 스마트 포인터입니다. `dyn Trait`은 특정 구체 타입 대신, 그 타입이 구현한 trait의 인터페이스를 통해 값을 다루게 하는 타입입니다. 두 기능은 독립적입니다. `Box<T>`는 **누가 값을 소유하고 정리하는가**를 결정하고, `dyn Trait`은 **구체 타입을 드러내지 않고 어떤 동작을 호출할 수 있는가**를 결정합니다.

따라서 `Box<dyn Trait>`을 이해하려면 두 질문을 나누어야 합니다. 먼저 값을 생성하고 소유권을 이동한 뒤 정리하는 과정을 살펴봅니다. 그다음 구체 타입을 감춘 상태에서도 메서드 호출과 정리가 가능한 이유를 연결합니다. 오류 처리에서 사용하는 `Box<dyn Error>`는 이 기본 동작의 한 적용입니다.

## 1. 값, 저장 위치, 소유자는 서로 다릅니다

Rust에서 변수 이름은 값을 사용하는 경로입니다. 소유권은 그 값의 사용과 정리를 관리하는 규칙이며, 별도의 소유자 목록을 실행 중에 검색하는 기능이 아닙니다. 컴파일러는 대입과 함수 호출을 검사하여 이동한 값을 다시 사용하지 못하게 하고, 필요한 정리 코드가 실행되도록 합니다.

다음 코드에서 `first`는 `String` 값을 소유합니다.

```rust
fn main() {
    let first = String::from("sample");
    let second = first;

    println!("{second}");
}
```

`let second = first`는 `String`의 소유권을 `second`로 이동합니다. 이후 `first`를 읽으면 컴파일 오류입니다. 문자열 내용이 두 벌로 복제되는 것이 아니며, 블록 끝에서 같은 문자열 버퍼를 두 번 해제하지도 않습니다. 정리해야 할 값을 가진 변수는 이제 `second`입니다.

이동은 “메모리에 있는 모든 바이트가 반드시 다른 주소로 옮겨진다”는 뜻은 아닙니다. 언어 차원에서는 이전 소유자를 통한 사용이 끝나고 새 소유자가 값을 인수한다는 뜻입니다. 실제 기계어에서 바이트를 옮기는지, 레지스터를 사용하는지, 이동을 없애는지는 컴파일러가 결정합니다. Rust 공식 입문서인 *The Rust Programming Language*의 [소유권 설명](https://doc.rust-lang.org/book/ch04-01-what-is-ownership.html)은 이러한 이동과 복사를 구분하는 출발점입니다.

`u32`처럼 `Copy`를 구현한 타입은 대입할 때 값을 복사하여 양쪽을 계속 사용할 수 있습니다. 반면 `String`과 `Box<T>`는 `Copy`가 아닙니다. 특히 `Box<u32>`도 내부 숫자가 `Copy`라는 이유로 소유권까지 복제되지는 않습니다.

## 2. Box는 무엇을 저장하고 소유합니까

힙은 실행 중에 필요한 저장 공간을 할당하고 해제할 수 있는 메모리 영역입니다. `Box::new(value)`는 일반적인 크기가 0이 아닌 값에 대해 힙 공간을 확보하고, 그곳에 값을 저장하며, 그 공간을 소유하는 `Box`를 반환합니다.

```rust
fn main() {
    let first: Box<u32> = Box::new(7);
    let second: Box<u32> = first;

    println!("{}", *second);
}
```

`Box<u32>` 값과 힙에 저장된 `u32` 값은 구분해야 합니다. `first`에 있던 것은 힙의 숫자를 소유하는 포인터 값입니다. 대입 뒤에는 `second`가 그 포인터 값을 인수합니다. 힙의 숫자를 새로 할당하거나 복제하지 않습니다. `*second`는 포인터가 가리키는 숫자에 접근하는 역참조입니다.

```text
Box::new(7) 이후
first  ──소유──▶ 힙 할당: u32 값 7

let second = first 이후
first: 이동되어 사용할 수 없음
second ──소유──▶ 동일한 힙 할당: u32 값 7
```

이런 간접 저장은 큰 값을 여러 함수 사이에서 전달하거나, 크기가 재귀적으로 정의되는 자료구조를 구성할 때 유용합니다. 이동하는 것은 `Box`의 작은 포인터 표현이고, 그 이동만으로 힙의 값이 다른 위치로 옮겨지지는 않습니다. Rust 입문서의 [Box 장](https://doc.rust-lang.org/book/ch15-01-box.html)에서는 이와 같은 사용 목적을 설명하고 있습니다.

`Box` 자체가 반드시 스택에 있어야 하는 것은 아닙니다. 지역 변수일 수도 있고, 다른 구조체의 필드나 벡터의 원소일 수도 있습니다. 또한 크기가 0인 타입에는 실제 힙 할당이 필요하지 않습니다. 여기서는 메모리 관계를 분명하게 보기 위해 크기가 0이 아닌 값을 다룹니다. 표준 라이브러리의 [boxed 문서](https://doc.rust-lang.org/std/boxed/index.html)는 할당과 메모리 표현의 조건을 명시하고 있습니다.

## 3. 함수에 Box를 전달하면 정리 책임도 이동합니다

함수 매개변수의 타입이 `Box<T>`라면 호출자는 `Box` 값을 이동합니다. 매개변수가 `&T`라면 함수는 값을 빌려 사용할 뿐 소유권을 인수하지 않습니다. 이 차이는 함수가 끝날 때 어느 값이 정리되는지를 결정합니다.

아래 예제는 시작점인 `main`에서 생성, 빌림, 함수로의 이동, 반환, 명시적 정리를 차례로 수행합니다. `Resource`의 `Drop` 구현은 값이 정리되는 순간을 출력하기 위한 코드입니다.

```rust
fn main() {
    let first = Box::new(Resource { id: 7 });
    println!("created");

    inspect(&first);
    println!("after borrow");

    let second = transfer(first);
    println!("after transfer");

    drop(second);
    println!("after drop");
}

struct Resource {
    id: u32,
}

impl Drop for Resource {
    fn drop(&mut self) {
        println!("drop Resource {}", self.id);
    }
}

fn inspect(resource: &Resource) {
    println!("inspect {}", resource.id);
}

fn transfer(resource: Box<Resource>) -> Box<Resource> {
    println!("transfer {}", resource.id);
    resource
}
```

Rust 1.95.0에서 실행한 출력은 다음과 같습니다.

```text
created
inspect 7
after borrow
transfer 7
after transfer
drop Resource 7
after drop
```

먼저 `inspect(&first)`에서 `&first`는 `&Box<Resource>`입니다. 함수가 요구하는 것은 `&Resource`이므로 Rust가 `Box`의 역참조 기능을 이용해 참조를 변환합니다. 이를 deref coercion이라고 합니다. 힙의 `Resource`를 빌려 읽는 것이며 `Box` 소유권은 여전히 `first`에 있습니다. 이 호출을 더 직접적으로 표기하면 `inspect(&*first)`입니다. `*first`로 대상에 접근하고 `&`로 그 대상을 빌립니다.

반면 `transfer(first)`는 `Box<Resource>`를 값으로 전달합니다. `first`의 소유권이 매개변수 `resource`로 이동하며, 호출 이후 `first`는 사용할 수 없습니다. 함수의 마지막 표현식인 `resource`는 그 소유권을 반환값으로 이동하고, 호출자가 반환값을 `second`에 저장합니다. `transfer`가 끝나더라도 내부 값은 정리되지 않습니다. 매개변수가 소유하던 값이 이미 반환되었기 때문입니다.

이 과정에서 힙 할당은 하나입니다. 소유권 경로는 `first → resource → 반환값 → second`로 바뀌지만, 그 경로가 바뀔 때마다 `Resource`가 생성되거나 `Drop`이 실행되지는 않습니다.

## 4. Drop은 값의 정리이며, 할당 해제와는 구분됩니다

`Drop`은 값이 정리될 때 실행할 사용자 정의 동작을 제공하는 trait입니다. `impl Drop for Resource`의 `drop(&mut self)`는 정리 직전에 `Resource`를 가변 참조로 받아 실행합니다. 이 메서드 안에서는 아직 필드를 읽을 수 있습니다. 예제에서 `self.id`를 출력할 수 있는 이유입니다.

사용자가 작성한 `Drop::drop`만으로 전체 정리가 끝나는 것은 아닙니다. 컴파일러가 연결하는 정리 코드, 흔히 **drop glue**라고 부르는 코드가 필드의 정리도 수행합니다. 사용자 정의 `Drop`이 없는 구조체라도 `String`이나 `Vec` 필드를 가지고 있다면 그 필드는 자동으로 정리됩니다. 표준 라이브러리의 [Drop 문서](https://doc.rust-lang.org/std/ops/trait.Drop.html)는 사용자 정의 정리와 필드의 자동 정리를 구분하고 있습니다.

앞 예제에서 `drop(second)`를 실행하면 정상적인 경로에서 다음 순서로 진행합니다.

1. `second`의 `Box<Resource>`가 `std::mem::drop`의 인수로 이동합니다.
2. 그 함수의 인수 값이 정리되면서 `Box`가 소유한 `Resource`의 정리를 수행합니다.
3. `Resource::drop`이 실행되어 `drop Resource 7`을 출력합니다.
4. `Resource`의 필드를 정리합니다. `u32` 필드에는 추가 자원 정리가 없습니다.
5. `Box`가 `Resource`를 저장했던 힙 할당을 해제합니다.

`std::mem::drop`은 특별한 해제 명령문이 아니라 일반 함수입니다. 핵심 형태는 `fn drop<T>(_value: T) {}`이며, 인수를 값으로 받은 뒤 함수가 끝나므로 그 인수의 정리가 일어납니다. 표준 라이브러리의 [drop 함수 설명](https://doc.rust-lang.org/std/mem/fn.drop.html)에서도 이 구현을 그대로 보여 줍니다. `drop(&second)`처럼 참조를 전달하면 `Box`의 소유권은 이동하지 않으므로 같은 효과가 없습니다.

이와 달리 `second.drop()`처럼 `Drop::drop`을 직접 호출하는 것은 허용되지 않습니다. 값의 수명 종료와 필드·할당의 정리를 일관되게 처리하려면 소유권을 소비하는 `drop(second)`를 사용해야 합니다.

명시적인 `drop(second)`를 생략하면 이 예제에서는 `main`의 블록 끝에서 `second`가 정리됩니다. `first`나 `transfer`의 매개변수에서 같은 값을 다시 정리하지 않습니다. Rust는 이동된 저장 위치에 이전 값이 남아 있는 것처럼 취급하지 않습니다.

### 내부 값도 다른 메모리를 소유할 수 있습니다

`Resource`에 `name: String` 필드가 있다고 가정하면 두 종류의 할당을 구분해야 합니다. `Box`의 할당에는 `Resource` 자체와 그 안의 `String` 관리 정보가 저장됩니다. 문자열의 바이트 버퍼는 `String`이 별도로 소유합니다.

```text
Box<Resource>
  └─ 소유 → Resource용 힙 할당
               └─ name: String
                    └─ 소유 → 문자열 바이트 버퍼
```

정리 시에는 `Resource::drop`을 먼저 실행하고, 그다음 `name` 필드의 `String`을 정리하여 문자열 버퍼를 해제하며, 마지막으로 `Box`의 할당을 해제합니다. `Resource::drop` 안에서 문자열 버퍼를 직접 해제할 필요가 없습니다. 수동 해제와 자동 정리를 중복해서 수행해서도 안 됩니다.

Rust의 언어 규칙을 설명하는 *The Rust Reference*의 [destructor 규칙](https://doc.rust-lang.org/reference/destructors.html)에 따르면 구조체의 사용자 정의 정리 후에는 필드를 선언 순서대로 정리합니다. 단, 프로세스 강제 종료나 `panic = "abort"` 같은 경우까지 정리가 항상 실행된다는 뜻은 아닙니다. 또한 `mem::forget`이나 `Box::leak`처럼 의도적으로 자동 정리를 수행하지 않는 기능도 있습니다. 여기서 설명한 순서는 정상적으로 정리를 수행하는 경로를 전제로 합니다.

## 5. dyn은 소유권이 아니라 구체 타입을 다루는 방식입니다

trait은 타입이 제공할 동작의 계약입니다. 다음 `Describe` trait을 구현하는 타입은 `describe(&self)` 메서드를 제공해야 합니다. `&self`이므로 이 메서드는 대상을 빌려 읽으며 소유권을 소비하지 않습니다.

```rust
trait Describe {
    fn describe(&self);
}

impl Describe for Resource {
    fn describe(&self) {
        println!("Resource {}", self.id);
    }
}
```

`Resource`는 필드와 메모리 크기가 정해진 구체 타입입니다. 반면 `dyn Describe`는 `Describe`를 구현하는 구체 타입의 값을 그 인터페이스로 다루기 위한 **trait object 타입**입니다. 실제 값이 `Resource`라는 사실이 사라지는 것이 아니라, 사용하는 쪽의 타입에 `Resource`가 드러나지 않는 것입니다.

```rust
fn show(value: &dyn Describe) {
    value.describe();
}
```

`show`의 매개변수는 구체 타입을 지정하지 않습니다. `Resource`를 빌려 호출할 수도 있고, 나중에 `Describe`를 구현한 다른 타입을 빌려 호출할 수도 있습니다. 함수 본문은 공통 계약인 `describe`만 이용합니다. `dyn`은 런타임에 메서드 이름을 검색하거나, 아무 타입의 아무 메서드나 호출하게 하는 기능이 아닙니다. 허용되는 인터페이스는 컴파일할 때 검사합니다.

### 구체 타입을 감추었는데 어떤 메서드를 호출합니까

trait object를 가리키는 포인터에는 대상 데이터에 접근할 정보와, 해당 구체 타입의 구현을 선택할 메타데이터가 필요합니다. 이 메타데이터에 사용되는 **vtable**은 해당 타입의 trait 구현 등을 연결하는 컴파일러 관리 정보입니다. `value.describe()`는 이 정보를 통해 실제 대상에 맞는 구현을 호출합니다. 이런 호출 선택을 **동적 디스패치**라고 합니다.

```text
&dyn Describe 또는 Box<dyn Describe>
  ├─ 데이터 포인터 ──▶ 실제 Resource 값
  └─ 메타데이터    ──▶ Resource의 Describe 구현 등에 대한 정보
```

The Rust Reference의 [trait object 설명](https://doc.rust-lang.org/reference/types/trait-object.html)은 데이터 포인터와 vtable을 통해 이 동작을 설명합니다. 위 그림은 개념적 관계이며, Rust가 프로그램 사이에 고정된 vtable 바이너리 배치를 보장한다는 뜻은 아닙니다.

실행 중 호출 대상을 선택하는 모델이라고 해도 컴파일러가 구체 타입을 알아낼 수 있는 위치에서는 최적화할 수 있습니다. 중요한 것은 소스 코드가 구체 타입을 요구하지 않는 인터페이스로 작성된다는 점입니다.

### 왜 dyn 앞에 &나 Box를 붙입니까

`Describe`를 구현하는 타입마다 크기가 다를 수 있습니다. 따라서 `dyn Describe` 자체의 크기를 하나의 컴파일 타임 상수로 정할 수 없습니다. 이런 타입을 동적 크기 타입, 즉 DST라고 합니다. 일반적인 지역 변수나 값 매개변수처럼 크기가 정해져야 하는 자리에 `dyn Describe`를 그대로 저장하는 대신, 크기가 정해진 포인터를 통해 접근합니다.

`&dyn Describe`는 대상을 빌리는 참조이고 `Box<dyn Describe>`는 대상을 소유하는 포인터입니다. 전자는 그 자체로 힙 할당을 요구하지 않습니다. 지역 변수인 `Resource`를 `&dyn Describe`로 빌릴 수도 있습니다. 후자는 대상의 소유권과 힙 할당의 정리를 맡습니다. 따라서 “`dyn`을 쓰려면 항상 `Box`가 필요하다”는 설명은 맞지 않습니다.

모든 trait이 `dyn`으로 사용 가능한 것도 아닙니다. 예를 들어 객체를 통해 호출할 메서드가 타입 매개변수를 갖는 경우에는 제약이 있습니다. 위의 `Describe`처럼 단순한 빌림 메서드는 이 예제에 적합하며, 더 복잡한 인터페이스의 정확한 조건은 Reference의 [dyn compatibility 규칙](https://doc.rust-lang.org/reference/items/traits.html#dyn-compatibility)에서 확인할 수 있습니다.

## 6. `Box<dyn Trait>`에서도 이동과 Drop의 규칙은 유지됩니다

이제 앞의 두 기능을 결합할 수 있습니다. 다음은 별도로 실행할 수 있는 전체 예제입니다. `main`의 한 줄씩을 따라가면 구체 타입을 가진 `Box`가 trait object를 소유하는 `Box`로 바뀌고, 다른 함수로 이동한 다음 정리되는 과정이 드러납니다.

```rust
fn main() {
    let concrete: Box<Resource> = Box::new(Resource { id: 7 });
    println!("created");

    let object: Box<dyn Describe> = concrete;
    println!("converted to trait object");

    show(&*object);
    println!("after borrow");

    consume(object);
    println!("after consume");
}

trait Describe {
    fn describe(&self);
}

struct Resource {
    id: u32,
}

impl Describe for Resource {
    fn describe(&self) {
        println!("Resource {}", self.id);
    }
}

impl Drop for Resource {
    fn drop(&mut self) {
        println!("drop Resource {}", self.id);
    }
}

fn show(value: &dyn Describe) {
    value.describe();
}

fn consume(value: Box<dyn Describe>) {
    value.describe();
    println!("leaving consume");
}
```

Rust 1.95.0에서 실행한 출력은 다음과 같습니다.

```text
created
converted to trait object
Resource 7
after borrow
Resource 7
leaving consume
drop Resource 7
after consume
```

`let object: Box<dyn Describe> = concrete`에서는 소유권 이동과 타입 변환이 함께 일어납니다. 이때의 변환은 컴파일러가 허용하는 **unsized coercion**입니다. 힙의 `Resource`를 복제하거나 다른 크기의 객체로 바꾸는 것이 아니라, 같은 값을 가리키면서 trait object에 필요한 메타데이터를 갖춘 소유 포인터로 바꿉니다. `concrete`는 이동되었으므로 이후 사용할 수 없습니다. Reference의 [타입 강제 변환 규칙](https://doc.rust-lang.org/reference/type-coercions.html#unsized-coercions)은 이런 변환을 일반적인 임의 타입 변환과 구분합니다.

`show(&*object)`에서는 `Box`가 가리키는 대상을 `&dyn Describe`로 빌립니다. `show`가 돌아와도 `object`가 소유자이므로 대상은 남아 있습니다. 이어서 `consume(object)`가 `Box`를 값으로 받으면 소유권은 매개변수 `value`로 이동합니다. 이 함수는 `Box`를 반환하지 않습니다. 따라서 함수 끝에서 `value`가 정리되며, 호출자가 다음 줄을 실행하기 전에 `drop Resource 7`이 출력됩니다.

`consume`에는 `Resource`라는 타입 이름이 없지만 실제 값은 여전히 `Resource`입니다. trait object의 런타임 메타데이터를 통해 그 실제 타입에 맞는 정리 경로를 사용합니다. `Resource::drop`을 실행하고 필드를 정리한 다음, `Box`가 할당을 해제합니다. 이것은 `Describe`에 `drop` 메서드를 추가해서 구현하는 동작이 아닙니다. trait object를 정리할 때 내부 구체 타입의 destructor를 실행하는 Rust의 규칙입니다.

여기까지의 소유권 변화를 요약하면 다음과 같습니다.

| 시점 | Box 값을 소유하는 위치 | 힙의 Resource | 정리 여부 |
| --- | --- | --- | --- |
| 생성 직후 | `concrete` | 새로 생성됨 | 아직 아님 |
| trait object 변환 후 | `object` | 같은 값, 같은 할당 | 아직 아님 |
| `show` 실행 중 | 여전히 `object` | 빌려 읽음 | 아직 아님 |
| `consume` 실행 중 | 매개변수 `value` | 같은 값, 같은 할당 | 아직 아님 |
| `consume` 종료 | 소유권이 소비됨 | destructor 실행 후 할당 해제 | 한 번 실행 |

## 7. Box를 이동하는 것과 내부 값을 꺼내는 것은 다릅니다

지금까지는 `Box` 자체를 이동했습니다. 구체 타입을 소유한 `Box<T>`에서는 역참조한 위치의 값을 밖으로 이동할 수도 있습니다.

```rust
fn main() {
    let boxed = Box::new(String::from("sample"));
    let text: String = *boxed;

    println!("{text}");
}
```

이 예제의 `String`은 `Copy`가 아니므로 `let text = *boxed`는 내부 `String`의 이동입니다. `Box`가 소유하던 `String`은 이제 `text`가 소유합니다. `Box`의 저장 공간 정리와 문자열 바이트 버퍼의 정리는 별개입니다. 밖으로 이동한 문자열 버퍼는 `text`가 정리될 때까지 유효합니다. 단지 역참조 기호를 썼다는 이유로 항상 이동하는 것은 아닙니다. `&*boxed`는 빌림이고, 앞의 `u32` 예제처럼 `Copy` 값의 읽기는 복사가 될 수 있습니다.

`Box<dyn Describe>`에서 같은 형태로 내부 값을 일반 지역 변수에 꺼내려고 하면 다른 문제가 생깁니다. 꺼내려는 타입 `dyn Describe`의 크기가 고정되어 있지 않기 때문입니다. 앞에서 포인터를 통해 다룬 이유가 여기서도 유지됩니다.

## 8. `Box<dyn Error>`는 같은 규칙을 오류에 적용한 형태입니다

[`Error`](https://doc.rust-lang.org/std/error/trait.Error.html)는 표준 라이브러리에서 오류를 표현하기 위해 제공하는 trait입니다. `Result<(), Box<dyn std::error::Error>>`는 성공할 때 `()`를, 실패할 때 `Error`를 구현한 어떤 구체 오류 값을 소유하는 `Box`를 반환한다는 뜻입니다.

이 타입을 사용한다고 오류 객체에 특별한 수명 규칙이 생기지는 않습니다. `Err(boxed_error)`로 반환하면 `Box`의 소유권이 `Result` 안으로 이동하고, 반환된 `Result`의 소유권이 호출자에게 이동합니다. 호출자가 오류를 다른 곳으로 이동하지 않고 정리하면 내부 구체 오류 타입의 정리와 힙 할당 해제가 진행됩니다. 오류 메시지를 출력하는 행위와 오류 값을 정리하는 행위는 서로 다른 동작입니다.

`Box`는 오류 전용 기능도, 참조 카운트 기반 공유 소유권도 아닙니다. `dyn` 역시 소유권 이동을 대신하는 기능이 아닙니다. 코드에서 확인할 것은 **어떤 값을 누가 소유하는지**, **현재 연산이 이동인지 빌림인지**, **구체 타입을 직접 사용하는지 trait object를 사용하는지**입니다. 이 세 가지를 구분하면 `Box<dyn Trait>`의 메서드 호출과 정리 과정을 같은 원리로 추적할 수 있습니다.
