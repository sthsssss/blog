#include "gradient.hpp"
#include <iostream>
#include <type_traits>
#include <utility>
Gradient make_gradient() { return Gradient{0, 255}; }
Gradient& get_ref(Gradient& g) { return g; }
const Gradient& get_readonly(const Gradient& g) { return g; }
const char* inspect(Gradient&) { return "mutable lvalue"; }
const char* inspect(const Gradient&) { return "const lvalue or fallback"; }
const char* inspect(Gradient&&) { return "rvalue"; }
int main() {
    Gradient data{0, 255};
    const Gradient frozen{0, 255};
    Gradient&& named = std::move(data);
    static_assert(std::is_same_v<decltype((data)), Gradient&>);
    static_assert(std::is_same_v<decltype((frozen)), const Gradient&>);
    static_assert(std::is_same_v<decltype(make_gradient()), Gradient>);
    static_assert(std::is_same_v<decltype(std::move(data)), Gradient&&>);
    static_assert(std::is_same_v<decltype((named)), Gradient&>);
    static_assert(std::is_same_v<decltype(get_ref(data)), Gradient&>);
    static_assert(std::is_same_v<decltype(get_readonly(data)), const Gradient&>);
    std::cout << "name: " << inspect(data) << '\n';
    std::cout << "const name: " << inspect(frozen) << '\n';
    std::cout << "new result: " << inspect(make_gradient()) << '\n';
    std::cout << "move expression: " << inspect(std::move(data)) << '\n';
    std::cout << "named rvalue reference: " << inspect(named) << '\n';
}
