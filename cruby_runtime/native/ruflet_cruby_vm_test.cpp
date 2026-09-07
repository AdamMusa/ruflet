#include "ruflet_vm_host.h"

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>

int main(int argc, char **argv) {
  if (argc != 2) {
    std::cerr << "usage: ruflet_cruby_vm_test PROJECT_ROOT\n";
    return 64;
  }
  const std::string root = argv[1];
  const std::string entrypoint = root + "/main.rb";
  const char *load_paths[] = {root.c_str()};
  const char *keys[] = {"RUFLET_RUNTIME_TRANSPORT",
                        "RUFLET_SUPPRESS_SERVER_BANNER"};
  const char *values[] = {"in_process", "1"};
  if (ruflet_vm_start(root.c_str(), entrypoint.c_str(), load_paths, 1, keys,
                      values, 2, "/tmp/ruflet-cruby.stop",
                      "/tmp/ruflet-cruby.error") != 0)
    return 65;

  for (int attempt = 0; attempt < 500 && ruflet_vm_is_running(); ++attempt) {
    const std::string error = [] {
      const size_t size = ruflet_vm_copy_error(nullptr, 0);
      std::string value(size == 0 ? 0 : size - 1, '\0');
      if (size > 1)
        ruflet_vm_copy_error(value.data(), size);
      return value;
    }();
    if (!error.empty()) {
      std::cerr << error << '\n';
      return 1;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  if (!ruflet_vm_is_running()) {
    const size_t size = ruflet_vm_copy_error(nullptr, 0);
    std::string error(size == 0 ? 0 : size - 1, '\0');
    if (size > 1)
      ruflet_vm_copy_error(error.data(), size);
    std::cerr << (error.empty() ? "CRuby app exited before the bridge connected"
                                : error)
              << '\n';
    return 1;
  }
  std::cout << "CRuby runtime started and is waiting on the in-process bridge\n";
  ruflet_vm_stop();
  for (int attempt = 0; attempt < 500 && ruflet_vm_is_running(); ++attempt)
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  return ruflet_vm_is_running() ? 1 : 0;
}
