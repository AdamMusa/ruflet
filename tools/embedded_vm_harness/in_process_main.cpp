#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <future>
#include <iostream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "../../ruby_runtime/desktop/ruflet_vm_host.h"

namespace {

std::string runtime_error() {
  const size_t required = ruflet_vm_copy_error(nullptr, 0);
  if (required <= 1)
    return {};
  std::vector<char> buffer(required);
  ruflet_vm_copy_error(buffer.data(), buffer.size());
  return std::string(buffer.data());
}

bool contains(const std::vector<uint8_t> &message, const std::string &needle) {
  return std::search(message.begin(), message.end(), needle.begin(),
                     needle.end()) != message.end();
}

} // namespace

int main(int argc, char **argv) {
  if (argc != 2) {
    std::cerr << "usage: " << argv[0] << " PROJECT_ROOT\n";
    return 2;
  }

  const std::string root = argv[1];
  const std::string entrypoint = root + "/main.rb";
  const char *load_paths[] = {root.c_str()};
  const char *environment_keys[] = {
      "RUFLET_RUNTIME_TRANSPORT", "RUFLET_PROTOCOL_TRACE",
      "RUFLET_SUPPRESS_SERVER_BANNER"};
  const char *environment_values[] = {"in_process", "0", "1"};
  const std::string stop_path = root + "/.runtime-test.stop";
  const std::string error_path = root + "/.runtime-test.error";

  const int start_status = ruflet_vm_start(
      root.c_str(), entrypoint.c_str(), load_paths, 1, environment_keys,
      environment_values, 3, stop_path.c_str(), error_path.c_str());
  if (start_status != 0) {
    std::cerr << "embedded VM rejected the test app\n";
    return 1;
  }

  // MessagePack for [register_client, {}]. The real server codec handles the
  // message after these bytes cross the same bridge used by Flutter/Swift.
  const uint8_t registration[] = {0x92, 0x01, 0x80};
  if (ruflet_bridge_send_to_ruby(registration, sizeof(registration)) !=
      RUFLET_BRIDGE_MESSAGE) {
    std::cerr << "could not send registration through the bridge\n";
    ruflet_vm_stop();
    return 1;
  }

  uint8_t *response_bytes = nullptr;
  size_t response_length = 0;
  const int receive_status = ruflet_bridge_receive_for_renderer(
      &response_bytes, &response_length);
  std::vector<uint8_t> response;
  if (receive_status == RUFLET_BRIDGE_MESSAGE) {
    response.assign(response_bytes, response_bytes + response_length);
    ruflet_bridge_free_message(response_bytes);
  }

  if (receive_status != RUFLET_BRIDGE_MESSAGE || response.size() < 2 ||
      response[0] != 0x92 || response[1] != 0x01) {
    ruflet_vm_stop();
    std::cerr << "Ruby did not return a register-client MessagePack frame\n";
    return 1;
  }
  if (!contains(response, "in-process bridge ready")) {
    ruflet_vm_stop();
    std::cerr << "Ruby's rendered control tree was missing from the response\n";
    return 1;
  }

  auto background_update = std::async(std::launch::async, [] {
    uint8_t *bytes = nullptr;
    size_t length = 0;
    const int status =
        ruflet_bridge_receive_for_renderer(&bytes, &length);
    std::vector<uint8_t> message;
    if (status == RUFLET_BRIDGE_MESSAGE) {
      message.assign(bytes, bytes + length);
      ruflet_bridge_free_message(bytes);
    }
    return std::make_pair(status, std::move(message));
  });
  if (background_update.wait_for(std::chrono::seconds(2)) !=
      std::future_status::ready) {
    ruflet_bridge_close();
    background_update.wait();
    std::cerr << "Ruby background tasks stopped while the bridge was idle\n";
    return 1;
  }
  auto update_result = background_update.get();
  if (update_result.first != RUFLET_BRIDGE_MESSAGE ||
      !contains(update_result.second, "in-process background task advanced")) {
    ruflet_vm_stop();
    std::cerr << "Ruby background update did not cross the bridge\n";
    return 1;
  }

  ruflet_vm_stop();
  const auto deadline = std::chrono::steady_clock::now() +
                        std::chrono::seconds(5);
  while (ruflet_vm_is_running() && std::chrono::steady_clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(10));

  const std::string error = runtime_error();
  if (!error.empty()) {
    std::cerr << error << "\n";
    return 1;
  }
  if (ruflet_vm_is_running()) {
    std::cerr << "embedded VM did not stop after closing the bridge\n";
    return 1;
  }

  std::cout << "packaged VM exchanged a rendered page in process\n";
  return 0;
}
