import std/compiler

// Pure-Koru .k file: no ~ prefix (it is the host->Koru switch and is
// meaningless here). The qualified spelling makes this an impl of
// std/compiler:coordinate from module app.override — a cross-module override.
std/compiler:coordinate => error "FAILURE"
