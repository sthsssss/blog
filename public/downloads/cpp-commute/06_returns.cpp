#include "gradient.hpp"
#include <cassert>
#include <iostream>
Gradient get_copy(const Gradient& source) { return source; }
Gradient& get_ref(Gradient& source) { return source; }
const Gradient& get_readonly(const Gradient& source) { return source; }
Gradient make_gradient() { return Gradient{0, 255}; }
struct Owner {
    Gradient data{0, 255};
    Gradient& get_ref() { return data; }
    const Gradient& get_ref() const { return data; }
};
int main() {
    Gradient original{0, 255};
    Gradient copy = get_copy(original);
    copy.start = 100;
    assert(original.start == 0 && copy.start == 100);
    std::cout << "value return: " << original.start << ' ' << copy.start << '\n';
    Gradient& alias = get_ref(original);
    alias.start = 150;
    assert(&alias == &original);
    Gradient another_copy = get_ref(original);
    another_copy.start = 200;
    std::cout << "reference return: " << original.start << ' ' << another_copy.start << '\n';
    const Gradient& read = get_readonly(original);
    original.start = 180;
    Gradient independent = get_readonly(original);
    independent.start = 250;
    assert(read.start == 180 && independent.start == 250);
    std::cout << "const return path: " << read.start << ' ' << independent.start << '\n';
    Gradient made = make_gradient();
    assert(made.start == 0 && made.end == 255);
    Owner owner;
    owner.get_ref().start = 75;
    const Owner frozen;
    assert(owner.data.start == 75 && frozen.get_ref().start == 0);
    std::cout << "owned member: " << owner.data.start << '\n';
}
