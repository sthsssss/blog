#include "gradient.hpp"
struct IntView { int& value; };
extern "C" int copy_int(int original) { int copy = original; return copy + 1; }
extern "C" int read_pointer(int* p) { return *p; }
extern "C" int* pointer_identity(int* p) { return p; }
extern "C" void set_reference(int& value) { value = 100; }
extern "C" int read_const_reference(const int& value) { return value; }
extern "C" int gradient_by_value(Gradient value) { return value.start; }
Gradient copy_gradient(const Gradient& source) { return source; }
Gradient& ref_gradient(Gradient& source) { return source; }
extern "C" int local_reference(int x) { int& r = x; return r + 1; }
extern "C" int member_reference(int x) { IntView view{x}; return view.value + 1; }
extern "C" int dynamic_reference(bool choose_a, int& a, int& b) {
    IntView view{choose_a ? a : b};
    return view.value;
}
extern "C" int read_existing(const IntView& view) { return view.value; }
extern "C" int inlined_call(int x) { IntView view{x}; return read_existing(view) + 1; }
extern "C" void observe(const IntView& view);
extern "C" void materialize_for_call(int& x) { IntView view{x}; observe(view); }
extern "C" int pointer_equivalent(int x) { int* p = &x; return *p + 1; }
extern "C" int by_value_view(IntView view) { return view.value; }
extern "C" unsigned long view_size() { return sizeof(IntView); }
struct Big { int values[8]; };
Big make_big() { return Big{{1, 2, 3, 4, 5, 6, 7, 8}}; }
