# codex2 dispatch runbook (lessons from the 26.2.x patch)

What looked like "codex2 hangs" during this patch was actually correct
codex2 behaviour driven by sloppy prompts. This runbook documents the
patterns that fail, the patterns that work, and the explicit knobs to
use for future dispatches.

## Three failure modes seen in this patch

### 1. Cross-file atomic dependency × per-file gate

**Symptom:** codex2 makes the first edit, runs the static gate, the
gate fails because a port-list change in file A breaks an instantiation
in file B that hasn't been edited yet, codex2 stops per the "stop on
first failure" instruction, no commit lands.

**Example:** the GEOM_FIX dispatch asked codex2 to edit
`frontend_csr.sv` and `emulator_mutrig.sv` separately with the static
gate after each. The CSR change rips out the old port; the top still
wires the old port; gate fails between files; codex2 stops.

**Fix:** for cross-file dependent changes, instruct codex2 to:
1. make **all** touched edits first
2. run the static gate **once** on the combined tree
3. commit as one mega-patch OR commit each file in sequence only after
   the combined gate passes
4. explicitly enumerate the port-list / signal renames so the agent
   can make them atomically

### 2. Polling for a parallel codex2 job

**Symptom:** job B sits in a `sleep 30 && grep commit-count` loop
waiting for job A to land N commits. Job A halts (per #1 above), so
job B polls forever, eventually exits at the codex2 wallclock budget
with zero work done.

**Fix:** never have one codex2 job wait on another. Orchestrate
sequencing from outside via the harness `Bash` tool with
`run_in_background=true` and the task-completion notifications.
Codex2 has no shared state with parallel jobs; polling git from
inside one codex2 process to wait for another's commits is a
deadlock generator.

### 3. `xhigh` reasoning on long multi-step prompts

**Symptom:** codex2 prints the prompt, prints `tokens used 13,224`,
then exits with no codex turn at all. Smoke test of a trivial prompt
succeeds; the same trivial prompt with `medium` reasoning also
succeeds. Long multi-step prompt with `xhigh` (the codex2 default)
exhausts the per-session token budget on planning before the first
tool call.

**Fix:** always pass `-c 'model_reasoning_effort="medium"'` to
`codex2 exec` for prompts longer than a paragraph or that require >2
tool calls. Reserve `xhigh` for short single-step "think hard about
this one decision" prompts.

## What works

A focused codex2 dispatch should look like:

```bash
codex2 exec --skip-git-repo-check \
    -c 'model_reasoning_effort="medium"' \
    -C <ip-dir> \
    "<prompt below>" \
    < /dev/null \
    > /tmp/codex2_<task>.log 2>&1 &
```

Prompt anatomy that lands:

1. **Single bounded task** — one of: rewrite this one file, add this
   one feature, fix this one specific failure. Not "do A then B then C".
2. **Self-contained** — read these specific files first, follow this
   specific skill, write to these specific paths. No outbound
   dependencies (don't wait, don't poll, don't expect another agent's
   work to be ready).
3. **Atomic completion criterion** — "the static gate passes on the
   combined tree, then commit". Not "after each file, gate then commit".
4. **Bounded retry budget in the prompt** — "if the gate fails, fix
   the immediate cause and retry up to 3 times; if still failing,
   abort with a status report and do not commit".
5. **Explicit format for the commit message** — paste the
   `git-commit-style-lint` rules verbatim so the agent doesn't
   bikeshed the message format and trip the hook.
6. **`< /dev/null`** redirect — codex2 reads from stdin even when a
   prompt is given; without `</dev/null` it can race with EOF and exit
   immediately.

## What does NOT work

- Multiple codex2 jobs that try to coordinate via shared git state.
  Treat them as fully independent; orchestrate from outside.
- `--enable` or `--disable` magic flags as a substitute for explicit
  prompt content.
- Asking codex2 to "decide" what to do. Codex2 follows directives
  much more reliably than it explores. Spec the deliverable.
- Multi-hour plans inside one prompt. Break them into 2..4 codex2
  dispatches that each take 10..20 minutes.

## Reference: things that landed cleanly in this patch

- `doc/wiki/scripts/lint_wiki.py` (single file, well-spec'd, medium reasoning)
- `tb/script/build_cov_profiles.py` regeneration
- The folder reorg (single shell script of `git mv` calls)

## Reference: things that stalled

- Multi-file RTL refactors split across N commits with per-file gate
- Two parallel codex2 jobs with one waiting on the other's commits
- Long multi-phase "DV closure + syn closure + tb_int setup" prompts
  with `xhigh` reasoning
