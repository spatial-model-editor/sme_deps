#include <vector>
#include <algorithm>
#include <execution>

int main(){

std::vector<double> v(6000000, 0.5);
return static_cast<int>(std::reduce(std::execution::par_unseq, v.begin(), v.end(), 0.0));
}
