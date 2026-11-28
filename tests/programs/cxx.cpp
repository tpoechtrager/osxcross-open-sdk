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
#include <unistd.h>
#include <regex>
#if __cplusplus >= 201703L
#include <filesystem>
#include <fstream>
#endif

static thread_local int tls = 1;

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
  int tls_other = 0;
  std::thread([&] { tls += 10; tls_other = tls; }).join();
  if (tls != 1 || tls_other != 11) return 2;
  std::smatch sm;
  std::string line = "key=value42";
  if (!std::regex_match(line, sm, std::regex("(\\w+)=(\\w+?)(\\d+)")) || sm[3] != "42") return 3;
#if __cplusplus >= 201703L
  namespace fs = std::filesystem;
  fs::path d = fs::temp_directory_path() / ("cxxfs." + std::to_string(::getpid()));
  fs::create_directories(d / "sub");
  std::ofstream(d / "sub" / "f.txt") << "hello";
  size_t files = 0;
  for (auto &e : fs::recursive_directory_iterator(d)) files += e.is_regular_file();
  if (files != 1 || fs::file_size(d / "sub" / "f.txt") != 5) return 4;
  fs::remove_all(d);
  if (fs::exists(d)) return 5;
  std::cout << "filesystem ok" << std::endl;
#endif
  return counter == 4000 ? 0 : 1;
}
