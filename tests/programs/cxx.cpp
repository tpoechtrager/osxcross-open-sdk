#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <stdexcept>
#include <thread>
#include <mutex>
#include <atomic>
#include <algorithm>
#include <sstream>

struct Thing { std::string name; int v; };

int main() {
  std::vector<int> v{5, 3, 9, 1};
  std::sort(v.begin(), v.end());
  std::map<std::string, Thing> m;
  m["a"] = {"alpha", v[0]};
  m["b"] = {"beta", v[3]};
  std::ostringstream os;
  for (auto &kv : m) os << kv.first << "=" << kv.second.name << ":" << kv.second.v << " ";
  std::cout << os.str() << std::endl;

  try { throw std::runtime_error("boom"); }
  catch (const std::exception &e) { std::cout << "caught " << e.what() << std::endl; }

  std::atomic<int> counter{0};
  std::mutex mu;
  std::vector<std::thread> ts;
  for (int i = 0; i < 4; ++i) ts.emplace_back([&] { for (int j = 0; j < 1000; ++j) { std::lock_guard<std::mutex> g(mu); ++counter; } });
  for (auto &t : ts) t.join();
  std::cout << "counter " << counter << std::endl;
  auto p = std::make_shared<std::string>("shared");
  std::cout << *p << " " << p.use_count() << std::endl;
  return counter == 4000 ? 0 : 1;
}
