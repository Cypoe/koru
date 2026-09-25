// Test: Parser should handle void tor chaining
// Void tors (no output branches) should support continuation syntax
// void-event() |> next_event() should create a continuation

tor void-event {}

tor another-void {}

// This should parse as a flow with ONE continuation
// Initial invocation: void-event()
// Continuation: |> another-void() (no branch specifier needed)
void-event() |> another-void()
