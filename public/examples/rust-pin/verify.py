#!/usr/bin/env python3
"""Compile and run the Rust Pin article examples; require rustc on PATH."""
from pathlib import Path
import subprocess
import tempfile

CASES = [
    ('move_before_pin', r"""async fn hello() {
    println!("hello");
}

fn main() {
    let future = hello();
    let a = future;
    drop(a);
}
""", ''),
    ('box_move', r"""struct Buffer {
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
""", '힙의 배열 주소 유지: true\n'),
    ('replace', r"""use std::mem;

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
""", '꺼낸 값: 1\n원래 위치의 값: 99\n'),
    ('unpin', r"""use std::pin::Pin;

fn main() {
    let mut number = 10_u32;
    let pinned = Pin::new(&mut number);

    let ordinary: &mut u32 = pinned.get_mut();
    let old = std::mem::replace(ordinary, 20);

    println!("꺼낸 숫자: {old}, 현재 숫자: {number}");
}
""", '꺼낸 숫자: 10, 현재 숫자: 20\n'),
    ('poll_twice', r"""use std::future::{poll_fn, Future};
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
""", 'Future 생성 완료\ninspect: 잠시 중단\n첫 poll: Pending\ninspect: 참조로 읽은 값 = 10\n둘째 poll: Ready(10)\n'),
    ('move_pinned_box', r"""use std::future::Future;
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
""", 'Pin<Box<F>> 이동 후에도 Future 주소 유지\n'),
]
FAILURES = [
    ('new_requires_unpin', r"""use std::pin::Pin; async fn hello() {} fn main() { let mut f = hello(); let _p = Pin::new(&mut f); }""", 'E0277'),
    ('get_mut_requires_unpin', r"""use std::pin::pin; async fn hello() {} fn main() { let p = pin!(hello()); let _ordinary = p.get_mut(); }""", 'E0277'),
    ('into_inner_requires_unpin', r"""use std::pin::Pin; async fn hello() {} fn main() { let p = Box::pin(hello()); let _b = Pin::into_inner(p); }""", 'E0277'),
    ('old_binding_moved', r"""use std::pin::pin; async fn hello() {} fn main() { let f = hello(); let _p = pin!(f); drop(f); }""", 'E0382'),
    ('poll_without_reborrow', r"""use std::{future::Future,pin::pin,task::{Context,Waker}}; async fn hello() {} fn main() { let p = pin!(hello()); let mut cx = Context::from_waker(Waker::noop()); let _first = p.poll(&mut cx); let _second = p.poll(&mut cx); }""", 'E0382'),
]

print(subprocess.check_output(["rustc", "--version"], text=True).strip())
with tempfile.TemporaryDirectory(prefix="rust-pin-examples-") as directory:
    root = Path(directory)
    for name, source, expected in CASES:
        path = root / (name + ".rs")
        binary = root / name
        path.write_text(source, encoding="utf-8")
        result = subprocess.run(["rustc", "--edition=2024", "-D", "warnings", str(path), "-o", str(binary)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(name + "\n" + result.stderr)
        result = subprocess.run([str(binary)], capture_output=True, text=True)
        if result.returncode or result.stdout != expected:
            raise RuntimeError(name + " output mismatch: " + repr(result.stdout) + result.stderr)
        print("PASS", name)
    for name, source, expected_error in FAILURES:
        path = root / (name + ".rs")
        path.write_text(source, encoding="utf-8")
        result = subprocess.run(["rustc", "--edition=2024", str(path), "-o", str(root / name)], capture_output=True, text=True)
        if result.returncode == 0 or ("error[" + expected_error + "]") not in result.stderr:
            raise RuntimeError(name + " did not produce " + expected_error + "\n" + result.stderr)
        print("PASS", name, expected_error)
print("6 executable examples and 5 expected compilation failures verified.")
