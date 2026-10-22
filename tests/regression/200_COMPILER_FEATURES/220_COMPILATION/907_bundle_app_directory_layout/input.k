import std/build
import std/io

std/build:app { name: "Regtest App", id: "org.koru.regtest.bundle", version: "0.2" }

std/io:print.ln("bundled input")
