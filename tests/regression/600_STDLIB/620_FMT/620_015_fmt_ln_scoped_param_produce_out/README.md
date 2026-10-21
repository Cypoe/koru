# 620_015 — fmt:ln scoped param produce-out (negative half)

The mirror of 620_014: the param declares `string<*@scoped>`, so `data`
binds scoped inside the callee — but the declared output is plain
`-> string`. A scoped binding may not occupy a produce position unless
the declared output preserves the class, so `-> data` refuses inside
`launder` with `may not be produced out`.

This is the last launder: acceptance without a classed output buys the
callee in-place use only. To hand the borrow onward, the output contract
must spell `string<*@scoped>` — as `passthru` does in 620_014.
