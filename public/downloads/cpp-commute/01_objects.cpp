#include "gradient.hpp"
#include <cassert>
#include <iostream>
int main() {
    Gradient data{0, 255};
    Gradient copy = data;
    copy.start = 100;
    assert(data.start == 0 && copy.start == 100);
    std::cout << "copy: " << data.start << ' ' << copy.start << '\n';
    Gradient assigned{10, 20};
    assigned = data;
    assigned.end = 200;
    assert(data.end == 255 && assigned.end == 200);
    std::cout << "assignment: " << data.end << ' ' << assigned.end << '\n';
}
