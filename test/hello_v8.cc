// Minimal V8 embedding test
#include "include/v8.h"
#include "include/libplatform/libplatform.h"

#include <cstdio>

int main(int argc, char* argv[]) {
  // Initialize V8
  v8::V8::InitializeICUDefaultLocation(argv[0]);
  v8::V8::InitializeExternalStartupData(argv[0]);
  std::unique_ptr<v8::Platform> platform = v8::platform::NewDefaultPlatform();
  v8::V8::InitializePlatform(platform.get());
  v8::V8::Initialize();

  // Create isolate
  v8::Isolate::CreateParams create_params;
  create_params.array_buffer_allocator =
      v8::ArrayBuffer::Allocator::NewDefaultAllocator();
  v8::Isolate* isolate = v8::Isolate::New(create_params);

  {
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Local<v8::Context> context = v8::Context::New(isolate);
    v8::Context::Scope context_scope(context);

    // Run "1 + 2"
    v8::Local<v8::String> source =
        v8::String::NewFromUtf8Literal(isolate, "1 + 2");
    v8::Local<v8::Script> script =
        v8::Script::Compile(context, source).ToLocalChecked();
    v8::Local<v8::Value> result = script->Run(context).ToLocalChecked();

    v8::String::Utf8Value utf8(isolate, result);
    printf("V8 result: %s\n", *utf8);

    // Run something more complex
    v8::Local<v8::String> source2 = v8::String::NewFromUtf8Literal(
        isolate,
        "'Hello from V8 ' + typeof Array.prototype.at");
    v8::Local<v8::Script> script2 =
        v8::Script::Compile(context, source2).ToLocalChecked();
    v8::Local<v8::Value> result2 = script2->Run(context).ToLocalChecked();

    v8::String::Utf8Value utf8_2(isolate, result2);
    printf("%s\n", *utf8_2);

    // Test more JS features
    const char* tests[] = {
        "JSON.stringify({a: 1, b: [2, 3]})",
        "[1,2,3].map(x => x * x).join(', ')",
        "new Map([[1,'one'],[2,'two']]).get(2)",
        "(() => { let s = 0; for (let i = 1; i <= 100; i++) s += i; return s; })()",
        "typeof WebAssembly",
        // ICU / Intl tests
        "typeof Intl",
        "new Intl.NumberFormat('en-US').format(1234567.89)",
        "new Intl.DateTimeFormat('en-US').format(new Date(2025,0,1))",
        "new Intl.Collator('de').compare('ä', 'z') < 0 ? 'correct' : 'wrong'",
        "'café'.normalize('NFD').length",
    };
    for (const char* code : tests) {
      v8::Local<v8::String> src =
          v8::String::NewFromUtf8(isolate, code).ToLocalChecked();
      v8::Local<v8::Script> s =
          v8::Script::Compile(context, src).ToLocalChecked();
      v8::Local<v8::Value> r = s->Run(context).ToLocalChecked();
      v8::String::Utf8Value u(isolate, r);
      printf("  %s => %s\n", code, *u);
    }
  }

  // Cleanup
  isolate->Dispose();
  v8::V8::Dispose();
  v8::V8::DisposePlatform();
  delete create_params.array_buffer_allocator;

  printf("V8 MSVC build test PASSED\n");
  return 0;
}
