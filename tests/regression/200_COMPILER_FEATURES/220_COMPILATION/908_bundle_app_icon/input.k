import std/build
import std/io

std/build:app { name: "Icon App", id: "org.koru.regtest.icon", version: "0.1", icon: "appicon.icns" }

std/io:print.ln("bundled icon input")
