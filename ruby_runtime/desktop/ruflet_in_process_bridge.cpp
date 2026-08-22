#include "ruflet_in_process_bridge.h"

#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <mutex>
#include <utility>
#include <vector>

namespace {

using Message = std::vector<uint8_t>;

std::mutex g_bridge_mutex;
std::condition_variable g_bridge_changed;
std::deque<Message> g_to_ruby;
std::deque<Message> g_to_renderer;
bool g_bridge_closed = true;

int enqueue(std::deque<Message> &queue, const uint8_t *bytes, size_t length) {
  if (bytes == nullptr && length > 0)
    return RUFLET_BRIDGE_ERROR;

  {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);
    if (g_bridge_closed)
      return RUFLET_BRIDGE_CLOSED;
    Message message;
    if (length > 0)
      message.assign(bytes, bytes + length);
    queue.emplace_back(std::move(message));
  }
  g_bridge_changed.notify_all();
  return RUFLET_BRIDGE_MESSAGE;
}

int dequeue(std::deque<Message> &queue, uint8_t **bytes, size_t *length,
            bool wait_for_message) {
  if (bytes == nullptr || length == nullptr)
    return RUFLET_BRIDGE_ERROR;

  *bytes = nullptr;
  *length = 0;

  Message message;
  {
    std::unique_lock<std::mutex> lock(g_bridge_mutex);
    if (wait_for_message) {
      g_bridge_changed.wait(
          lock, [&queue] { return g_bridge_closed || !queue.empty(); });
    } else if (queue.empty() && !g_bridge_closed) {
      return RUFLET_BRIDGE_EMPTY;
    }
    if (queue.empty())
      return RUFLET_BRIDGE_CLOSED;
    message = std::move(queue.front());
    queue.pop_front();
  }

  const size_t allocation_size = message.empty() ? 1 : message.size();
  auto *copy = static_cast<uint8_t *>(std::malloc(allocation_size));
  if (copy == nullptr)
    return RUFLET_BRIDGE_ERROR;
  if (!message.empty())
    std::memcpy(copy, message.data(), message.size());

  *bytes = copy;
  *length = message.size();
  return RUFLET_BRIDGE_MESSAGE;
}

} // namespace

void ruflet_bridge_reset(void) {
  {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);
    g_to_ruby.clear();
    g_to_renderer.clear();
    g_bridge_closed = false;
  }
  g_bridge_changed.notify_all();
}

void ruflet_bridge_close(void) {
  {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);
    g_bridge_closed = true;
  }
  g_bridge_changed.notify_all();
}

int ruflet_bridge_is_open(void) {
  std::lock_guard<std::mutex> lock(g_bridge_mutex);
  return g_bridge_closed ? 0 : 1;
}

int ruflet_bridge_send_to_ruby(const uint8_t *bytes, size_t length) {
  return enqueue(g_to_ruby, bytes, length);
}

int ruflet_bridge_receive_for_ruby(uint8_t **bytes, size_t *length) {
  return dequeue(g_to_ruby, bytes, length, true);
}

int ruflet_bridge_try_receive_for_ruby(uint8_t **bytes, size_t *length) {
  return dequeue(g_to_ruby, bytes, length, false);
}

int ruflet_bridge_send_to_renderer(const uint8_t *bytes, size_t length) {
  return enqueue(g_to_renderer, bytes, length);
}

int ruflet_bridge_receive_for_renderer(uint8_t **bytes, size_t *length) {
  return dequeue(g_to_renderer, bytes, length, true);
}

void ruflet_bridge_free_message(uint8_t *bytes) { std::free(bytes); }
