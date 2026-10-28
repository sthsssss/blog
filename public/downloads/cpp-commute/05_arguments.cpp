#include "gradient.hpp"
#include <cassert>
#include <iostream>
#include <span>
int change_copy(Gradient value) { value.start = 100; return value.start; }
void change_ref(Gradient& value) { value.start = 100; }
void change_pointer(Gradient* value) { value->start = 200; }
void redirect_copy(Gradient* value, Gradient& other) { value = &other; (void)value; }
void redirect_ref(Gradient*& value, Gradient& other) { value = &other; }
void fill(std::span<int> values) { for (int& value : values) { value = 7; } }
int main() {
    Gradient data{0, 255};
    const int local_result = change_copy(data);
    assert(data.start == 0 && local_result == 100);
    std::cout << "value argument: " << data.start << ' ' << local_result << '\n';
    change_ref(data);
    std::cout << "reference argument: " << data.start << '\n';
    change_pointer(&data);
    assert(data.start == 200);
    std::cout << "pointer argument: " << data.start << '\n';
    Gradient other{10, 20};
    Gradient* p = &data;
    redirect_copy(p, other);
    assert(p == &data);
    redirect_ref(p, other);
    assert(p == &other);
    std::cout << std::boolalpha << "pointer redirected: " << (p == &other) << '\n';
    int values[]{1, 2, 3};
    fill(std::span<int>{values});
    assert(values[0] == 7 && values[2] == 7);
    const std::span<int> fixed_view{values};
    fixed_view[0] = 9;
    assert(values[0] == 9);
    std::cout << "range passed by value: " << values[0] << ' ' << values[1] << ' ' << values[2] << '\n';
}
