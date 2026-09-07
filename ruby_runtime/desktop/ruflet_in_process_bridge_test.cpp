#include "ruflet_in_process_bridge.h"

#include <cassert>
#include <chrono>
#include <cstring>
#include <future>
#include <string>

namespace {

std::string receive_for_ruby() {
  uint8_t *bytes = nullptr;
  size_t length = 0;
  assert(ruflet_bridge_receive_for_ruby(&bytes, &length) ==
         RUFLET_BRIDGE_MESSAGE);
  std::string message(reinterpret_cast<char *>(bytes), length);
  ruflet_bridge_free_message(bytes);
  return message;
}

std::string receive_for_renderer() {
  uint8_t *bytes = nullptr;
  size_t length = 0;
  assert(ruflet_bridge_receive_for_renderer(&bytes, &length) ==
         RUFLET_BRIDGE_MESSAGE);
  std::string message(reinterpret_cast<char *>(bytes), length);
  ruflet_bridge_free_message(bytes);
  return message;
}

} // namespace

int main() {
  ruflet_bridge_reset();
  assert(ruflet_bridge_is_open() == 1);

  uint8_t *empty_bytes = nullptr;
  size_t empty_length = 0;
  assert(ruflet_bridge_try_receive_for_ruby(&empty_bytes, &empty_length) ==
         RUFLET_BRIDGE_EMPTY);
  assert(empty_bytes == nullptr);
  assert(empty_length == 0);

  auto waiting_ruby = std::async(std::launch::async, receive_for_ruby);
  assert(waiting_ruby.wait_for(std::chrono::milliseconds(10)) ==
         std::future_status::timeout);
  const std::string renderer_message = "renderer-to-ruby";
  assert(ruflet_bridge_send_to_ruby(
             reinterpret_cast<const uint8_t *>(renderer_message.data()),
             renderer_message.size()) == RUFLET_BRIDGE_MESSAGE);
  assert(waiting_ruby.get() == renderer_message);

  const std::string immediate_message = "nonblocking-renderer-to-ruby";
  assert(ruflet_bridge_send_to_ruby(
             reinterpret_cast<const uint8_t *>(immediate_message.data()),
             immediate_message.size()) == RUFLET_BRIDGE_MESSAGE);
  uint8_t *immediate_bytes = nullptr;
  size_t immediate_length = 0;
  assert(ruflet_bridge_try_receive_for_ruby(
             &immediate_bytes, &immediate_length) == RUFLET_BRIDGE_MESSAGE);
  assert(std::string(reinterpret_cast<char *>(immediate_bytes),
                     immediate_length) == immediate_message);
  ruflet_bridge_free_message(immediate_bytes);

  const std::string first = "first";
  const std::string second = "second";
  assert(ruflet_bridge_send_to_renderer(
             reinterpret_cast<const uint8_t *>(first.data()), first.size()) ==
         RUFLET_BRIDGE_MESSAGE);
  assert(ruflet_bridge_send_to_renderer(
             reinterpret_cast<const uint8_t *>(second.data()), second.size()) ==
         RUFLET_BRIDGE_MESSAGE);
  assert(receive_for_renderer() == first);
  assert(receive_for_renderer() == second);

  auto waiting_renderer = std::async(std::launch::async, [] {
    uint8_t *bytes = nullptr;
    size_t length = 0;
    return ruflet_bridge_receive_for_renderer(&bytes, &length);
  });
  assert(waiting_renderer.wait_for(std::chrono::milliseconds(10)) ==
         std::future_status::timeout);
  ruflet_bridge_close();
  assert(waiting_renderer.get() == RUFLET_BRIDGE_CLOSED);
  assert(ruflet_bridge_is_open() == 0);
  assert(ruflet_bridge_send_to_ruby(nullptr, 0) == RUFLET_BRIDGE_CLOSED);

  return 0;
}
