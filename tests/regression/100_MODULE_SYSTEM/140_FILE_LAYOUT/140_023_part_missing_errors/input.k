// PIN (part): a `part` that names no file is an error, never a silent skip.
// The house law is fail loud: `part missing` must refuse with a located
// diagnostic naming the tag and the files that were probed — the absent
// file is a broken module, not an optional facet.

part missing
