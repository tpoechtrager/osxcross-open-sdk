// new libc++ features; select one with -DT_<name>
#include <cstdio>
#include <string>
#include <vector>
#include <version>
#if defined(T_format)
#include <format>
#elif defined(T_print)
#include <print>
#elif defined(T_expected)
#include <expected>
#elif defined(T_rangesto)
#include <ranges>
#include <algorithm>
#elif defined(T_jthread)
#include <thread>
#include <stop_token>
#elif defined(T_tz)
#include <chrono>
#elif defined(T_flatmap)
#include <flat_map>
#elif defined(T_mdspan)
#include <mdspan>
#elif defined(T_syncstream)
#include <syncstream>
#include <iostream>
#elif defined(T_charconv)
#include <charconv>
#elif defined(T_latch)
#include <latch>
#include <barrier>
#include <semaphore>
#include <thread>
#elif defined(T_atomicwait)
#include <atomic>
#include <thread>
#elif defined(T_pmr)
#include <memory_resource>
#elif defined(T_hash)
#include <functional>
#include <unordered_map>
#endif

int main() {
#if defined(T_format)
  std::string s = std::format("{} {:>5} {:.2f}", 42, "ab", 3.14159);
  std::puts(s.c_str());
#elif defined(T_print)
  std::println("hello {} {}", 1, "two");
#elif defined(T_expected)
  std::expected<int, std::string> e = 5;
  std::expected<int, std::string> f = std::unexpected(std::string("err"));
  std::printf("%d %s\n", e.value(), f.error().c_str());
#elif defined(T_rangesto)
  auto v = std::views::iota(1, 6) | std::views::transform([](int x) { return x * x; }) | std::ranges::to<std::vector>();
  for (int x : v) std::printf("%d ", x);
  std::puts("");
#elif defined(T_jthread)
  int n = 0;
  { std::jthread t([&](std::stop_token st) { while (!st.stop_requested()) { ++n; if (n > 3) break; } }); }
  std::printf("jthread %d\n", n);
#elif defined(T_tz)
  using namespace std::chrono;
  auto z = locate_zone("Europe/Berlin");
  zoned_time zt{z, sys_days{2024y/January/15} + 12h};
  std::printf("tz %s\n", z->name().data());
  std::printf("%d\n", (int)zt.get_local_time().time_since_epoch().count());
#elif defined(T_flatmap)
  std::flat_map<int, int> m{{1, 2}, {3, 4}};
  std::printf("flat_map %zu\n", m.size());
#elif defined(T_mdspan)
  int a[6] = {1, 2, 3, 4, 5, 6};
  std::mdspan<int, std::extents<int, 2, 3>> m(a);
  std::printf("mdspan %d\n", m[1, 2]);
#elif defined(T_syncstream)
  std::osyncstream(std::cout) << "syncstream\n";
#elif defined(T_charconv)
  double d = 0; const char* s = "3.25";
  auto r = std::from_chars(s, s + 4, d);
  std::printf("from_chars double %g %d\n", d, r.ec == std::errc());
#elif defined(T_latch)
  std::latch l(1); std::thread t([&] { l.count_down(); }); l.wait(); t.join();
  std::counting_semaphore<4> sem(1); sem.acquire(); sem.release();
  std::puts("latch ok");
#elif defined(T_atomicwait)
  std::atomic<int> a{0}; std::thread t([&] { a.store(1); a.notify_all(); }); a.wait(0); t.join();
  std::puts("atomic wait ok");
#elif defined(T_pmr)
  std::pmr::monotonic_buffer_resource mr; std::pmr::vector<int> v(&mr); v.push_back(1);
  std::puts("pmr ok");
#elif defined(T_hash)
  std::unordered_map<std::string, int> m{{"a", 1}}; std::printf("hash %zu\n", m.size());
#endif
  return 0;
}
