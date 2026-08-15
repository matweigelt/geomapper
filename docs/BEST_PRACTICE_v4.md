# Best practice for model-assisted scientific software

**What this is.** A merged distillation of three completed projects — one numerical/geodetic
library built over roughly 180 revisions of a handover document, one adjustment toolbox
built over 38 work packages and 43 test suites to a frozen release, and one
spherical-harmonic analysis toolbox taken through fifty-odd pull requests to its first
fully unfiltered green acceptance run on real 24-year data — each developed by a
domain expert working with a language model. All three projects recorded their defects with
measurements. The third contributed something the first two could not: a phase in which a
live interpreter on the production machine, with the production data, re-measured every
number the documents claimed. This file keeps the rules and the numbers that bought them, and drops
everything specific to either subject.

**How to read it.** Almost every rule is followed by the defect that produced it. The
defects are the point. A rule without its evidence becomes a style preference and gets
argued with; a rule with a number attached to it does not. Rules marked **(proposed)**
carry no defect record yet — they are inferences from the two histories, and they should
be treated as weaker than the rest until something has been paid for them.

**Scope.** Numerical and scientific software where correctness is not self-evident from
the output: a wrong answer is smooth, plausible, and the right shape.

**Contents**

1. The five failure modes
2. The workflow — two tiers, one loop
3. Validation — theory, implementation, code
4. Rules for the code
5. Rules for the tests
6. Rules for the process and the documents (6.10: the CI/repository loop)
7. Prompting
8. The one-page checklist
9. Appendix A — the pasteable standing preamble
10. Appendix B — what carries evidence and what does not

---

## Part 1 — The five failure modes

Nearly every defect in both projects falls into five classes. They recur because each one
is invisible to the check that would normally catch it.

### F1. The plausible wrong answer

A wrong rotation sense still produces an orthogonal, unit-determinant matrix that
round-trips through its own inverse. Offsets referred to the wrong precession-nutation model
produce a transformation that is smooth, continuous and **wrong by 4.2 mm**. A column-major
flatten of a character matrix produces **43 077 "lines" that are each one character long**,
and every downstream pattern simply fails to match — silently.

> **No self-consistency check can catch a consistently wrong program.** Validate against
> something that was not built here: a published worked example, a second toolkit, real
> instrument data, an analytic limit, a physical invariant the code does not use.

*And a self-consistency check can be inert without anyone noticing:* one pairing check was dead
from the day it was written until four runs later, and a dead check looks exactly like a passing
one.

*Two further faces of the same mode.* A reference run reproduced from memory instead of from
the frozen acceptance script — the ocean mask paraphrased as a plain latitude band, dropping the
continent exclusions — **halved a validated trend (+0.71 vs +1.41) and collapsed the annual
amplitude (2.5 vs ~9 mm)**, and an hour went into hunting a code regression that did not exist.
The acceptance call is code: re-run the frozen script, never a recollection of it. And a
documentation pipeline **parsed input descriptions into its data model for years while the
renderer never read the field** — every claim of coverage must be counted in the *built
artefact* (there: 881 arguments walked in the output model, 4 found missing), not at the parser
that feeds it.

### F2. The claim recalled instead of read

At one point in the first project, seven of ten consecutive failures were a name or a
value recalled rather than read from source: a gateway signature that took fourteen
arguments and not three; a function that did not exist; an accepted enumeration value that
was not one of the four; a document chapter that contains nothing on the subject.

> **Anything not exercised by a currently-green test is a guess until the source is open.**
> This includes the standard library, your own API from three revisions ago, and documents
> you are certain of.

Operational form: **an argument-validation block without an explicit membership constraint
does not define the accepted values. Read the body.** Two of three invented signatures
were wrong; the third was right, which is worse than useless as evidence — guessing
correctly twice is what makes the third guess feel safe.

### F3. The instrument that lies

Ad-hoc scripts written in the same session as the change they check produced confidently
wrong answers repeatedly: a block-depth checker missing its increment; a slice that
swallowed a whole method; a tag pattern that omitted one category; a sizing probe whose
signature pattern made the assignment optional, so `function requireArity(op, got, want)`
parsed as a function named `y`. That last one reported 1709 findings, mostly its own parse,
and a scope decision was very nearly taken on the number.

> **No count, structure or coverage claim from an instrument written in the same session
> as the change it checks.** Either use one that has been shown to fail on a known defect,
> or mark the claim provisional in writing.

*Corollary:* an "independent" check copied from the code under test is not independent. A
reader copied out of the library **including its defect** agreed perfectly with it, so the
assertion passed while the number beside it was absurd.

*Corollary:* two gates can share one blind spot for **different** reasons. A migration script's
header pattern disallowed a dot, so it read the header of all 39 public functions as absent and
prepended a wrong one above each — and the existing header check could not catch that, because
the wrong header still matched the file name. One gate was blind because of its pattern, the
other because it read only the first line. **The second gate must read something the first does
not**, which is why its replacement reads the whole block.

