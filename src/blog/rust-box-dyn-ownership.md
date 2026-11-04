---
title: "Rust의 Box와 dyn: 값의 소유권은 어떻게 이동하고 정리되는가"
pubDate: 2026-11-04T09:00:00+09:00
description: "일반 trait 메서드 호출과 dyn의 차이에서 출발해 제네릭, 빌림, Box의 소유권 이동과 Drop을 연결합니다. Rust 1.95.0으로 예제를 실행해 확인했습니다."
author: "Tae Shim"
image:
  url: "/images/rust-box-dyn.svg"
  alt: "Box의 단독 소유권과 dyn의 데이터 포인터·메타데이터"
tags: ["rust", "ownership", "memory", "systems"]
---

`Box<T>`는 값과 그 값을 저장한 힙 할당을 소유하는 스마트 포인터입니다. `dyn Trait`은 구체 타입을 직접 드러내지 않고 trait의 인터페이스로 값을 다루게 하는 타입입니다. 둘을 결합한 `Box<dyn Trait>`은 “인터페이스로 사용할 값을 소유한다”는 뜻이며, 메서드를 호출할 때마다 만들어야 하는 포장이 아닙니다.

객체지향 언어에서는 자식 객체로 부모 클래스의 메서드를 호출하거나, 부모 타입의 변수로 자식 객체를 다룹니다. 두 경우는 겉모습이 비슷하지만 서로 다른 문제입니다. 첫째는 **그 타입에 어떤 메서드가 제공되는가**이고, 둘째는 **호출자가 구체 타입을 모른 채 어떻게 그 메서드를 선택하는가**입니다. Rust에서도 메서드를 제공하는 것과 동적 디스패치를 사용하는 것은 구분됩니다.

이 구분에서 출발하면 소유권 표기의 역할도 분명해집니다. 먼저 trait 메서드를 평범하게 호출하는 경우를 확인하고, 여러 타입을 공통 인터페이스로 처리할 때 `dyn`이 맡는 일을 살펴봅니다. 이어서 같은 값을 빌릴 것인지 소유할 것인지 결정하며 `&`, `Box`, 이동과 `Drop`을 연결합니다.

## 1. Trait 메서드는 구체 타입의 값에서도 바로 호출합니다

Rust의 trait은 타입이 제공할 동작의 계약입니다. 클래스 상속처럼 부모 객체의 필드를 자식 객체에 포함시키는 구조는 아닙니다. 따라서 `impl Describe for Resource`는 “Resource가 Describe의 자식 클래스다”가 아니라 “Resource에 Describe 계약의 구현을 제공한다”는 선언입니다.

이 차이가 매번 특별한 호출 문법을 써야 한다는 뜻은 아닙니다. 아래 예제는 `main`에서 `Resource`를 만들고 곧바로 `resource.describe()`를 호출합니다. `dyn`도 `Box`도 없습니다.

```rust
fn main() {
    let resource = Resource { id: 7 };

    resource.describe();
}

trait Describe {
    fn id(&self) -> u32;

    fn describe(&self) {
        println!("Resource {}", self.id());
    }
}

struct Resource {
    id: u32,
}

impl Describe for Resource {
    fn id(&self) -> u32 {
        self.id
    }
}
```

출력은 `Resource 7`입니다. `Describe`에는 두 메서드가 있습니다. `id`에는 본문이 없으므로 구현 타입이 제공해야 합니다. `describe`에는 본문이 있으므로 구현 타입이 별도로 정의하지 않아도 그 **기본 구현**을 사용할 수 있습니다. 여기서 `Resource`는 `id`만 구현했고, `resource.describe()`는 trait에 작성된 기본 구현을 실행합니다.

