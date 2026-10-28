#include "gradient.hpp"
#include <cassert>
#include <iostream>
struct GradientView { Gradient& data; };
int main() {
    Gradient data{0, 255};
    Gradient& alias = data;
    alias.start = 100;
    Gradient& second = alias;
    second.end = 200;
    assert(&alias == &data && &second == &data);
    std::cout << "aliases: " << data.start << ' ' << data.end << '\n';
    Gradient other{10, 20};
    alias = other;
    alias.start = 50;
    assert(&alias == &data && other.start == 10);
    std::cout << "assignment: " << data.start << ' ' << data.end << ' ' << other.start << '\n';
    GradientView view{data};
    GradientView copied_view = view;
    copied_view.data.start = 75;
    assert(&view.data == &copied_view.data && data.start == 75);
    std::cout << "copied view: " << data.start << '\n';
}
