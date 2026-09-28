import std/testing
import std/io

pub tor checks {}
checks = assert.eq(expected: 3, actual: 3)
|> assert.contains(haystack: "hello world", needle: "wor")
|> std/io:print.ln("mod asserts passed")
