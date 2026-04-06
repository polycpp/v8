// Minimal stub implementations for V8 Inspector non-virtual factory methods.
// This allows d8 to link without building the full inspector protocol.

#include "include/v8-inspector.h"
#include "include/v8-version.h"

namespace v8_inspector {

// StringBuffer::create - used by d8 and tests
std::unique_ptr<StringBuffer> StringBuffer::create(StringView view) {
  // Minimal implementation: empty buffer
  class StubStringBuffer : public StringBuffer {
   public:
    explicit StubStringBuffer(StringView view) : view_(view) {}
    StringView string() const override { return view_; }
   private:
    StringView view_;
  };
  return std::make_unique<StubStringBuffer>(view);
}

// V8DebuggerId methods
V8DebuggerId::V8DebuggerId(std::pair<int64_t, int64_t> pair)
    : m_first(pair.first), m_second(pair.second) {}

std::unique_ptr<StringBuffer> V8DebuggerId::toString() const {
  return StringBuffer::create(StringView());
}

bool V8DebuggerId::isValid() const {
  return m_first || m_second;
}

std::pair<int64_t, int64_t> V8DebuggerId::pair() const {
  return {m_first, m_second};
}

// V8StackTraceId methods
V8StackTraceId::V8StackTraceId() : id(0), debugger_id({0, 0}) {}

V8StackTraceId::V8StackTraceId(
    uintptr_t id, const std::pair<int64_t, int64_t> debugger_id)
    : id(id), debugger_id(debugger_id) {}

V8StackTraceId::V8StackTraceId(
    uintptr_t id, const std::pair<int64_t, int64_t> debugger_id,
    bool should_pause)
    : id(id), debugger_id(debugger_id), should_pause(should_pause) {}

V8StackTraceId::V8StackTraceId(StringView) : id(0), debugger_id({0, 0}) {}

bool V8StackTraceId::IsInvalid() const { return !id; }

std::unique_ptr<StringBuffer> V8StackTraceId::ToString() {
  return StringBuffer::create(StringView());
}

// V8Inspector::create - returns a stub inspector that does nothing
class StubV8Inspector : public V8Inspector {
 public:
  StubV8Inspector() = default;
  void contextCreated(const V8ContextInfo&) override {}
  void contextDestroyed(v8::Local<v8::Context>) override {}
  void resetContextGroup(int) override {}
  v8::MaybeLocal<v8::Context> contextById(int) override {
    return v8::MaybeLocal<v8::Context>();
  }
  V8DebuggerId uniqueDebuggerId(int) override { return V8DebuggerId(); }
#if V8_MAJOR_VERSION >= 13
  uint64_t isolateId() override { return 0; }
#endif
  void idleStarted() override {}
  void idleFinished() override {}
  void asyncTaskScheduled(StringView, void*, bool) override {}
  void asyncTaskCanceled(void*) override {}
  void asyncTaskStarted(void*) override {}
  void asyncTaskFinished(void*) override {}
  void allAsyncTasksCanceled() override {}
  V8StackTraceId storeCurrentStackTrace(StringView) override {
    return V8StackTraceId();
  }
  void externalAsyncTaskStarted(const V8StackTraceId&) override {}
  void externalAsyncTaskFinished(const V8StackTraceId&) override {}
  unsigned exceptionThrown(v8::Local<v8::Context>, StringView,
                           v8::Local<v8::Value>, StringView, StringView,
                           unsigned, unsigned, std::unique_ptr<V8StackTrace>,
                           int) override {
    return 0;
  }
  void exceptionRevoked(v8::Local<v8::Context>, unsigned, StringView) override {}
  bool associateExceptionData(v8::Local<v8::Context>, v8::Local<v8::Value>,
                              v8::Local<v8::Name>,
                              v8::Local<v8::Value>) override {
    return false;
  }
  std::unique_ptr<V8InspectorSession> connect(int, Channel*, StringView,
                                              ClientTrustLevel,
                                              SessionPauseState) override {
    return nullptr;
  }
#if V8_MAJOR_VERSION >= 14
  std::shared_ptr<V8InspectorSession> connectShared(int, Channel*, StringView,
                                                    ClientTrustLevel,
                                                    SessionPauseState) override {
    return nullptr;
  }
#endif
  std::unique_ptr<V8StackTrace> createStackTrace(
      v8::Local<v8::StackTrace>) override {
    return nullptr;
  }
  std::unique_ptr<V8StackTrace> captureStackTrace(bool) override {
    return nullptr;
  }
};

std::unique_ptr<V8Inspector> V8Inspector::create(v8::Isolate*,
                                                  V8InspectorClient*) {
  return std::make_unique<StubV8Inspector>();
}

}  // namespace v8_inspector
