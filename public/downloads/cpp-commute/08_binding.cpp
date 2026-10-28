#include "gradient.hpp"
#include <cassert>
#include <iostream>
#include <type_traits>
#include <utility>
Gradient make_gradient() { return Gradient{0, 255}; }
const Gradient make_const_gradient() { return Gradient{0, 255}; }
int main() {
    Gradient data{0, 255};
    Gradient& edit = data;
    const Gradient& read = data;
    Gradient&& candidate = std::move(data);
    candidate.start = 100;
    assert(&edit == &read && &candidate == &data && data.start == 100);
    std::cout << "same object: " << data.start << '\n';
    const Gradient& temporary_read = make_gradient();
    Gradient&& temporary_edit = make_gradient();
    temporary_edit.start = 200;
    assert(temporary_read.start == 0 && temporary_edit.start == 200);
    std::cout << "temporary bindings: " << temporary_read.start << ' ' << temporary_edit.start << '\n';
    const Gradient frozen{10, 20};
    const Gradient& fallback = std::move(frozen);
    static_assert(std::is_same_v<decltype(std::move(frozen)), const Gradient&&>);
    assert(&fallback == &frozen);
    auto copy = read;
    auto& alias = read;
    const auto& explicit_read = data;
    copy.start = 300;
    data.start = 150;
    static_assert(std::is_same_v<decltype(copy), Gradient>);
    static_assert(std::is_same_v<decltype(alias), const Gradient&>);
    static_assert(std::is_same_v<decltype(explicit_read), const Gradient&>);
    std::cout << "auto: " << copy.start << ' ' << alias.start << '\n';
    Gradient mutable_result = make_const_gradient();
    mutable_result.start = 200;
    assert(mutable_result.start == 200);
}