기본 구현은 `Resource`의 `id` 필드를 직접 아는 것이 아닙니다. `self.id()`라는 trait 메서드로 필요한 값을 얻습니다. 그 호출이 `Resource`의 구현으로 연결되고, 해당 구현이 필드 값을 반환합니다. 이렇게 공통 동작을 재사용할 수 있지만, 부모 클래스의 필드와 객체 구조까지 물려받는 상속은 아닙니다. Rust 공식 입문서인 *The Rust Programming Language*의 [trait과 기본 구현 설명](https://doc.rust-lang.org/book/ch10-02-traits.html)은 이 두 역할을 이해하는 출발점입니다.

따라서 “부모가 제공하는 메서드를 자식 값에서 호출한다”와 비슷한 사용 경험은 가능합니다. 그러나 Rust에서 대응되는 구조는 자식 클래스가 아니라 trait 구현입니다. 기본 구현을 바꾸고 싶다면 해당 타입의 `impl`에 `describe`를 직접 작성할 수 있습니다. 이 경우에도 호출 형태는 `resource.describe()`입니다.

### 메서드 호출에서 자동으로 처리되는 부분

`describe`의 매개변수는 `&self`입니다. 호출 시에는 `resource.describe()`라고 썼지만, Rust는 이 메서드가 요구하는 참조를 자동으로 빌립니다. 따라서 이 호출은 `resource`의 소유권을 소비하지 않습니다. 반대로 메서드가 `self`를 값으로 받도록 선언되었다면, 같은 점 표기라도 소유권 이동이 발생할 수 있습니다.

이것은 trait object 변환과는 다른 규칙입니다. 메서드 호출에는 수신자에 대한 자동 참조·역참조가 적용됩니다. 반면 `inspect(resource)`처럼 일반 함수의 인수를 전달할 때에는 같은 자동 빌림을 가정할 수 없습니다. 함수가 `&Resource`를 요구하면 `inspect(&resource)`로 빌림을 표현합니다. Rust의 언어 동작을 기술하는 *The Rust Reference*의 [메서드 호출 규칙](https://doc.rust-lang.org/reference/expressions/method-call-expr.html)은 이러한 수신자 처리를 설명합니다.

또 다른 모듈에 정의된 trait의 메서드를 점 표기로 호출할 때에는 보통 그 trait을 `use`로 현재 범위에 가져옵니다. 위 예제는 같은 범위에 trait이 있으므로 별도 `use`가 없습니다. 이 가져오기는 컴파일러가 메서드를 찾도록 하는 이름 해석 규칙이지, 값의 변환이나 런타임 등록 작업이 아닙니다.

## 2. dyn은 메서드의 존재가 아니라 호출 경로를 바꿉니다

앞 예제의 컴파일러는 `resource`의 타입이 `Resource`임을 압니다. 필요한 구현을 그 타입에 맞게 결정할 수 있으므로, 단순한 메서드 호출을 위해 구체 타입을 감출 이유가 없습니다.

이제 한 함수가 `Describe`를 구현한 여러 타입을 처리해야 한다고 가정합니다. 이때도 곧바로 `dyn`이 필요한 것은 아닙니다. **제네릭 함수**와 **trait object를 받는 함수**라는 두 경로가 있습니다. 앞의 trait·구조체·구현은 그대로 두고, `main`을 다음 코드로 바꾼 뒤 두 함수를 추가합니다.

```rust
fn main() {
    let resource = Resource { id: 7 };

    show_static(&resource);
    show_dynamic(&resource);
}

fn show_static<T: Describe>(value: &T) {
    value.describe();
}

fn show_dynamic(value: &dyn Describe) {
    value.describe();
}
```

두 호출 모두 `Resource 7`을 출력합니다. 하지만 함수가 타입을 다루는 방식은 다릅니다.

`T: Describe`는 “T는 Describe를 구현하는 타입이어야 한다”는 제약입니다. `show_static(&resource)`에서는 `T`가 `Resource`로 정해집니다. Rust는 이렇게 결정된 구체 타입에 맞춰 제네릭 코드를 구체화하며, 이 예제의 메서드 구현을 정적으로 선택할 수 있습니다. 여러 타입에서 재사용하는 코드라고 해서 반드시 동적 디스패치가 발생하는 것은 아닙니다.

반면 `show_dynamic`의 매개변수 타입은 `&dyn Describe`입니다. 함수는 `Resource`라는 이름 대신 trait의 계약으로 값을 다룹니다. `Describe`를 구현한 다른 타입도 같은 매개변수 타입을 통해 전달할 수 있습니다. 이때 실제 값의 타입에 맞는 구현을 메타데이터를 통해 선택하는 것이 **동적 디스패치**입니다.

여기서 호출부도 중요합니다. `show_dynamic(&resource)`에는 명시적인 `as` 변환이 없습니다. 함수의 매개변수가 요구하는 타입을 보고 컴파일러가 `&Resource`를 `&dyn Describe`로 변환합니다. 즉, Rust가 모든 변환 과정을 호출부에 직접 쓰도록 요구하는 것은 아닙니다. 이 예제에서 명시한 것은 **함수가 trait object를 받는다는 API 선언**과 **호출자가 값을 빌려 준다는 `&`**입니다.

C#에서 부모 클래스나 인터페이스 타입의 매개변수에 객체를 전달할 때, 호출부에 형 변환을 쓰지 않는 경우와 비교할 수 있습니다. 다만 Rust에는 클래스 상속이 없고, 인터페이스 사용과 객체의 소유 방식이 별도로 표현됩니다. `dyn`을 없애면 반드시 못 부르는 것이 아니라, 제네릭처럼 구체 타입을 유지하는 다른 방식을 선택할 수 있다는 점이 중요합니다.

이는 컴파일러가 변환을 자동화할 수 없어서 생긴 문법적 한계가 아닙니다. Rust는 구체 타입을 유지하는 제네릭과, 구체 타입을 감추는 trait object를 서로 다른 타입 형태로 표현합니다. 전자는 구체 타입별 구현 선택을 허용하고, 후자는 서로 다른 구현을 하나의 인터페이스 타입으로 다룰 수 있게 합니다. `dyn`은 그 선택을 API에서 드러내는 표기입니다. 여기에 값을 빌리는지 소유하는지까지 자동으로 하나로 결정하지 않고, `&`나 `Box`로 따로 표현합니다.

`dyn`의 이점은 서로 다른 구체 타입을 같은 인터페이스 타입으로 다뤄야 할 때 드러납니다. 예를 들어 서로 다른 구현들을 참조하는 `Vec<&dyn Describe>`를 만들 수 있습니다. 반면 `Vec<T>` 하나의 `T`는 한 구체 타입으로 정해집니다. Rust 입문서의 [trait object 장](https://doc.rust-lang.org/book/ch18-02-trait-objects.html)은 이러한 공통 인터페이스와 제네릭의 차이를 설명하고 있습니다.

### Trait object가 보존하는 정보

`dyn Describe`는 **trait object 타입**입니다. 구체 타입을 인터페이스 뒤로 감추어도 실제 `Resource` 값이 다른 종류의 값으로 바뀌는 것은 아닙니다. `dyn`은 런타임에 아무 이름의 메서드나 검색하는 기능도 아닙니다. 호출 가능한 메서드는 trait의 계약으로 컴파일 시점에 검사됩니다.

trait object를 가리키는 포인터에는 대상 데이터의 위치와 해당 타입의 구현을 연결하는 메타데이터가 필요합니다. 이때 사용하는 **vtable**은 컴파일러가 준비하는 구현 선택 정보입니다. `value.describe()`는 이 정보를 통해 실제 대상에 맞는 구현으로 연결됩니다.

```text
&dyn Describe
  ├─ 데이터 포인터 ──▶ 실제 Resource 값
  └─ 메타데이터    ──▶ Resource의 Describe 구현 등에 대한 정보
```

Reference의 [trait object 설명](https://doc.rust-lang.org/reference/types/trait-object.html)은 데이터 포인터와 vtable을 통해 이 관계를 설명합니다. 그림은 개념적 관계이며, 고정된 vtable 바이너리 배치를 프로그램 외부에 공개한다는 뜻은 아닙니다. 컴파일러가 실제 대상을 알아낼 수 있다면 동적 호출을 최적화할 수도 있습니다.

`Describe`를 구현하는 타입마다 크기가 다를 수 있으므로 `dyn Describe` 자체에는 하나로 고정된 컴파일 타임 크기가 없습니다. 이런 타입을 **동적 크기 타입(DST)**이라고 합니다. 일반적인 지역 변수나 값 매개변수처럼 크기가 정해져야 하는 자리에 그대로 저장하지 않고, 크기가 정해진 포인터를 통해 다룹니다. 여기서는 `&dyn Describe`라는 참조를 사용했습니다.

모든 trait이 trait object로 사용 가능한 것은 아닙니다. 예를 들어 객체를 통해 호출할 메서드가 타입 매개변수를 갖는 경우에는 제약이 있습니다. 위의 `Describe`는 사용 가능하며, 복잡한 인터페이스의 정확한 조건은 [dyn compatibility 규칙](https://doc.rust-lang.org/reference/items/traits.html#dyn-compatibility)에 정의되어 있습니다.

그러나 포인터로 접근한다는 사실만으로 값의 소유권까지 정해지지는 않습니다. `&resource`로 만든 참조는 값을 빌릴 뿐이고, `dyn`으로 변환해도 그 값의 소유자가 되지 않습니다. 함수가 호출자에게 돌아온 뒤에도 값을 보관하거나, 호출자에게서 값을 완전히 인수하려면 **구체 타입을 아는가**와 별도로 **값을 누가 소유하는가**를 결정해야 합니다. 이제 `Box`가 맡는 문제가 시작됩니다.

## 3. 값, 저장 위치, 소유자는 서로 다릅니다

앞의 `show_static`과 `show_dynamic`은 모두 참조를 받았으므로 값을 정리할 책임을 인수하지 않았습니다. 이 사실은 정적·동적 디스패치와 무관합니다. 호출자가 값의 소유권까지 전달하는 경우를 구분하려면 먼저 이동을 살펴봐야 합니다.

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

## 4. Box는 무엇을 저장하고 소유합니까

값을 다른 함수에 이동하려고 반드시 `Box`를 사용할 필요는 없습니다. 앞의 `String`처럼 값 자체도 이동할 수 있습니다. `Box`는 그중에서도 값의 저장 공간을 힙에 두고, 그 공간을 소유하는 포인터를 이동하고 싶을 때 사용합니다.

힙은 실행 중에 필요한 저장 공간을 할당하고 해제할 수 있는 메모리 영역입니다. `Box::new(value)`는 일반적인 크기가 0이 아닌 값에 대해 힙 공간을 확보하고, 그곳에 값을 저장하며, 그 공간을 소유하는 `Box`를 반환합니다.

```rust
fn main() {
    let first: Box<u32> = Box::new(7);
    let second: Box<u32> = first;

    println!("{}", *second);
}
```

`Box<u32>` 값과 힙에 저장된 `u32` 값은 구분해야 합니다. `first`에 있던 것은 힙의 숫자를 소유하는 포인터 값입니다. 대입 뒤에는 `second`가 그 포인터 값을 인수합니다. 힙의 숫자를 새로 할당하거나 복제하지 않습니다. `*second`는 포인터가 가리키는 숫자에 접근하는 역참조입니다. 여기서 힙 할당의 소유권은 하나지만, 소유자가 허용한 빌린 참조까지 존재할 수 없다는 뜻은 아닙니다.

```text
Box::new(7) 이후
first  ──소유──▶ 힙 할당: u32 값 7

let second = first 이후
first: 이동되어 사용할 수 없음
second ──소유──▶ 동일한 힙 할당: u32 값 7
```

이런 간접 저장은 큰 값을 여러 함수 사이에서 전달하거나, 크기가 재귀적으로 정의되는 자료구조를 구성할 때 유용합니다. 이동하는 것은 `Box`의 작은 포인터 표현이고, 그 이동만으로 힙의 값이 다른 위치로 옮겨지지는 않습니다. Rust 입문서의 [Box 장](https://doc.rust-lang.org/book/ch15-01-box.html)에서는 이와 같은 사용 목적을 설명하고 있습니다.

`Box` 자체가 반드시 스택에 있어야 하는 것은 아닙니다. 지역 변수일 수도 있고, 다른 구조체의 필드나 벡터의 원소일 수도 있습니다. 또한 크기가 0인 타입에는 실제 힙 할당이 필요하지 않습니다. 여기서는 메모리 관계를 분명하게 보기 위해 크기가 0이 아닌 값을 다룹니다. 표준 라이브러리의 [boxed 문서](https://doc.rust-lang.org/std/boxed/index.html)는 할당과 메모리 표현의 조건을 명시하고 있습니다.

## 5. 함수에 Box를 전달하면 정리 책임도 이동합니다

앞에서 `resource.describe()`의 자동 빌림과 `show_dynamic(&resource)`의 명시적 빌림을 구분했습니다. `Box`를 사용해도 같은 구분을 적용합니다.

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

## 6. Drop은 값의 정리이며, 할당 해제와는 구분됩니다

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

이 과정은 더 이상 사용하지 않는 힙 객체를 실행 중에 찾아내는 가비지 컬렉션과 다릅니다. 일반적인 `Box` 이동에는 참조 카운트를 늘리거나 줄이는 동작도 없습니다. 컴파일러가 소유권 흐름에 맞춰 배치한 정리 코드가 실행됩니다. 빌린 참조가 유효한 동안 소유자를 정리해서 참조 대상을 없애려는 코드는 안전한 Rust에서 허용되지 않습니다.

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

## 7. `Box<dyn Trait>`에서도 이동과 Drop의 규칙은 유지됩니다

이제 구체 타입을 감추는 인터페이스와 값의 소유권을 결합할 수 있습니다. `&dyn Describe`는 대상을 빌리는 참조이고, `Box<dyn Describe>`는 대상을 소유하는 포인터입니다. `dyn` 자체가 힙 할당을 요구하는 것은 아니며, 앞의 지역 변수 빌림에는 `Box`가 없었습니다. 다음은 별도로 실행할 수 있는 전체 예제입니다. `main`의 한 줄씩을 따라가면 구체 타입을 가진 `Box`가 trait object를 소유하는 `Box`로 바뀌고, 다른 함수로 이동한 다음 정리되는 과정이 드러납니다.

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
    fn id(&self) -> u32;

    fn describe(&self) {
        println!("Resource {}", self.id());
    }
}

struct Resource {
    id: u32,
}

impl Describe for Resource {
    fn id(&self) -> u32 {
        self.id
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

별도의 `concrete` 변수가 필요 없다면 `let object: Box<dyn Describe> = Box::new(Resource { id: 7 });`처럼 한 줄로 쓸 수 있습니다. 여기서 두 줄로 나눈 것은 변환 전후를 관찰하기 위해서입니다. `Box<Resource>` 상태에서도 `concrete.describe()`를 호출할 수 있습니다. 그 경우에는 메서드 수신자의 자동 역참조가 적용되며, `dyn` 변환이 호출의 선행 조건이 아닙니다.

`show(&*object)`에서는 `Box`가 가리키는 대상을 `&dyn Describe`로 빌립니다. `show`가 돌아와도 `object`가 소유자이므로 대상은 남아 있습니다. 이어서 `consume(object)`가 `Box`를 값으로 받으면 소유권은 매개변수 `value`로 이동합니다. 이 함수는 `Box`를 반환하지 않습니다. 따라서 함수 끝에서 `value`가 정리되며, 호출자가 다음 줄을 실행하기 전에 `drop Resource 7`이 출력됩니다.

`consume`에는 `Resource`라는 타입 이름이 없지만 실제 값은 여전히 `Resource`입니다. trait object의 런타임 메타데이터를 통해 그 실제 타입에 맞는 정리 경로를 사용합니다. `Resource::drop`을 실행하고 필드를 정리한 다음, `Box`가 할당을 해제합니다. `Describe`의 메서드를 선택하는 경로와 값을 정리하는 경로는 별개입니다. 이것은 `Describe`에 `drop` 메서드를 추가해서 구현하는 동작이 아닙니다. trait object를 정리할 때 내부 구체 타입의 destructor를 실행하는 Rust의 규칙입니다.

여기까지의 소유권 변화를 요약하면 다음과 같습니다.

| 시점 | Box 값을 소유하는 위치 | 힙의 Resource | 정리 여부 |
| --- | --- | --- | --- |
| 생성 직후 | `concrete` | 새로 생성됨 | 아직 아님 |
| trait object 변환 후 | `object` | 같은 값, 같은 할당 | 아직 아님 |
| `show` 실행 중 | 여전히 `object` | 빌려 읽음 | 아직 아님 |
| `consume` 실행 중 | 매개변수 `value` | 같은 값, 같은 할당 | 아직 아님 |
| `consume` 종료 | 소유권이 소비됨 | destructor 실행 후 할당 해제 | 한 번 실행 |

## 8. Box를 이동하는 것과 내부 값을 꺼내는 것은 다릅니다

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

## 9. `Box<dyn Error>`는 같은 규칙을 오류에 적용한 형태입니다

[`Error`](https://doc.rust-lang.org/std/error/trait.Error.html)는 표준 라이브러리에서 오류를 표현하기 위해 제공하는 trait입니다. `Result<(), Box<dyn std::error::Error>>`는 성공할 때 `()`를, 실패할 때 `Error`를 구현한 어떤 구체 오류 값을 소유하는 `Box`를 반환한다는 뜻입니다.

`Result`의 오류 타입 매개변수는 하나로 정해져야 합니다. 서로 다른 구체 오류를 같은 반환 타입으로 전달하고 싶을 때 `Box<dyn Error>`를 사용할 수 있습니다. 구체 오류 타입 하나로 충분하다면 이 조합을 쓸 필요는 없으며, 오류 종류를 enum으로 정의하는 선택도 가능합니다.

이 타입을 사용한다고 오류 객체에 특별한 수명 규칙이 생기지는 않습니다. `Err(boxed_error)`로 반환하면 `Box`의 소유권이 `Result` 안으로 이동하고, 반환된 `Result`의 소유권이 호출자에게 이동합니다. 호출자가 오류를 다른 곳으로 이동하지 않고 정리하면 내부 구체 오류 타입의 정리와 힙 할당 해제가 진행됩니다. 오류 메시지를 출력하는 행위와 오류 값을 정리하는 행위는 서로 다른 동작입니다.

`Box`는 오류 전용 기능도, 참조 카운트 기반 공유 소유권도 아닙니다. `dyn` 역시 소유권 이동을 대신하는 기능이 아닙니다. 코드에서 확인할 것은 **어떤 값을 누가 소유하는지**, **현재 연산이 이동인지 빌림인지**, **구체 타입을 직접 사용하는지 trait object를 사용하는지**입니다. 이 세 가지를 구분하면 `Box<dyn Trait>`의 메서드 호출과 정리 과정을 같은 원리로 추적할 수 있습니다.
