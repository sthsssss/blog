#include "gradient.hpp"
#include <cassert>
#include <iostream>
struct IntView { int& value; };
extern "C" int copy_int(int);
extern "C" int read_pointer(int*);
extern "C" int* pointer_identity(int*);
extern "C" void set_reference(int&);
extern "C" int read_const_reference(const int&);
extern "C" int gradient_by_value(Gradient);
Gradient copy_gradient(const Gradient&);
Gradient& ref_gradient(Gradient&);
extern "C" int local_reference(int);
extern "C" int member_reference(int);
extern "C" int dynamic_reference(bool, int&, int&);
extern "C" int read_existing(const IntView&);
extern "C" int inlined_call(int);
extern "C" void materialize_for_call(int&);
extern "C" int pointer_equivalent(int);
extern "C" int by_value_view(IntView);
extern "C" unsigned long view_size();
struct Big { int values[8]; };
Big make_big();
int observed = 0;
extern "C" void observe(const IntView& view) { observed = view.value; }
int main() {
    int a = 10, b = 20;
    IntView view{a};
    assert(copy_int(a) == 11 && read_pointer(&a) == 10 && pointer_identity(&a) == &a);
    assert(local_reference(a) == 11 && member_reference(a) == 11 && pointer_equivalent(a) == 11);
    assert(dynamic_reference(true, a, b) == 10 && dynamic_reference(false, a, b) == 20);
    assert(read_existing(view) == 10 && inlined_call(a) == 11 && by_value_view(view) == 10);
    materialize_for_call(b);
    assert(observed == 20);
    Gradient data{0, 255};
    Gradient copy = copy_gradient(data);
    copy.start = 75;
    ref_gradient(data).start = 100;
    assert(data.start == 100 && copy.start == 75 && gradient_by_value(data) == 100);
    set_reference(a);
    assert(read_const_reference(a) == 100);
    const Big big = make_big();
    assert(big.values[0] == 1 && big.values[7] == 8);
    std::cout << "optimizer examples: PASS\n";
    std::cout << "IntView layout bytes: " << view_size() << '\n';
}
