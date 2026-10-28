#include "gradient.hpp"
#include <cassert>
#include <iostream>
struct View { const Gradient& data; };
struct Watched {
    inline static int alive = 0;
    Gradient data{0, 255};
    Watched() { ++alive; }
    ~Watched() { --alive; }
};
Watched make_watched() { return Watched{}; }
const Watched& identity(const Watched& value) { return value; }
int main() {
    Gradient data{0, 255};
    const Gradient* saved = nullptr;
    { View view{data}; saved = &view.data; }
    assert(saved == &data);
    std::cout << "outer target: " << saved->start << '\n';
    {
        const Watched& direct = make_watched();
        assert(Watched::alive == 1 && direct.data.end == 255);
        std::cout << "direct temporary alive: " << Watched::alive << '\n';
    }
    assert(Watched::alive == 0);
    std::cout << "after block: " << Watched::alive << '\n';
    {
        [[maybe_unused]] const Watched& dangling = identity(make_watched());
        assert(Watched::alive == 0);
        std::cout << "forwarded temporary alive: " << Watched::alive << '\n';
        // Do not access dangling: its target has already been destroyed.
    }
}
