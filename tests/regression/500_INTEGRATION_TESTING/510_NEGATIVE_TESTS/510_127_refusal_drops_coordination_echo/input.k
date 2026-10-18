// Pin (emission layering): a refusal whose pipeline delivered a real,
// located diagnostic must not be followed by the coordination layer's
// vaguer echo of the same failure, nor by the post-failure summary
// re-printing it a third time. One refusal, one message.
//
// The `❌ Compiler coordination error` line is NOT gone — it stays for
// failures that never produced a diagnostic (user-authored coordinator
// overrides, pinned by the 430 cluster; diagnostic-free internal errors).
x = 42
