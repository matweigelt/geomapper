# geoMap v2 tests

## Run

    >> cd <toolbox root>
    >> addpath(pwd, fullfile(pwd,'tests'), fullfile(pwd,'tools'))
    >> makeManifest                     % once, after any file change
    >> ok = rungeoMapTests("all")       % all tiers

`rungeoMapTests` is **the** runner. Never call
`runtests('tests')` directly: a runner that reports what it did is the
instrument, and the directory-discovery entry point reports only a count.

## Selectors

| Call | Runs |
|---|---|
| `rungeoMapTests()` | contract, reference, precision, robustness, vectorisation, metamorphic |
| `rungeoMapTests("all")` | the above plus speed |
| `rungeoMapTests("speed")` | speed only |
| `rungeoMapTests("TestB1")` | name-substring filter |

`setenv('GEOMAP_SKIP_SPEED','1')` filters the speed tier as *incomplete*
rather than silently dropping it.

## Green gate

Zero failures **and** every suite loaded **and** no new warning identifier
**and** no speed budget exceeded **and** the manifest verified **and** the
category coverage clean. Not "the number went up".

## Before every run

Predict the point count. A suite that silently fails to load is
indistinguishable from a green run by the pass count alone. The runner
prints three reconciliations to compare against your prediction. **Do not
write the number into any document** — it goes stale the way a maintained
suite list does.
