// PIN (part): a top-level declaration repeated across the primary/part
// boundary must be diagnosed. The stem-facet merge could rely on silent
// dedup (type_registry.registerEvent early-returns) because facets are
// different host views; parts are the SAME kind of file, so a duplicate is
// an accident and must name the part that redeclares it — never vanish.

part a

pub tor greet {}
