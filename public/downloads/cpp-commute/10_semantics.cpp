#include <iostream>
#include <memory>
#include <utility>
#include <vector>

struct Gradient { int start; int end; };
struct GradientView { Gradient* target; };
struct Palette { std::vector<int> colors; };

void inspect(const std::vector<int>& values) {
    std::cout << "const &: " << values.size() << '\n';
}
void inspect(std::vector<int>&& values) {
    std::cout << "&&: " << values.size() << '\n';
}

int main() {
    Palette a{{10, 20, 30}};
    Palette b = a;
    b.colors[0] = 99;
    std::cout << "value semantics: " << a.colors[0] << ' ' << b.colors[0] << '\n';

    Gradient data{0, 255};
    GradientView first{&data};
    GradientView second = first;
    second.target->start = 100;
    std::cout << "copied view: " << first.target->start << ' ' << second.target->start << '\n';

    std::vector<int> source{10, 20, 30};
    inspect(source);
    inspect(std::move(source));
    std::cout << "after inspect: " << source.size() << '\n';
    int* original_storage = source.data();
    std::vector<int> destination = std::move(source);
    std::cout << std::boolalpha << "same storage: " << (destination.data() == original_storage) << '\n';
    source = {7};
    std::cout << "after reassignment: " << source[0] << ' ' << destination[0] << '\n';

    std::vector<int>&& alias = std::move(destination);
    inspect(alias);

    std::unique_ptr<Gradient> owner = std::make_unique<Gradient>(Gradient{0, 255});
    Gradient* observer = owner.get();
    std::unique_ptr<Gradient> next_owner = std::move(owner);
    std::cout << "owner empty: " << (owner == nullptr) << '\n';
    std::cout << "observer still points: " << (observer == next_owner.get()) << '\n';

    const std::vector<int> frozen{10, 20, 30};
    std::vector<int> from_const = std::move(frozen);
    from_const[0] = 99;
    std::cout << "move from const copies: " << frozen[0] << ' ' << from_const[0] << '\n';
}