*Corollary:* **an option's semantics are what its loop does, not what its name suggests.** A
download budget documented as a time limit was checked only *between* files, so it could not cut
the first transfer — proven by an accidental 460 MB pull in a call meant as a dry probe. The
plumbing-only cut existed all along under a different option (a max-files count of zero). The
repair was not code but honesty: document the negative space explicitly ("checked between
files — it never interrupts a running transfer and never blocks the first file") and switch
the acceptance to the option that actually cuts.

### F4. The preserving mechanism that destroys

Repeatedly, a mechanism whose purpose was to preserve information destroyed it:

| Where | What was lost |
|---|---|
| A downloader that raised after fetching | The manifest describing files already on disk |
| A formatter refusing a missing array element | An entire report of 577 test results |
| An exception anywhere before the report was written | Three revisions of runs, silently |
| A recursion guard added to stop a hang | Seven tests turned into silent no-ops |

Each was repaired **at the site where it was noticed**, and the same shape was left
standing one level up.

> **When a mechanism that preserves is found destroying, immediately ask where else the
> same producer/artefact relationship exists.** Fixing the instance is not fixing the class.

*And the sharper form:* **a guard is not a fix.** The recursion guard above was worse than
the hang it replaced, because it looked like progress. The repair was to remove the cycle.

*And the correcting mechanism that over-corrects.* An iterative boundary-leakage removal was
validated in a clean 1-D reference, where one sweep carried most of the effect and five were
"converged". On the real sphere the measured ladder ran **+1.557 / +1.524 / +1.321 for 0/1/5
sweeps — monotonically away from the published value**: at depth, the separation attributed
genuine boundary signal to the wrong domain. When an iterative correction's answer moves
monotonically with iteration depth, **depth is a physical claim, not a convergence knob**:
measure the ladder on the real target, freeze all its rungs in the record, and default to the
validated point (there: one sweep), documenting deeper settings as aggressive.

*And the fix that needs the same rigour as the defect.* A mode-selection rule that silently kept
zero modes (a real degeneracy it could not represent) was extended with the textbook group rule —
and the unguarded extension **kept ten modes**, walking gap by random gap into the noise, because
separation alone is not significance. The final form needed a second, independent criterion
(a noise-bulk edge) plus a conservative cap where the edge's own assumption (independent noise)
is known false in the field. Three states — 0, 10, 3 — and each transition was forced by a
measured failure, then frozen as exact scenario tests (noise-only keeps 0, a planted degenerate
pair keeps 2, a single mode keeps 1). **Validate the repair the way the defect was validated,
or the repair becomes the next defect.**

### F5. The layered defect

One item — validating a single code path against an external authority — was declared
closed three times and was not. The fixture was assumed to lack a body it had always
contained; then a name map had no entry, so the path would have stayed dead even with the
data present; then the helper opened one hard-coded filename, so a file already downloaded
was invisible; then a safety refusal excluded it from the set.

**Each cause was visible only after the previous one was removed.**

> **Do not write "closed" until the path has run end to end and produced a number.** A
> repair that removes one of several blockers looks exactly like a repair that removes the
> last one.

### What a live machine adds — the sixth source of findings

The third project's first session with a live interpreter on the production machine produced
**four findings in one day that a green CI, six static gates and a complete fixture suite had
all missed**, and every one belongs to a class no offline check can reach:

| Finding | Why nothing offline could see it |
|---|---|
| A wrong function name in a batch script | The script had never been executed anywhere |
| A budget option that cannot cut the first transfer | Its loop semantics only show against a real 460 MB file |
| An acceptance expectation outdated by the data | The strongest event in the record postdated the frozen expectation |
| A selection rule silently returning zero | The criterion degenerated only at the grown series length |

> **Fixture-green certifies nothing about scripts never executed and expectations never
> re-measured.** Schedule a live acceptance phase as its own tier of work, expect it to produce
> findings rather than confirmations, and budget the session for repairing them — the findings
> above each changed shipped code or shipped criteria the same day.

---

## Part 2 — The workflow

### 2.0 Declare the tier at the start of every session

Which tier you are in decides what counts as evidence, what ships, and what "done" means.
It is the first line of the session, not an assumption.

- **Tier A — a live language session is reachable from the authoring chat** (e.g. MATLAB
  over MCP). The in-session run is ground truth.
- **Tier B — no interpreter in the sandbox.** Development is mirrored in a second language
  (Python), pre-validated numerically there, and the *user's* run is ground truth.

Tier A was adopted in the second project midway through, and the reversal is instructive:
Tier B had been *chosen* deliberately eight days earlier, because earlier attempts at a
sandbox runner lost files in transfer and would have surfaced as phantom test failures. What
changed was not the risk appetite but the topology.

> **A live session is admissible as ground truth only when it runs over the very folder the
> deliverable is built from.** No transfer between authoring and running means the failure
> mode that made a sandbox runner untrustworthy cannot occur on that path. If the run is
> over a copy, you are in Tier B with extra steps.

### 2.1 Tier A — the in-session loop

1. **Write the code and its tests together.** Never ship code in one session and its tests
   in the next; the code is then never exercised.
2. **Static analysis first.** Run the language's own code checker over every changed file
   before running anything. It is the cheapest gate and it catches the class of defect —
   an unbalanced block, a shadowed builtin, an unreachable branch — that costs a whole
   round otherwise.
3. **Run the one runner.** Never the framework's directory-discovery entry point directly;
   a project runner that reports what it did is the instrument (see 2.3).
4. **Run long suites through a background/idle-time call with a status file.** A full suite
   can outlast a single tool call. The status file answers the question the log cannot: **a
   run that died leaves a stale result file that looks exactly like a run that succeeded.**
5. **Read the log, not the pass count.** Which files loaded; the warning inventory by
   identifier; per-suite seconds; incompletes and why.
6. **The deliverable still ships, and the user may still re-run it** — that run is now a
   confirmation rather than the gate.
7. **Keep the authoring harness inside the tree, and audit it like everything else.** Held
   outside, it belongs to nothing, and it rots: a project-wide rename could not see it, its
   hard-coded path broke silently, and it was found by reading rather than by any gate. It
   need not be on the search path or on any public surface — only inside the audited set.

### 2.2 Tier B — the mirror loop

1. **Pre-validate in the mirror language against exact or independent formulae.** Every
   number the target-language test will assert is measured here first.
2. **Validate structurally and statically** — block balance, naming, the project audit.
3. **Ship the entire tree as one artefact per round**, never a partial file set, with a
   **transfer manifest** listing every shipped path with a line count and a content hash.
   The runner verifies the tree against the manifest **before** running and reports missing,
   truncated or altered files in its own words. This converts a transfer loss from a
   mysterious test failure discovered rounds later into a legible message at the top of the
   log.
4. **The user's run is the gate.** The log comes back as an uploaded file; large pastes are
   lost in transit.

In Tier A the manifest is still generated — it now guards only the download, not the run.

### 2.3 The mirror survives the promotion to Tier A

The mirror is not a fallback. It is the **pre-validation instrument**, and its findings are
the highest-yield output of the whole workflow (Part 3.1). Under Tier A it keeps that job
and loses only its role as the last word.

Rules that keep a mirror honest:

- **One owner per kernel.** Before consolidation, four separate verification scripts had
  each re-derived the same three kernels — four chances to drift. **A drifted mirror makes
  the evidence quietly wrong rather than merely repetitive**, which is worse than no mirror,
  because the numbers still look like measurements.
- **Import from the mirror; never re-derive.** Add to it what your package mirrors, with the
  same documentation discipline as shipped code.
- **A change to shipped arithmetic or order of operations changes the mirror in the same
  round**, and a standing mirror test checks that it still reproduces the properties its
  originating work measured.
- **Where the two disagree, the target language is right by definition.**
- **Record what the mirror cannot see**, so it is not trusted too far. Documented examples:
  trailing singleton dimensions are dropped in one language and not the other, so a guard
  correct in the mirror made a legitimate model inexpressible in the target; a conditioning
  estimator in one language against an exact value in the other moved a refusal threshold
  by two decades; speed ratios transfer only when both sides scale alike between languages
  (§3.4).
- **Where a measurement can only be taken in the target language, say so and put the
  evidence where the measurement was taken** — in the help text of the budget it justifies,
  with the numbers, the bands, and the approaches that did not work. **Record the procedure for
  re-deriving it**, so the finding is reproducible from the shipped tree rather than from a
  scratch file on one machine. A missing verification script should read as a decision, not an
  oversight.
- **A scratch probe that duplicates a shipped fixture is not shipped, and not kept.** One
  carried its own copies of two fixtures — exactly the drift these rules exist to prevent — and
  broke within a day of being written. What was missing was the procedure, not the script.
- **A superseded verification script is left frozen as the record of its own round.** Rewriting
  a record is not the same as keeping it.

### 2.35 Three mechanics the live phase paid for

- **Jobs longer than the tool window run detached.** A five-to-six-minute acceptance run
  inside a four-minute call window: write a self-contained job script that saves its result
  to an artefact file, launch it as a detached process, poll for the artefact. The 368-second
  run completed while the session verified other items in parallel. Never stretch a single
  call toward a timeout — a timed-out call loses the work *and* the diagnosis.
- **A patch anchor that fails to match is a signal, not an annoyance.** Twice in one session
  the assert on an exact-match replacement saved a release: once it exposed that an earlier
  edit had been silently lost (its heredoc had crashed after the replace but before the
  write); once it exposed that the whole branch sat on a stale base. Patch scripts assert the
  old text, write only after all asserts pass, and re-grep the file afterwards — and when the
  anchor fails, the question is never "how do I make it match" but "what does its failure
  mean".
- **Rate-test before every long operation.** Measure the cost on a bounded slice, project
  to full size, and only then choose inline, detached, or "not today". One projected rate
  (0.14 s per iteration) turned a would-be seven-minute timeout into a bounded call; the
  timeout it avoided would have lost the work *and* the diagnosis, which is the real price.
- **Fetch before every branch.** A release branch created without a fresh fetch was based on
  a main several merges old; everything built and every gate passed, because gates check the
  tree, not the ancestry. The failing patch anchor above was the only symptom. The rule is
  mechanical: fetch, then branch from the remote ref, in one command, every time.

### 2.4 Batching — and a worked example of re-reading a decision

Under Tier B, a session may cover several work packages **provided they are mutually
independent in code** — no package depends on another in the batch, and their public
surfaces do not overlap. Each still ships its own test suite, so a red run points at exactly
one suite. Two or three independent leaves is the typical safe batch; batching across a
dependency edge turns a red run into a multi-package hunt and costs more rounds than it
saves.

**The reasoning was explicitly a cost model:** the slow part of the loop was never the
writing, it was that each red round cost one full human round-trip.

> **Tier A removes the cost that justified batching.** The decision must therefore be
> re-read, not inherited. **(proposed)** Under Tier A, prefer one package per confirming
> run: rounds are cheap, and a red run that points at one package is worth more than a
> saved round-trip that no longer exists.

This is the general shape of §6.4: **a decision must be re-read when the conditions it was
taken under change, and nothing prompts that automatically.**

---

## Part 3 — Validation

Three levels, and they fail differently. Most projects test only the third.

| Level | The question | Validated against | Instrument |
|---|---|---|---|
| **Theory** | Is the thing we are about to build the right thing? | The primary source: paper, standard, worked example, analytic limit | Pre-validation, before any implementation |
| **Implementation** | Does this realisation compute what the theory says? | An independent reference: dense/analytic form, second toolkit, second language | The mirror, the oracle register |
| **Code** | Does the software keep the promises its documentation makes? | Its own contract | Contract, robustness and metamorphic tests, static audit |

### 3.05 A criterion derived from data carries the data's span

Two acceptance criteria in the third project went stale by nothing more than the series
growing: the strongest drought in the record came to postdate the frozen expectation
(the new event measured **-3.05 against the remembered -1.4 class**), and a statistical
selection rule met a degeneracy the shorter series had not shown (leading eigenvalue gap
0.44e9 against a sampling uncertainty of 0.53e9 — and the rule returned zero, silently).
Neither was a defect when frozen; both were defects at re-measurement.

> **Write the temporal span next to every number derived from the data, and re-run the
> derivation when the span grows.** An expectation without its span is a claim about a
> dataset that no longer exists.

### 3.1 Validate the specification before implementing it

This is the highest-yield practice in either project's record, and it was a habit rather
than a rule.

Across seven consecutive work packages, **the majority of all findings were errors in the
brief, found before a line of production code existed.** A representative sample, each
found by a pre-validation script:

- The brief's estimator, read literally, was neither of the two intended estimators but a
  third fixed point. All three converge, so only algebra could separate them.
- A regularisation parameter does **not** go to zero on a well-posed problem; its fixed
  point is an inverse signal-to-noise ratio, and the brief's target value implied an SNR of
  1e5.
- The brief's first acceptance test — "on clean data all weights are 1 to 1e-12" — is false
  for any finite tuning constant. The estimator downweights 17.6% of clean rows by design;
  that *is* the efficiency loss.
- A stated invariance named a row scaling and described a column one. Both are real
  properties, and they guard different defects.
- A fixture designed to be rank deficient was not: duplicating a group's design left it
  well conditioned, because each group keeps its own noise.
- A validation fixture was rank deficient by accident — one column equalled the sum of four
  others — caught only because a redundancy sum refused to close against the degrees of
  freedom.

> **Run the specification against the mathematics before writing the code, and record what
> that stage finds as findings, with their measurements.** A brief is a claim about the
> world too (§4.3).

*And its counterpart:* **pre-validation verifies the campaign you actually build.** One
package pre-validated a fixture whose row count it had computed rather than measured; the
suite built a different one, and the assertion failed correctly for a reason the
pre-validation could not see.

### 3.15 The pre-validation model must share the failure surface

Two defects sailed through pre-validation because the model was cleaner than the target:
a prototype that projected **all** degrees could not, in principle, exhibit the leak that
put a degree-0 imbalance onto one coefficient (**153% error** in the implementation); and a
synthetic data fixture used a dimension order no real product file uses, so the reader was
"validated" against an arrangement that does not exist and failed on first contact with a
real file.

> **Mirror the target's failure surface, not only its mathematics**: same dimension
> orders, same truncations, same file-format quirks, same missing pieces. A pre-validation
> model that cannot express the bug cannot catch it.

### 3.2 The oracle register

> **If you cannot name what this will be checked against that was not built here, the
> prompt is not ready.** That question caught more design problems than any other.

Make it countable: keep one table listing every external authority in the project, what it
certifies, and which tests consume it. Gaps then show up as empty rows rather than as an
absence nobody notices. **(proposed)**

### 3.3 The test categories — every unit states which it ships

The two projects used overlapping taxonomies. Merged:

| Category | Asserts |
|---|---|
| **contract** | The promises in the help text: shapes and types of every output, argument rejection with the *documented* identifier and only that one, determinism where promised, order/batch invariance where promised, error messages that name the offending field |
| **reference** | Agreement with an outside authority — a published example, a second toolkit, real data |
| **precision** | The numerical claim, with an explicit tolerance and a comment saying where the tolerance comes from |
| **speed** | A *relative* budget against a recorded baseline operation on the same machine (§3.4) |
| **robustness** | Behaviour at and beyond the edge of validity: degeneracy, conditioning, boundary and empty inputs, non-finite propagation, reproducibility under worker count and arrival order (§3.5) |
| **vectorisation** | A batched call equals the same inputs one at a time — the single cheapest reference test in a vectorised language, and the one most often assumed |
| **metamorphic** | Invariance and equivariance through the public API: permutation, rescaling, split/merge, duplication, worker count — each stating whether the expectation is bitwise or eps-level, and why |

Add **diagnostics** and **provenance** as cross-cutting tags rather than categories: does every
measured number reach the report (§5.3), and does every result carry the metadata that says where it
came from (§4.2)?

**Count them mechanically, per unit.** An audit that asked this question for the first time
found 46 of 81 functions short of at least one category **after nine green runs**.

House tolerances that worked, as a starting point: exact-identity checks ≤ 1e-10 relative;
factorisation round-trips ≤ 1e-12; Monte-Carlo quantities within 4/√Z — noting that
4/√Z is a 2.93-sigma bar and **not** a containment guarantee.

**An exemption is a claim that the test is impossible, not that it is inconvenient.** Keep
the list, require a reason per entry, and have something object when an exemption becomes
false. Note what that does not catch: an exemption that was **wrong when written**. Two
entries reasoned from an expensive *success* to an impossible test — "calling it recompiles
255 sources", "every code path reaches the network" — and never asked what a **rejected**
call costs. Argument validation runs before the body, so both were refutable in
microseconds.

> Mechanical form: **`contract` may not be exempted for a function that validates its
> arguments.**

### 3.4 Speed — how to write a budget that means something

The most developed doctrine in either project, and the one most often got wrong. Nine rules,
each with the measurement that produced it.

1. **Assert a ratio; log the absolute.** An absolute figure with no baseline cannot detect
   the change it was written for — a benchmark added for a speed change measured only the
   state *after* the change and shipped a 1.30× regression. A sub-millisecond absolute
   timing measures the host: one such row swung 6.8× across three runs on a function nobody
   had touched.
2. **Median of ratios, never ratio of medians.** A budget that times its first point to
   completion and only then times its second has put the two points in **different windows**,
   and everything that drifts across a window — thermal throttling, allocator state, the
   scheduler, a page cache dozens of suites have just churned — lands entirely on the later
   one. **A median over repeats cannot remove it**: a median removes a slow repeat *inside*
   one window and is blind to a monotone drift *between* them; more repeats give the drift
   longer to run. Measured: a ratio read **8.298 inside the full runner against 4.81, 5.11,
   5.34, 5.43 and 5.54 for the same binary run alone, five times out of five**, on a budget
   of 8.
   The repair has three parts and all three are needed: **(i)** time every measurement point
   of one statistic inside one repeat, after an untimed warm-up call; **(ii)** **rotate** which
   point is timed first, because timing the same one first leaves a small, non-zero,
   always-identically-signed bias — prefer a repeat count that is a multiple of the number of
   points; **(iii)** form the statistic per repeat and take the median of *those*. Quote
   `min .. max` of the per-repeat distribution in the failure message: a spread is what tells the
   next reader whether a red budget is a regression or a machine having a bad minute.
   **One shared timing helper does the pairing, rotation and bookkeeping for the whole
   project.** Before consolidation there were eleven near-copies of a local median helper plus
   two bespoke pairing helpers — thirteen places, which is thirteen chances for the next repair
   to be applied twelve times.
   **A threshold does not move as part of this repair.** The instrument changes; if the
   honest instrument reads differently, that difference is a finding and is recorded with its
   measurement, never absorbed by widening the budget. In the sweep that converted **26 budgets
   across 17 suites, not one threshold moved**: the budget that had been failing at **1.364
   against a floor of 1.5 read 2.29** on the honest instrument — and the suite got *faster*
   (**134.33 s → 112.70 s**), because five inner batches that existed only to clear the timer
   floor turned out not to be needed.
3. **Keep both measurement points in the same memory regime.** A ratio between two operations
   sitting in different levels of the cache hierarchy measures the cache transition as well as
   the algorithm, and is unstable on a byte-identical binary: one budget moved **6.751 → 9.380**
   between two runs of the same code because its two points were 3.1 MiB and 12.5 MiB,
   straddling L3. Check the footprint *before* writing the budget. More repeats do not fix
   this — they sharpen a statistic that is answering the wrong question. A ratio *of ratios*
   is naturally robust to it. **Better still, prefer a ratio whose two sides do the same work on
   the same arrays** — a dispatch layer against the kernel it dispatches to. Those sit in one
   memory regime by construction and are the stable shape.
4. **Check that the fixed cost does not dominate before writing a growth budget.** Solve
   `f + v` and `f + 4v` from the two points: if the fixed term is the larger, the ratio is
   measuring it. One ladder was *passing* at 0.95× and 1.08× where linear predicts 2.00×,
   because **99% of the small point was the fixed cost of making the call** — a genuinely
   quadratic implementation would have scored 1.25× against a budget of 3.0. Measure the
   fixed term with an extra point and subtract it; the repaired ladder read 1.89 .. 2.00.
   Another budget asserting `< 8×` at four times the rows measured 1.44× against a linear
   4.00×, for the same reason.
5. **Below about a millisecond you are timing the timer. The cure is an inner batch, not
   more repeats.** Where the fixture can be grown, grow it. Where the quantity forbids it —
   the budget asserts that cost does *not* depend on the swept dimension — time an inner
   batch of calls and divide.
6. **Repeat count.** Measured spread over 10 trials: 5 repeats → 31.2%, 9 → 14.0%, 15 →
   10.2%, 21 → 4.4%. **Use 15** unless there is a reason not to; 5 is too thin for a budget
   asserted at twice its expected value.
7. **A number measured on one fixture is not a claim about another.** One budget was measured
   in the mirror at a large size (17.6× in favour of the new path) and asserted at 2× in a
   test using a much smaller fixture. Re-measured **at the test's own size**, the old path
   *wins* at 0.28× in the mirror and by 70× in the target language. The budget was not
   optimistic, it was false at the size it ran at, and no amount of language reasoning would
   have found it. **Where the fixture sizes cannot match — a mirror fixture is often
   deliberately larger — the assertable quantity is a ratio of ratios across two sizes**,
   which is invariant to both machine and fixture: the rewritten test predicted 3.4× growth
   and the target language delivered 3.41×, agreeing to three digits where the absolute ratio
   had disagreed by a factor of 250.
8. **A cross-language ratio transfers only when both sides scale alike, and the direction is
   not predictable.** Three data points: 26–46× in the mirror → budget 5× → delivered 57×
   (safe); 26× in the mirror → delivered **4.5× against a 5× budget** (unsafe, nearly missed);
   over-predicted by 2.3× (safe). The cause is that the two sides do not translate alike —
   a multi-core dense factorisation is ~16× faster in the target language while an interpreted
   loop is only ~3× faster, so the ratio *fell* by roughly 5× crossing languages. **Set budgets
   several times away from the mirror figure in whichever direction the failure would hurt.**
9. **The measurement point is part of the budget.** A ratio between an O(N³) operation and an
   O(N) one is a function of N, not a constant: measured 1.9× at N = 800, 4.5× at 1200, 12.7×
   at 2000, 47.8× at 4000. Fit the scaling from whatever real numbers exist, choose N so the
   *expected* value is several times the budget, and write the expectation into the test beside
   the budget so the next reader sees the margin without re-deriving it.

Two more, cheap to state:

- **A wrapper's cost is its validation, not its dispatch.** A thin layer budgeted as "a switch
  plus argument packing" measured 1.71× rather than the predicted 1.007×, because its operand
  check scanned the whole panel for finiteness — O(m·n) work inside a wrapper whose
  documentation described only O(1) work. When a thin layer measures thicker than expected,
  look at what its guards *touch* before looking at the call mechanism. When the same property
  is validated at two layers, the outer one is usually paying twice.
- **A scale-free ratio cannot be tightened by a bigger fixture.** Where a tolerance is a
  multiple of a sampling floor ∝ 1/√n, both sides fall alike and the distribution is invariant
  to fixture size. The only lever on a thin band is a larger seed study: **20 seeds set a 4×
  band that the run then met at the 96th and 100th percentiles of 300.**

Finally, **state in the test what the budget cannot catch** — one complexity budget guards the
order of growth, not the constant factor, and says so. And **mark the speed suites**, so the
runner reports them separately from the correctness gate.

And: **do not compare per-suite seconds across rounds of different colour.** A failing
verification makes the framework build a diagnostic, resolve a stack and format links, which
is not free; one suite read 1.61 s, 1.41 s, 1.27 s across three rounds while *gaining* six
points and five times as much speed-test work, and the remainder fell with the failure count.
The effect is real and directionally obvious, and it did **not** account for the whole of that
drop — the rest was recorded as unexplained rather than given a cause it had not earned.

### 3.5 Robustness — the weakest column, made explicit

- **Construct a degeneracy from the algebra, not by zeroing things that look influential.**
  A guard test built its singular case by zeroing two inputs and left behind a perfectly well
  conditioned diagonal matrix; the guard did not fire because nothing was wrong. Derive the
  parameter values that make the quantity vanish.
- **When a property has a negative half, assert it too.** An invariance test alone passes
  against an implementation that ignores its keys entirely — the exact design being rejected.
  The same applies to every guard: assert that it fires **and** that the thing it guards still
  works. In one metamorphic suite, two candidate permutations were indistinguishable by the
  estimate (both at 1.8e-16), and **the negative half is what made the property a real test.**
- **A guard test can fail because its fixture is healthy.** Check the fixture is degenerate
  before concluding the guard is broken.
- **Measure conditioning thresholds in the target language.** A conditioning table carried the
  mirror's numbers under the target language's attribution and got the refusal threshold wrong
  by two decades, because one language's estimate is the square of the other's.
- **A placeholder value in a collector result is a robustness defect, not a cosmetic one.** A
  non-finite placeholder silently broke a single-pass and a bitwise-parallel promise, and
  exposed a latent break dating from a much earlier package.
- **Test the default path of every optional argument.** A format-guard test passed cleanly
  while nine other tests failed on that very format, because it always supplied all arguments
  and the defect lived only on the default path.

---

## Part 4 — Rules for the code

### 4.1 One authority per fact, one name per thing

The version lives in one file. The manifest lives in one file. A lookup table lives behind
one function. Consumers **read the field they want** — they never recover a fact by taking a
substring of a composed value.

*Evidence:* a report title built by splitting a composed tag worked until the tag was split
across two lines; it then returned a missing value and destroyed the whole report. A consumer
that re-splits a composed authority has made itself a second authority, and the two will agree
until the day nobody is looking.

*Mechanical form:* a mirror instrument — a linter in another language, a build script — must
**derive** what the original derives. Never hold a copy. A mirror that does not mirror is worse
than none, because it is cheap and is therefore believed.

*And:* **no aliases.** A renamed thing has one name; the old one is deleted, and the rename is
declared a breaking change where it is one. One thing with two names is the shape this rule
exists to remove — including error identifiers, which are names and are not exempt.

*And:* **name the role, not the vendor.** A build report once claimed a font it had not used,
because the registered names were the supplier's rather than the role's. A build report that
names something it did not use is worse than one that names nothing, because it reads like
evidence.

### 4.2 Metadata travels with the data

The model reference, the convention, the generation, the units, the source of a table — all
travel beside the values. Anything assumed is eventually assumed wrongly.

*Test for this:* if two objects from different sources were combined by mistake, would anything
notice? If not, the metadata is missing.

### 4.3 Measured, never declared

Where the program can ask, it asks. Pairing is read from the file's own header, not inferred
from its name. A build reports what the compiler did, not what it was told to do.

*Extended form:* **a diagnostic message is a claim about the world too.** A skip reason reading
"the input is not in the set" went on printing for two revisions after the input appeared.
Derive the message from what the run actually holds.

*And the inverse:* where a check cannot see the failure that actually happened, the repair may
be a **recorded fact rather than a better test**. A generated artefact that is internally
consistent with its own build report but built from a stale declaration passes every
consistency check; having the builder record the version it *read*, and comparing two
declarations, catches it — and needs none of the tooling the consistency check needs.

### 4.4 Refuse, report, or proceed — never degrade silently

Three legitimate responses to an anomaly; "quietly return something plausible" is not one of
them. A guard that cannot positively determine a fault **proceeds** — a false negative blocks
all work, a false positive merely fails to warn.

### 4.5 Refuse what is provably meaningless; report what is merely suspicious

A refusal to combine two data generations was justified as "mixing them is not harmless and
nothing downstream would report it". The second half stopped being true — a metadata field, a
warning channel and a report section had all been added since — and the refusal then merely
prevented a legitimate comparison.

> **A library that will not let you do the thing you came to do is not protecting you.** Where
> the operation is provably meaningless, refuse it by name. Where it is only suspicious, report
> the contradiction, record it in the returned metadata, and leave the judgement with the
> caller.

*And:* **a flag that is always true is a claim to delete, not to keep.** When a correction makes
the state a flag named impossible, retire the flag and its identifiers in the same edit.

### 4.6 A tolerance is a claim about which error dominates

When a precision test fails, decompose the residual into its physical contributors **before**
touching the bound. Loosening a tolerance to make a test pass usually destroys exactly the
discrimination the test existed for. **Never loosen a tolerance to make a test pass — that is
a finding.**

*Corollaries:*

- One bound cannot span two error regimes. A planetary-ephemeris tolerance inherited by an
  asteroid comparison reported a working path as a failure **at 8 km** — a figure that was
  entirely correct and meant something else.
- A relative tolerance is undefined against an expected zero. Axis-aligned test vectors
  introduce them by the pair. Where a bin or a term is 0/0 at roundoff, assert the substitution
  rule rather than the quantity.
- Bit-identity may be asserted only where the arithmetic is elementwise. A batched and a
  per-row result that both pass through a matrix product need not agree bit for bit; the
  library may block them differently.

### 4.7 House rules that were paid for

- Gate behaviour on the structural reason, never on a literal false.
- **Declare and validate arguments in the language's own argument-validation block**, never in an
  ad-hoc parser object built at run time. Public name/value options are resolved case-insensitively
  with partial matching **off**; internal struct field access is case-sensitive — never rely on
  parser case-folding for it.
- Error and warning output only through the project's own logging function; verbosity only
  through the project's own verbosity function. No printing from library code.
- Full vectorisation; no function longer than about 400 lines without a written justification in
  the handover.
- Error identifiers `<package>:<function>:<reason>`, and the documented identifier must equal
  the raised one — enforced statically, not only by tests.
- **A validated default changes only the allowed way: measured, then decided, then frozen.**
  When a coastal-buffer default moved a headline number (+1.407 to +1.557), the change shipped
  only after the full alternative table existed from live runs, the author decided on the
  table, the old behaviour stayed reachable (option value 0, documented as the legacy
  reference), and every acceptance criterion was rebaselined in the same change — never in a
  later one.

### 4.8 Warnings are a gate

**Exactly one identifier may appear in a clean run's inventory** — a deliberate test probe.
Any other identifier is new and fails the gate. Expressed this way it needs no allow-list to
maintain, which is the point.

Two habits keep it true:

- **A test that raises a warning on purpose turns that identifier off for the duration**, with
  a cleanup-based restore, so a failing assertion cannot leave the warning state altered for
  the suites that follow. Do **not** silence it where it cannot fire: an unnecessary
  suppression teaches the next reader that the identifier is unavoidable.
- **Reuse an existing documented identifier** rather than coining a test-only one.
- **State-changing REPL experiments carry the same cleanup obligation as tests.** One
  exploratory snippet in a live session disabled all warnings, crashed before its restore
  line, and left the interpreter's warning state off globally — **six unrelated suites then
  failed their warning assertions at once**. The diagnostic rule earned there: a cluster of
  unrelated failures sharing one symptom is session state, not code — check the state before
  reading a single diff. The preventive rule: any snippet that alters interpreter state
  registers its restore *before* the alteration, even for a throwaway probe.
- **A warning-free assertion is about all warnings, not the one you mean.** Two tests asserting
  "this call does not raise X" failed because an unrelated and entirely correct identifier fired
  from the same call. Silence the neighbours explicitly, then assert. The same round **leaked 66
  instances of that identifier into the inventory**, so the two faults are one fault: an incidental
  warning that is not silenced is both a gate failure and a false negative waiting to happen.

---

## Part 5 — Rules for the tests

### 5.1 Organisation

One flat test directory, one file per public unit, function-based tests with shared expensive
fixtures — and the determinism assertion kept **separate** from the solve assertion. Discovery
finds a new suite by name: there is no list to update, which is why there is no list to forget.

**One project runner, and its count is authoritative.** The runner log records pass/fail/
incomplete, **which files loaded**, per-suite seconds, and the warning inventory by identifier.

> **A green gate means: zero failures AND every suite loaded AND no new warning identifier AND
> no speed budget exceeded.** Not "the number went up".

### 5.2 Predict the count, then reconcile it — and never persist the number

The prediction exists for exactly one reason: **a suite that silently fails to load or to run
is indistinguishable from a green run by the pass count alone.** A prediction that misses is
the cheapest available signal that the change was not the change you thought you made. One miss
was caused by counting three added *assertions* as three added *methods* — a distinction that
matters and is invisible in a green run.

Reconcile three ways: tag sums, per-class sums, and pass-plus-skip. And per suite, reconcile
**declared** points against **executed** ones: a grep for the test-function pattern, minus the
entry point, must equal the executed count exactly — 76 declared minus the entry point equals
the 75 executed, and the arithmetic is written down rather than waved off. An unexplained gap is
what a silently skipped suite looks like; the same trap was hit from the other side by a session
that predicted 23 and got 20.

> **The prediction is a disposable per-round instrument. It is never written into a document
> and no test asserts a hardcoded total** — such a number must be edited on every change and
> goes stale the way a maintained suite list does.

### 5.3 A passing test must leave the number it checked

An assertion that passes leaves no trace, so the report goes silent about exactly the
measurements that went well. Three separate figures were repaired by hand before a mechanism was
built: a helper that **qualifies the bound and returns the report record**, so an assertion
cannot exist without something to log.

*And:* a new record type is not a diagnostic until the report has a **section** for it. Two
records were logged into a section that did not exist, in revisions that cited the "diagnostics
must reach the report" rule as their justification.

### 5.4 One measurement at one setting is not a measurement

A single disagreement of **1.66e-7** was recorded as "55× above the floor" and treated as a
probable defect.
Sweeping the perturbation over four decades settled it in one run: the error fell as 1/δ,
dropping 306-fold by the largest step, so it was the *oracle's* own roundoff floor and the
analytic derivative was sound. The original floor estimate was also wrong, by sevenfold, in the
other direction.

> **A floor moves with the step; a model error does not.** When a number looks wrong, sweep the
> thing it should depend on before diagnosing it.

*Related:* a one-way comparison at one offset cannot measure a truncation, because it cannot see
a term that does not vary with the swept quantity. One error was recorded as 0.06 mm while the
dominant term was 0.7 mm and independent of the offset being swept.

### 5.45 When a number is wrong: configuration, then criterion, then code

Three wrong numbers in one live session, three different culprits — and the cheap ones
came first. A validated trend apparently halved: the *configuration* (a reference mask
paraphrased from memory instead of replayed from the frozen script). An extreme-event
check failed: the *criterion* (the strongest event in the record postdated the frozen
expectation; the literature confirmed the new event, and the criterion was corrected —
corrected, never widened until it passes). The code was innocent both times.

> **Diagnose in order of repair cost: exact configuration replay first, criterion
> re-derivation second, code last.** And a criterion is only ever *corrected* against an
> external authority, with the new numbers frozen — a criterion loosened until green is
> an instrument destroyed in place.

### 5.5 Assert the claim, not a proxy

If the specification says "the marginal cost is small", assert a **ratio against the thing it is
marginal to**, timed back to back on the same machine (§3.4.1 has what an absolute figure costs:
a shipped 1.30× regression, and a row that swung 6.8× on untouched code). If it says "this estimator recovers the
truth", check first that **the truth is detectable at that fixture size** — recovery may depend
on a dimension the brief does not name, and need not be monotone in the one it does.

*And:* **testing that an estimator ran is not testing that it worked.** A report level declared
a run unscreened because its only test was whether a state table existed.

### 5.6 Write tests that can fail informatively

The single most useful test in one project was one whose assertion was a **hypothesis**: it
stated both possible outcomes in its diagnostic and failed loudly. That failure is what got a
console log pasted, which found an unrelated defect that had gone unnoticed for three revisions.

*And its opposite:* a test that only asserts a refusal passes on a function that refuses
everything. Always pair it with the case that must succeed.

### 5.7 Regression discipline

**New behaviour ships with a test that would fail without it** — that is what makes it behaviour
rather than an intention. Every defect fixed gets a named regression test citing the record that
explains it. **A fix that
changes a contract deletes the test asserting the old one in the same edit** — one round's fix
added its regression test and left its contradictory sibling behind, which then failed the next
round. Randomness is seeded per test. Tests that need a resource carry an assumption filter and
are counted as **incomplete**, never skipped silently — and a standing incomplete belongs in the
document that records state, with the reason it is safe to leave filtered.

### 5.8 Every instrument ships with a fault-injection self-test, in the same round

This is F3, §4.1 and the audit rule as one mechanism.

- **A check without a fixture proving it fires is not a check.** Every audit check is verified
  **both ways** in the round it is added: it fires on a broken tree and is silent on a healthy one.
- **Prove a mutator on a scratch copy and read the applied diff before pointing it at the tree.**
  A help-text migration over 94 files produced **three defects — a mis-parsed signature pattern, a
  wrong header prepended to all 39 public functions, and new sections appended after the authorship
  stamp on all 44 suites — every one found by reading the applied diff and none by any check.**
- **One case form is not enough.** A later rename (426 replacements in 66 files), proved the same
  way, left the old name in every uppercase header line and in one camel-case hook after a
  lowercase-only pass. The first of those an existing check would have caught; **the second nothing
  would**, and reading the diff is the only reason it was not shipped.
- A one-shot mutator is **not shipped**. A mutator sitting among read-only scripts invites a
  second run over an already-migrated tree.
- The static audit exits zero before any ship. It is a gate, not a report.

---

## Part 6 — Process and documents

### 6.1 Three files, one job each

| File | Holds | Never holds |
|---|---|---|
| **HANDOVER** | The rules, the design, the ledger — **the only place a status lives** | Narrative evidence for finished work |
| **RECORDS** | The archived round-by-round evidence of completed packages | State. It is evidence, not status |
| **BEST_PRACTICE** | Cross-project rules — this file | Anything about one project's state |

The split was taken on a measurement, not a preference: narrative records had reached 50% of the
handover and were growing at ~4 600 tokens per package, projecting to ~190 000 tokens — which
every fresh session pays in full. The rule the split protects is intact: there is still exactly
one place to look up whether something is done.

**And the rule that keeps it finite: a trap that has become a check does not stay prose.** When a
defect is encoded as a check whose self-test reproduces it, the narrative paragraph shrinks to one
sentence and a pointer at the check. The check's docstring tells the story to a script that
enforces it; a paragraph tells it to a reader who may not be looking. Duplication is what goes
stale. Existing paragraphs are grandfathered and shrink when next edited.

This rule is what turns a falling growth rate into a flat one, and it is also measured: **after
the split the handover still grew by ~1 000 tokens per package, projecting ~63 000 by the end** —
most of the ground the split had just won.

### 6.2 A session is not complete until its report has been read

Code that has not been executed is a draft, however carefully reviewed. One project's foundation
session was reviewed through nine revisions and still contained four wrong statements about the
language itself, one test that had never checked what it claimed, and one false positive — none
reachable by reading, all reachable by one run. In another, **seven of ten defects in the first
package needed the run to surface.**

Mark such a session provisional on the status board, never done.

**Done means: a green gate, on the real runner, with its date and its counts.** Not a green
subset, and not the package's own suite passing while the gate is red.

### 6.3 Freeze the scope before implementing

Design grows indefinitely under review. Fix the deliverable list, deliver against it, and put
everything new in a backlog with explicit re-entry criteria.

### 6.4 Record decisions with their reasoning, their date, and their re-read trigger

A numbered decision log: what was chosen, what was rejected, the number that decided it — **and
the condition whose change invalidates it.**

The trigger field is the addition. **(proposed)** Three decisions in one project were reversed: a rejected
sandbox runner, a refusal to persist a path setting, and a harness held outside the tree. **All
three were correct when taken and wrong later**, and nothing prompted the re-read; two were found
by a person noticing, one by silent rot. Recording *why* is not enough — record *what would have
to change*.

Do the same for **obligations**: standing rules with an owner and a closing condition, kept in one
place a later reader will actually find.

### 6.5 Prefer a mechanism to a reminder

Every rule that survived was turned into something that fires: a test, an audit check, a formatter
that cannot be used without producing a record. Every rule that stayed a note was broken again —
usually by the person who wrote it, usually within three revisions.

The strongest form of this in either project: a documentation rule that had been true of the **56**
functions a user can call and of almost nothing else — **123** helpers with no errors section,
**840** test functions with no input section, **462** with no help block at all. **The rule was
amended in the only direction that keeps a rule honest: the tree was brought up to it with no
exemption, and it became an audit check that reads 2 348 functions and passes.** A rule nothing enforces is a rule that
has already stopped being true; the check is the difference between the two.

### 6.6 Do not mix a substantial change with unrelated repairs

A stretch of one project's history reads: real work, fix what the real work broke, fix the fix, fix
the instrument added to check the fix. The loop converges, but on tooling rather than on the
subject. Give a substantial change its own session.

**And when the same defect appears a third time, stop patching instances.** Three sightings of one
timing defect in three packages is not three incidents; it is the shape the project writes budgets
in. The interesting half is the budgets that *pass* — they pass on margin they have not earned,
because a drift moves a one-sided budget toward its threshold in a direction nobody is watching.

### 6.7 Version the artefact against its evidence

**The patch component is the test-point count**, and it moves when the evidence moves. A rename
making 426 replacements in 66 files correctly bumped nothing — bumping it would have stated something
false about the evidence. The document revision is recorded separately, in the same edit, so any
copy of the sources names the log entry that explains it. Dates cannot do this: two revisions on one
day are ordinary.

### 6.8 Documentation is a deliverable, and it is verified like one

- **Every function carries full help text**, to one template: a one-sentence purpose line; the call
  forms; a **motivated** description — why, with the measured numbers backing any claim it makes;
  inputs and outputs with name, type, dimension and description for every argument and field; the
  options with their defaults; an **ACCURACY** block stating what the function's numerical claim is
  and what it was measured against; the identifiers it raises **grouped by cause**; a runnable
  example; cross-references; and an authorship/date stamp in a fixed position. Updates append rather
  than overwrite. This is an audit check that reads the whole block, not a habit (§6.5), and not a
  first-line check (F3).
- **Public documentation is reachable from the language's own help system**, with no scripting of any
  kind and every equation a static image. A generated manual is **verified by rasterising it and
  looking**, never by the absence of an exception.
- **Every change ships its documentation in the same change — all surfaces, every time.** A
  behavioural change is not complete until the help text, the generated HTML reference, the
  guide, the README, the change log, the citation file and every auxiliary document that
  mentions the touched surface are updated **in the same commit or pull request**, and a
  sync gate proves it: an automated audit that cross-reads help, HTML and guide and fails on
  any disagreement (in the third project: 182 public entities checked on every round). This
  is a gate, not a habit, for the usual reason — in one rename, the guide's edit was
  silently lost when its patch script crashed after the replace but before the write, and
  the sync gate was the only thing that noticed. Two supporting rules paid for in the same
  project: the **version string is one fact with one authority** (a contents header), and
  every other file that repeats it — citation metadata, change log, HTML landing page,
  built manual — is checked against that authority, because a docs-only release once went
  out with the chain split across two versions when a patch failed half-way. And the sync
  gate runs on a **fresh mirror after the documentation rebuild**, never before it — a gate
  that reads yesterday's build approves yesterday's docs.

  The residual the gate cannot see is content that is *present but not rendered*: a
  reference section shipped for years with every input's description parsed into the data
  model and never printed, and every audit stayed green because nothing disagreed — there
  was no text to disagree with. The countermeasure is §F1's: count completeness in the
  **built artefact** (arguments documented / arguments rendered), not in the pipeline that
  feeds it.
- **An unavailable rebuild is a rebuild that does not happen.** One manual drifted four releases
  behind because its build required a font that was installed on no machine in the loop. Ship the
  build's dependencies inside the tree and search there first. And state the consequence rather than
  discovering it: different metrics mean different line breaks, so page counts and hashes move
  deliberately.
- **Documented claims are quoted numbers and go stale like any other copy.** Re-check every quoted
  number when the document is rebuilt, or derive it. This is the third face of one defect — the same
  mis-attributed conditioning table appears in §2.3 as a limit of the mirror and in §3.5 as a reason
  to measure thresholds in the target language.
- **Write the documentation in the same prompt as the code** (§7.4).

### 6.9 Measure the workflow itself

Keep one small standing table: package · rounds · findings from pre-validation · findings from the
run · defects found in shipped code. **(proposed)**

It is cheap, and it is the only way to know whether the pre-validation stage is still paying. In the
second project it plainly was: several packages went green on the first round with **no defect in
shipped code at any point**, their round-one failures being test faults and specification errors
that pre-validation had already reframed. That is a claim worth being able to check rather than
assert.

---

### 6.10 The repository loop — hosted CI as the shared instrument

The third project ran its entire life through a hosted repository: one branch per topic,
model pushes and polls, the author alone merges. The division of authority is the point —
the model can propose, build, and prove; only a human advances main. Everything below was
paid for inside that loop.

**Setting up the pipeline — the order that pays**

1. **One workflow, triggered on both push and pull request — deliberately both.** The twin
   run looks redundant and is an instrument: when a runner step hangs, the only way to
   tell platform trouble from a genuine hang is to **compare the step's duration against
   its twin** from the other trigger. That comparison settled four hang diagnoses in one
   session.
2. **Static gates first, runtime second.** Lint, help audit, documentation-sync audit, API
   surface check and attribution sweep need no language runtime — run them before the
   runtime-setup step so a docs defect fails in seconds instead of after minutes of
   environment provisioning.
3. **The runtime-setup step gets an explicit step-level timeout.** Its nominal duration is
   known (1.2 minutes there); the hung case ran 5–10. Without the timeout the pathological
   case burns the queue and looks like a slow success.
4. **The suite runs headless on fixtures only; data-gated tests self-filter on environment
   variables — and the filtering is loud.** Fixture *presence* is asserted, never assumed:
   the silent-assume form let a mistyped fixture name filter a chain test out for **seven
   minor versions**, indistinguishable from passing (§F4). A filtered test appears in the
   count as incomplete, and the count is reconciled every run (§5.2).
5. **The documentation build runs inside CI, and its examples are code**: every snippet in
   the guide is extracted and linted at build time (85 snippets there), so a guide example
   that stops compiling fails the build, not the reader.
6. **The acceptance numbers live in CI as frozen values with tolerance windows** — this is
   what made the pipeline a scientific instrument (the same wrong algorithm rejected three
   times, below).
7. **The zero-warning inventory gate runs in the same job** (§4.8): exactly one deliberate
   probe identifier allowed, anything else fails.
8. **Every gate must run locally, byte-identical, on a fresh mirror.** CI is the shared
   instrument, not the only one — a contributor who cannot reproduce the gates locally
   ships guesses and polls; the project's rule was six local gates at zero before any push,
   with CI confirming rather than discovering.
9. **Provision the token with the scopes the incident needs**, not the happy path: cancel
   and rerun require write on the actions surface (§above).

**Branching and merging**

- **Branch from the remote head immediately before pushing, never earlier.** Three pull
  requests collided on duplicate version bumps in one session because each had branched
  from a main that was current when the session started and stale when it pushed. The
  later, sharper form of the same defect: a release branch cut without a fresh fetch sat on
  a base several merges old, every gate green, the failing patch anchor the only symptom
  (§2.35).
- **Read the pull-request state through the API before every push.** A push onto a branch
  whose PR the author has already merged or closed is work delivered to a graveyard; the
  check costs one call.
- **Stacked branches re-target only when their base branch is deleted.** A PR stacked on
  another does not follow its base to main on merge — it must be re-targeted explicitly,
  and after any stacked merge the proof that content arrived is a **grep of main for the
  new symbols**, because the platform's merged flag can be true while the content sits in
  an intermediate branch.
- **A superseded pull request is closed, not left open.** One stale PR carrying an
  algorithm later shown wrong stayed open beside its corrected successor; merged by
  accident it would have shipped a defect the CI criterion had already rejected three
  times. Close it with one sentence saying why.

**CI as an instrument**

- **A frozen numerical criterion in CI is a scientific instrument, not a formality.** The
  same wrong algorithm was pushed three times in different forms, and the frozen acceptance
  number rejected it three times — before any human read the diff. This is §5.5's
  "assert the claim" earning its keep: the claim was a number, so the instrument could
  say no.
- **Green CI is still not a correctness certificate.** Audits found tests that asserted
  the wrong thing, tests exercising zero library code, and data-gated tests silently
  filtered by a renamed fixture — all green. When the local interpreter is unavailable,
  CI becomes the *only* instrument: four releases shipped in that mode, and the debt was
  paid later by the live-machine findings of Part 1. Record the verification mode of every
  release; "verified by static gates and CI only" is a debt entry, not a status.
- **Distinguish platform lag from a genuine hang before cancelling.** A hosted setup step
  hung four times in one session (5–10 minutes against a nominal 1.2). The tell: a run
  reporting completed while the check shows pending is bookkeeping and resolves itself; a
  job step genuinely in progress far past nominal is cancelled and rerun through the API.
  Set a step-level timeout so the pathological case fails fast.
- **Poll on the suite's own cadence** — one sleep of roughly the suite duration, then one
  status call; the check-run record lags the workflow record by design.

**Platform mechanics that cost an afternoon each**

- The raw-file CDN caches branch tips for minutes: **fetch raw content by commit hash,
  never by branch name**, or a gate reads yesterday's file and approves it.
- Escape what the URL layer eats (a plus sign in a package path travels encoded), and
  prove a fetch by content, not by status code.
- Token scopes are workflow design: cancelling and re-running CI needs write scope on the
  actions surface, and mid-incident is the wrong time to discover it.

### 6.11 The independent audit is its own phase

Once per release cycle, run a session whose only deliverable is findings: **no deference
to green CI, find first, fix nothing until agreed**, every finding ranked by severity with
its evidence attached. One such audit of a suite that was fully green produced eleven
findings — among them a reader returning plausibly-shaped wrong values through a silent
fallback, a science test that passed with the sign of its headline number flipped, and
twenty-odd tests a single file rename would silently filter out. None of these is visible
from inside the fix-as-you-go loop, because that loop only looks where it is currently
working.

The protocol that made it work: scope declared up front (suite integrity, documentation
truth, science reproduction, numerical foundations, error handling), every claim backed by
an executed command, findings ranked and *left unfixed* until the author agreed — which
kept the audit's incentives honest: an auditor who fixes as they go stops finding.

### 6.12 Changing an on-disk contract **(proposed)**

When a default path or layout changes, ship a **loud one-time detector for the legacy
location** in the same change — the alternative is a silent re-download or a silently
empty read, both shapes of F1. And treat the user's actual disk as specification: one
layout question in the third project was settled by looking at the migrated data folder,
which contradicted the plan and was right.

### 6.13 The session handover **(proposed)**

A collaboration whose memory resets each session lives or dies by its handover document:
one file, explicitly superseding all earlier ones, opening with a **verification-debt
table** ("what is unverified and why") before any accomplishment. The third project's
debts — a settings path never executed, a test green in CI but never run locally — were
listed in exactly this form, and every one of them turned into a real finding when the
live phase arrived. A handover that lists only what works is an advertisement, not an
instrument.

---

## Part 7 — Prompting

### 7.1 The standing instruction

See Appendix A for the pasteable form. Why each clause earns its place:

- **"follow the handover exactly"** — one authority, so a rule is never restated in a prompt where
  it can drift.
- **"and the corresponding tests"** — otherwise tests arrive a session late and the code is never
  exercised.
- **"state any assumption you had to make"** — the single highest-yield clause. It converts silent
  guesses into visible ones.
- **"satisfy the definition of done before declaring it complete"** — written before the work rather
  than after it.
- **"read the binding items of what you depend on"** — the short list of sentences you can be wrong
  for not having read. Explicitly *not* the archive: that is for when you need the evidence behind a
  decision, not before starting.

### 7.2 The per-session prompt

State, in this order:

1. **What is being built**, in one sentence.
2. **What it depends on** — which earlier work must be green first.
3. **The deliverables**, numbered, each one testable.
4. **The accuracy requirement**, as a number, with the reason that number and not another.
5. **The oracle** — what will this be checked against that was not built here?
6. **The test categories shipped**, and any exemption with its reason.
7. **Re-entry criteria** if it is deferred.

If item 5 cannot be answered, the prompt is not ready.

### 7.3 What to ask for in the wrap-up

- What changed, and what it was measured against
- **The predicted test count** (per §5.2 — for this round, not for the document)
- Every finding from pre-validation, with its measurement
- Any assumption made
- Anything that was *not* done, and why

### 7.4 Anti-patterns

| Anti-pattern | What happens |
|---|---|
| "Make it robust" | Unfalsifiable. Ask for a named failure mode and the behaviour under it. |
| "Fix the failing test" | Invites the tolerance to be loosened. Ask what the residual is made of. |
| "It should be about X" | A number that is *about* right is asserted, then inherited for fifty revisions. Ask for measured or explicitly predicted. |
| Several unrelated items in one prompt | Produces the repair loop in §6.6. |
| "Also update the docs" as an afterthought | Documentation written after the fact describes what was intended. Ask for it in the same prompt as the code. |
| "Port this from the old version" without "start from that file" | Invites a rewrite of verified code. Say: start from the verified file and adapt it to the new contract. |

### 7.5 What the human contributed that mattered most

Recorded because it is not obvious, and because it is the part no amount of care on the model's side
replaces:

- **Running the code.** Every session that was not executed contained defects that no review found.
- **Reading the report rather than the summary.** A stale report, an unreadable file and a wrong
  diagnostic message were all found by a person reading output and saying "that does not match what
  I see".
- **Supplying primary sources.** A release paper turned a plausible claim into a quantified one — and
  showed that the *reason* given for the claim had been wrong even though the claim was right. A real
  third-party data file settled a format question that documentation had got wrong.
- **Rejecting a design.** The decision to warn rather than refuse came from the user, against a rule
  the model had been defending for eighty revisions.
- **Noticing repetition.** "I feel we are going in circles" was correct, and produced a measurement
  showing that roughly a third of recent revisions were findings and the rest were repairs to
  instruments added the revision before.

---

## Part 8 — The one-page checklist

**Before writing code**

- [ ] Tier declared: is the interpreter live in this session, or is the mirror the instrument?
- [ ] Fetched before branching? Branch cut from the remote ref, not a stale local main?
- [ ] PR state read via API before this push? After a stacked merge: symbols grepped on main?
- [ ] Help, HTML, guide, README, change log, citation — all updated in THIS change, sync gate
      run on a fresh mirror after the doc rebuild, version chain from its one authority?
- [ ] All gates green LOCALLY on a fresh mirror before the push — CI confirms, it does not
      discover?
- [ ] Is there an oracle outside this project? If not, stop and find one.
- [ ] Has the *specification* been run against the mathematics? What did that find?
- [ ] Is the scope frozen and written down?
- [ ] Which existing decision does this change? Is its reasoning still true?

**While writing**

- [ ] One authority per fact; one name per thing; consumers read fields, never parse composites.
- [ ] Any number derived from the data: is its span written beside it? Any iterative correction:
      is the depth ladder measured and frozen, with the default at the validated point?
- [ ] Metadata travels with the values.
- [ ] Every approximation named and quantified where it is made.
- [ ] Nothing degrades silently; nothing is refused that the caller may legitimately want.
- [ ] Code and its tests in the same session, always.

**Before claiming it works**

- [ ] All test categories present, counted mechanically; every exemption has a reason.
- [ ] Every measured number appears in the report, pass or fail.
- [ ] Every "X is small" asserted as a ratio; every speed budget paired, rotated and median-of-ratios.
- [ ] Every guard asserted in both halves; every degeneracy constructed from the algebra.
- [ ] Predicted test count stated for this round.
- [ ] Any instrument written this session fault-injected, or distrusted in writing.
- [ ] Any mutator proved on a scratch copy, with the diff read.

**After the run**

- [ ] Report read in full: what loaded, the warning inventory, per-suite seconds — not the summary line.
- [ ] Count reconciled three ways, and declared-vs-executed per suite.
- [ ] Each failure diagnosed before any bound is touched.
- [ ] Anything closed has produced a number, end to end.
- [ ] Third sighting of a defect? Treat it as systemic, not as a third incident.

---

## Appendix A — The pasteable standing preamble

> You are an expert `<language>` programmer and `<domain>` specialist working on
> `<project>`. Think step by step and **motivate every answer** — why, not just what.
>
> **Read `HANDOVER.md` first.** Its rules, ledger, design and guideline sections are binding; the
> task below names the sections that matter. Read the BINDING items of the digests for anything this
> task depends on — they are short and they are the sentences you can be wrong for not having read.
> Do **not** read the archived records up front: they are evidence for when you need it, not
> background.
>
> **Execution tier for this session: `<A: a live <language> session is reachable — its run is ground
> truth>` / `<B: no interpreter here — pre-validate in the Python mirror, the user's run is the
> gate>`.** Under A: static-check every changed file, then run the one project runner over the same
> folder the deliverable is built from, long suites through the background call with its status file,
> and read the log rather than the pass count. Under B: pre-validate every asserted number in the
> mirror against exact or independent formulae, validate structurally and with the static audit, and
> ship the entire tree as one artefact with a regenerated transfer manifest.
>
> **Reuse the mirror rather than re-deriving anything a previous package already mirrored**; add to
> it what yours mirrors, and record what it cannot see. Where the two disagree, `<language>` is right
> by definition.
>
> **Validate the specification before implementing it.** If the brief's mathematics, tolerance or
> acceptance test is wrong, that is a finding: report it with its measurement before writing code.
>
> **Deliver together:** the code, its tests, and its documentation. Tests cover contract, reference,
> precision, speed, robustness and metamorphic properties as applicable; name any category you do not
> ship and why it is impossible rather than inconvenient. Speed budgets are relative, paired inside
> each repeat, rotated, and reported as a median of per-repeat ratios with the measured band.
>
> **Binding on every task:** one authority per fact, one name per thing, no aliases; full help text
> to the template — motivated description, typed and dimensioned inputs and outputs, the ACCURACY
> block, an errors section grouped by cause, a runnable example, the stamp in its fixed position;
> error identifiers `<package>:<function>:<reason>` matching the documented ones; arguments declared
> and validated in the language's own validation block, never an ad-hoc parser; the coding standard;
> full vectorisation; no printing from library code; nothing degrades silently.
>
> **State every assumption you had to make.** Where code is named "port from the verified version",
> start from that file and adapt it to the new contract rather than rewriting it.
>
> **Satisfy the definition of done written at the head of this task before declaring it complete** —
> the seam contract, decided before the work rather than after it. A task is done on a green gate,
> not on a green subset.
>
> **End with a wrap:** what changed and what it was measured against; the predicted test count for
> this round; every pre-validation finding with its measurement; every assumption; and anything not
> done, with the reason. Update the ledger row and the task's own section; leave a digest carrying the
> confirming run, what shipped, and every binding item a later task could be wrong for not reading.

---

## Appendix B — What carries evidence, and what does not

Rules in this file fall into three classes. The distinction matters, because §6.5 says a rule that
nothing enforces has already stopped being true — and a rule nothing has *paid* for is weaker still.

**Paid for by a recorded defect.** Part 1; Part 2 except §2.4's second half; §3.1, §3.3, §3.4, §3.5;
Part 4 except §4.2 and §4.4; §5.1, §5.3–§5.8; §6.1, §6.2, §6.5–§6.8; §7.1, §7.4, §7.5. Most carry
their measurement in the text.

Three of these are stated without a number because neither source recorded one — **§4.2** (metadata
travels with the data), **§4.4** (refuse, report or proceed) and **§6.3** (freeze the scope). They
are consequences of defects recorded elsewhere rather than rules with their own incident, and they
are listed here so the gap is visible rather than assumed.

**Merged from two conflicting practices, resolved deliberately** (these also appear above; the
overlap is intentional, since a merged rule is still a paid-for one):

- **§5.2, the predicted test count.** One project required a prediction before every run; the other
  forbade predicted counts. Resolved: the prediction is a per-round instrument whose purpose is to
  detect a suite that did not load or did not run, reconciled against the runner's authoritative
  count and against declared-vs-executed per suite — and never persisted in a document or asserted in
  a test.
- **§4.4–§4.5, refuse versus report.** One project learned not to overrule the caller; the other
  refuses many things by name. Resolved: refuse what is provably meaningless, report and record what
  is merely suspicious, and re-read every refusal when its conditions change.
- **§6.7, what the version number means.** One project tied the patch component to the document
  revision, the other to the test-point count. Resolved in favour of the evidence count, with the
  document revision recorded alongside.
- **§4.7, how arguments are declared.** One project forbade run-time parser objects outright; the
  other required a case-insensitive name/value parser with partial matching off. These are not in
  conflict once separated: the language's own validation block declares and types the arguments, and
  case-insensitive resolution applies to public name/value options only — never to internal struct
  fields.

**Proposed, not yet paid for.** Four rules, each marked **(proposed)** where it is stated: the oracle
register (§3.2), the re-read trigger field in the decision log (§6.4 — inferred from three reversals
that had no such field, so the *need* is evidenced and the *mechanism* is not), one-package rounds
under Tier A (§2.4), and the workflow-performance table (§6.9). Treat them as hypotheses. If one of them has not caught anything within a few packages, that is a finding about
the rule, and it should be dropped rather than kept out of politeness.

---

*Merged from a best-practice distillation of one project (revisions 1.0–1.180) and the handover of a
second (38 work packages, 43 suites, 1206 test points at freeze). Neither source document is superseded;
this file is a distillation and carries no authority they do not.*

*Compiled 2026-08-06 by Matthias Weigelt with the assistance of Claude Opus 5 (Anthropic).*
