#include "gradient.hpp"
#include <cassert>
#include <iostream>
struct Owner { Gradient data; };
struct PointerView { Gradient* target; };
struct ReferenceView { Gradient& target; };
struct MeasuredGradient {
    int start;
    int end;
    int width() const { return end - start; }
};
int main() {
    Gradient data{0, 255};
    const Gradient& read = data;
    data.start = 100;
    assert(read.start == 100);
    std::cout << "read-only path: " << read.start << '\n';
    Gradient other{10, 20};
    const Gradient* p = &data;
    p = &other;
    Gradient* const fixed = &data;
    fixed->start = 120;
    assert(p == &other && data.start == 120);
    std::cout << "pointer layers: " << p->start << ' ' << data.start << '\n';
    const PointerView pointer_view{&data};
    pointer_view.target->start = 150;
    const ReferenceView reference_view{data};
    reference_view.target.start = 180;
    const Owner owner{{0, 255}};
    assert(owner.data.start == 0 && data.start == 180);
    std::cout << "external target: " << data.start << '\n';
    const MeasuredGradient measured{0, 255};
    std::cout << "const member function: " << measured.width() << '\n';
}
