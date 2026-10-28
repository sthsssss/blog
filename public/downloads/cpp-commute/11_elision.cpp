#include <cassert>
#include <iostream>
#include <utility>
struct Packet {
    inline static int copies = 0;
    inline static int moves = 0;
    int value;
    explicit Packet(int v) : value(v) {}
    Packet(const Packet& other) : value(other.value) { ++copies; }
    Packet(Packet&& other) noexcept : value(other.value) { ++moves; }
};
Packet direct() { return Packet{7}; }
Packet named() { Packet result{7}; return result; }
Packet passthrough(Packet value) { return value; }
void reset() { Packet::copies = 0; Packet::moves = 0; }
void report(const char* name) {
    std::cout << name << ": copies=" << Packet::copies << ", moves=" << Packet::moves << '\n';
}
int main() {
    reset();
    Packet a = direct();
    assert(a.value == 7 && Packet::copies == 0 && Packet::moves == 0);
    report("direct");
    reset();
    Packet b = named();
    assert(b.value == 7 && Packet::copies == 0 && Packet::moves <= 1);
    report("named");
    reset();
    Packet c = passthrough(a);
    assert(c.value == 7 && Packet::copies == 1 && Packet::moves == 1);
    report("parameter");
}
