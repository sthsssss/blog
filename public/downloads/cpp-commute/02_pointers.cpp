#include "gradient.hpp"
#include <cassert>
#include <iostream>
int main() {
    Gradient data{0, 255};
    Gradient* p = &data;
    Gradient* q = p;
    q->start = 100;
    assert(data.start == 100 && p == q);
    std::cout << "same target: " << data.start << ' ' << p->start << '\n';
    Gradient other{10, 20};
    q = &other;
    q->start = 200;
    assert(p == &data && q == &other && data.start == 100);
    std::cout << "redirected: " << data.start << ' ' << other.start << '\n';
    int values[]{10, 20, 30};
    int* first = values;
    first[1] = 99;
    assert(values[1] == 99);
    std::cout << "array: " << values[0] << ' ' << values[1] << ' ' << values[2] << '\n';
}
