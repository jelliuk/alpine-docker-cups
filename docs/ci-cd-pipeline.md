# CI/CD Pipeline Reference

This document describes every GitHub Actions workflow and the Dependabot
configuration in this repository: what each one does, when it runs, how they
depend on each other, and what to check first when something breaks.

Each workflow section below starts with a fenced `meta` block. That block is
intentionally terse and consistently structured so it can be parsed
programmatically (by a script, or by an AI assistant working on this repo) as
well as read by a person. The prose underneath each block explains the *why*.

---

## Pipeline overview

```
Dependabot (raises PRs against `development`)
        │
        ▼
PR Validation (runs on the PR, builds the image)
        │  (required check — gates auto-merge)
        ▼
Dependabot auto-merge (merges once PR Validation passes)
        │
        ▼
development branch updated
        │
        ▼
Development Build and Publish (schedule / push / dispatch)
        │  tags image as :dev, publishes, scans
        │  opens/auto-merges a PR to sync security-findings.md
        │  (workflow_run trigger, gated on success + head_branch=development)
        ▼
Production Build and Publish
        tags image as :latest, publishes, scans
        opens/auto-merges a PR to sync security-findings.md
```

`security-findings.md` is written by both Development and Production, and
each build syncs its own section to the other branch so `development` and
`master` never diverge on that one file. This sync now goes through a real
pull request (build_check must pass, same as any other PR) rather than a
direct push — see the Reusable workflow section for the mechanism and why
it changed.

---

## `.github/dependabot.yml`

```meta
type: config (not a workflow)
purpose: raise dependency-update PRs
targets: docker base image, github-actions versions
target_branch: development
schedule: docker=daily, github-actions=weekly
open_pr_limit: 5 per ecosystem
```

**Purpose.** Configures Dependabot to watch two ecosystems: the `docker`
base image referenced in the Dockerfile, and the versions pinned in our own
`uses:` steps across all workflows. Both raise PRs against `development`
rather than the repository default branch, so nothing lands on `master`
without going through the Development validation → promotion path.

**Maintenance notes.**
- If a third ecosystem is ever introduced (e.g. `npm`, `pip`), add a new
  `updates:` block and remember to set `target-branch: "development"` on it
  too — it is not inherited, it must be repeated per block.
- `open-pull-requests-limit: 5` is a safety valve against PR floods; raise it
  only if Dependabot is being throttled and backlog is a known, accepted
  problem.

---

## `.github/workflows/dependabot-auto-merge.yml`

```meta
name: Dependabot auto-merge
trigger: pull_request (any branch, filtered in job condition)
runs_condition: actor=dependabot[bot] AND base.ref=development
gates_on: required status checks (see PR Validation) — not update-type
permissions: contents:write, pull-requests:write
depends_on: PR Validation (must be a required check on `development`)
external_setup_required:
  - repo setting "Allow auto-merge" must be enabled
  - branch protection on `development` must list PR Validation's job as required
```

**Purpose.** Flags eligible Dependabot PRs for GitHub's native auto-merge.
Important distinction: this workflow does **not** merge anything itself. The
`gh pr merge --auto` call only registers the PR to merge itself the instant
all *required* status checks pass — the actual gate is configured outside of
YAML, in the repo's branch protection settings.

**Why there's no update-type filter.** An earlier version only auto-merged
patch/minor bumps. That was deliberately removed — the design now trusts
required CI checks (PR Validation building the image) as the safety net for
every update, including majors. A commented-out `if:` line is left in the
file as a one-line toggle if you want to reinstate the major-version
exclusion later.

**Maintenance notes / gotchas.**
- This workflow being "green" proves nothing about whether the merge actually
  happened — check the PR's own merge status, not this workflow's status.
- If auto-merge silently never triggers, check, in order: (1) is "Allow
  auto-merge" enabled in Settings → General, (2) is the PR Validation job
  actually registered as a *required* check on `development` (GitHub only
  offers a check in that picker after it's run at least once — see below),
  (3) does `github.repository` in the `if:` condition still match the repo
  name (it's hardcoded).
- This is no longer the only automated PR/auto-merge flow in the repo: the
  reusable workflow's `security-findings.md` sync (see below) also opens PRs
  and calls `gh pr merge --auto` directly (it doesn't go through this
  workflow — its `if:` condition is scoped to `actor=dependabot[bot]` so it
  won't fire for the bot's own sync PRs). Both flows depend on the same
  "Allow auto-merge" repo setting and the same `build_check` required
  status check, so a change to either setting affects both.

---

## `.github/workflows/pr-validation.yml`

```meta
name: PR Validation
trigger: pull_request → branches: [development]
job: build_check
purpose: prove the Dockerfile still builds before merge; required check for auto-merge
gating_behavior: build step gates (must succeed); Trivy scan is informational only
permissions: contents:read
concurrency: per-PR-number, cancels superseded runs
```

**Purpose.** This is the only workflow that runs *before* code lands on
`development`. It builds the image (no push, no signing) to prove the
change — most often a Dependabot base-image bump — doesn't break the build.
It also runs a non-blocking Trivy scan purely for visibility in the PR's
logs; that scan never fails the check, only the build step does.

**Why this workflow exists at all.** Without a check that actually runs on
the PR itself, "require status checks to pass" in branch protection has
nothing to attach to, and GitHub's auto-merge has nothing to wait for. This
is the piece that makes `dependabot-auto-merge.yml` meaningful rather than
a no-op.

**Maintenance notes / gotchas.**
- GitHub Branch Protection only lists a status check as selectable once it
  has run at least once in the last week. After first adding/renaming this
  workflow or its job, open one throwaway PR against `development` to
  register the check before it can be marked required.
- If you rename the workflow (`name:`) or the job id (`build_check`), the
  required-check name in branch protection changes too and you must
  re-select it, or protection silently stops enforcing anything.
- This check now gates two distinct kinds of PR against `development`:
  Dependabot's dependency-bump PRs, and the reusable workflow's
  `security-findings.md` sync PRs (branch `bot/security-findings-sync-*`).
  Both need `build_check` to pass before their respective auto-merge can
  fire — there's nothing `security-findings.md`-specific in this workflow,
  it's just an ordinary PR to it.

---

## `.github/workflows/docker-build-publish-development.yml`

```meta
name: Development Build and Publish
triggers:
  - schedule: '0 0 * * *' (daily, regular pipeline validation)
  - push: branches: [development]
  - workflow_dispatch
calls: ./.github/workflows/reusable-build-scan-publish.yml
inputs_passed: {ref: development, tag_channel: dev}
concurrency: docker-cups-build-publish (SHARED with Production — see note)
downstream: triggers Production via workflow_run on success
```

**Purpose.** The "does the pipeline itself still work" heartbeat, plus the
first stage of promotion. Runs daily regardless of activity (catches
pipeline rot — broken actions, expired tokens, registry auth issues — even
if no one has touched the Dockerfile recently), and immediately on every
push to `development` (including Dependabot auto-merges) for fast feedback.
Publishes the image tagged `dev`.

**Maintenance notes / gotchas.**
- The `concurrency.group` is deliberately identical to the one in
  `docker-build-publish-production.yml`. This is not a copy-paste leftover —
  it serializes the two workflows so their git-writing steps (inside the
  reusable workflow) can never race against each other. Do not "fix" this by
  giving them different group names without understanding why — see the
  Reusable workflow section and the race-condition incident it documents.
- All real build/scan/publish/sign logic lives in the reusable workflow, not
  here. This file should stay a thin trigger+input wrapper; resist adding
  steps directly to it — add them to the reusable workflow instead so
  Development and Production stay identical in behavior.

---

## `.github/workflows/docker-build-publish-production.yml`

```meta
name: Production Build and Publish
triggers:
  - workflow_run: ["Development Build and Publish"], types: [completed]
  - workflow_dispatch
run_condition: workflow_dispatch OR (workflow_run.conclusion=success AND head_branch=development)
calls: ./.github/workflows/reusable-build-scan-publish.yml
inputs_passed: {ref: master, tag_channel: latest}
concurrency: docker-cups-build-publish (SHARED with Development — see note)
```

**Purpose.** Publishes the `latest`-tagged production image, but only after
a Development run has completed successfully. This is what satisfies
"Prod should build and publish on success of the Development action."

**Important caveat — this is NOT a promotion mechanism.** This workflow
builds whatever is currently on `master`. It does not merge `development`
into `master` for you. If nothing has promoted the code from `development`
to `master`, a successful Development run will trigger a Production build
of unchanged `master` content. Promotion (PR or merge from `development` →
`master`) is currently a manual step outside this pipeline — see "Open
recommendations" at the end of this document.

**Maintenance notes / gotchas.**
- `workflow_dispatch` is kept as a manual escape hatch (e.g. re-publish prod
  without waiting on/re-running Development) — it deliberately bypasses the
  success-gate condition.
- The `head_branch == 'development'` check exists so this doesn't
  accidentally fire off an ad-hoc Development run against some other ref.

---

## `.github/workflows/reusable-build-scan-publish.yml`

```meta
name: Reusable - Build, Scan & Publish
trigger: workflow_call
inputs:
  ref: {type: string, required: true}          # branch to build from
  tag_channel: {type: string, required: true}  # floating tag, e.g. dev|latest
outputs:
  digest: multi-arch image digest
permissions_requested: contents:write, packages:write, id-token:write, security-events:write, pull-requests:write
called_by: [docker-build-publish-development.yml, docker-build-publish-production.yml]
external_setup_required:
  - repo setting "Allow auto-merge" enabled (Settings → General)
  - repo setting "Automatically delete head branches" enabled (recommended,
    keeps bot/security-findings-sync-* branches from piling up)
```

**Purpose.** The single source of truth for build → scan → publish → sign,
called with different `ref`/`tag_channel` inputs so Development and
Production always behave identically. All future pipeline changes (new scan
severity, new registry, new signing method) belong here, once, rather than
duplicated across two files.

**Process, in order:**
1. Checkout `inputs.ref` with full history (`fetch-depth: 0` — required for
   the cross-branch git operations later in the job).
2. Docker Buildx setup, GHCR login, Cosign install.
3. Compute tags via `docker/metadata-action`: long sha, the floating
   `tag_channel` value, and a date+run-number tag.
4. Build a single-platform (`linux/amd64`) image, loaded locally (not
   pushed) — this is the artifact Trivy scans.
5. **Trivy scan, twice**: once as JSON (parsed for the summary/findings
   file), once as SARIF (uploaded to the Security tab). Both run with
   `exit-code: '0'` — **scans never fail the build**, by design (see
   "Non-blocking security scanning" below).
6. Count vulnerabilities, write a job summary, upload SARIF.
7. Generate/sync `security-findings.md` (see "security-findings.md
   mechanism" below) — opens (or refreshes) a PR carrying the file into
   `inputs.ref`, and a second PR carrying an identical copy into the
   counterpart branch, auto-merging both once `build_check` passes.
8. Build and push the real multi-arch(-capable) image with the computed
   tags.
9. Sign the pushed digest with Cosign (keyless OIDC).

**Non-blocking security scanning.** Both Trivy steps use `exit-code: '0'`
and `ignore-unfixed: true`. This is deliberate, not an oversight: findings
are documented (SARIF, job summary, `security-findings.md`) but never block
a publish. Each new build carries whatever upstream fixes exist at build
time; anything still outstanding is tracked in `security-findings.md` for a
future build to address.

**`security-findings.md` mechanism.** The file holds two marked sections —
`<!-- SECTION:DEVELOPMENT:... -->` and `<!-- SECTION:PRODUCTION:... -->`.
Each build only ever *regenerates its own section*, reads the *other*
branch's current section verbatim, composes the same combined file, and
pushes that identical file to **both** branches. This keeps `development`
and `master` byte-identical for this one file, so promoting `development` →
`master` never produces a merge conflict on it.

**PR-based sync mechanism (current).** Both the "sync into own branch" and
"sync into counterpart branch" steps push to a *stable, reused* branch name
(`bot/security-findings-sync-<target-branch>`, force-pushed each run — not a
fresh branch per run), open a PR from it if one isn't already open, and call
`gh pr merge --auto --squash`. GitHub merges the PR itself the moment
`build_check` passes; nothing about this step is required-check-aware beyond
that.

**Why this replaced the earlier direct-push approach.** An earlier version
committed straight to `inputs.ref` and the counterpart branch with raw git
(fetch → hard-reset → commit → push, retrying up to 5 times with backoff on
a rejected push). That worked fine as long as neither branch had protection
blocking direct pushes — but once `development` gained a required
`build_check` status check, every one of those direct pushes was rejected
outright with `GH006: Required status check "build_check" is expected`, and
no amount of retrying fixes "you're not allowed to push here without a
passing check that can't run on a plain push." Retrying was only ever a
mitigation for *races* between overlapping Development/Production runs
(see the shared `concurrency.group` note in the Development workflow's
section above), not for *protected-branch rejection* — those are different
failure modes, and only the PR-based flow described above solves the
second one. The shared concurrency group still matters and hasn't changed:
it's still what prevents two overlapping runs from generating conflicting
`security-findings.md` sync PRs against the same branch at once.

**Loop prevention — read this before changing commit messages.** This is
the part most likely to regress silently, so the reasoning is spelled out
here in full:
- The bot's commit *on the sync branch* (`bot/security-findings-sync-*`)
  deliberately has **no** `[skip ci]`. It needs `pr-validation.yml` to run
  on it so the PR can earn a passing `build_check` and become eligible for
  auto-merge. If you add `[skip ci]` here, the PR will sit open forever,
  unable to satisfy its own required check — a permanently stuck PR that
  needs manual intervention to close.
- The **squash-merge commit** that actually lands on `development`/`master`
  is given `[skip ci]` explicitly, via `--subject` on `gh pr merge --auto`.
  That merge is a `push` event, and `docker-build-publish-development.yml`
  listens for exactly that — without `[skip ci]` on the merge commit, that
  push would re-trigger the full build/publish pipeline, which would
  generate another `security-findings.md` update, open another PR, merge
  again, and repeat indefinitely.
- In short: the *source* commit needs CI to run (to pass the required
  check); the *merge* commit must not re-trigger CI (to avoid the loop).
  These are two different commits with two different messages by design —
  don't collapse them into one `[skip ci]` message, and don't remove
  `[skip ci]` from the merge subject to "simplify" it.

**Maintenance notes / gotchas.**
- Requires "Allow auto-merge" enabled in Settings → General — without it,
  `gh pr merge --auto` fails outright rather than queuing the merge.
  "Automatically delete head branches" is not strictly required (the branch
  name is reused/force-pushed either way) but keeps the branch list tidy.
- Each step checks for an already-open PR from its sync branch
  (`gh pr list --head ... --state open`) before creating a new one, so
  re-runs of the workflow update the existing PR rather than opening
  duplicates.
- `git worktree add` is still used for the counterpart-branch write so the
  job doesn't have to fully re-checkout and lose its build state. If this
  step is ever refactored, keep the worktree (or an equivalent isolated
  checkout) rather than switching the primary checkout mid-job.
- If `pr-validation.yml`'s job id or workflow name ever changes, remember
  this affects the sync PRs' ability to merge too, not just Dependabot's —
  see the note in that workflow's section.
- The multi-platform build step is currently `linux/amd64` only. If
  arm64 support is added later, the *scanning* build step must stay
  single-platform + `load: true` (Buildx can't `--load` multi-platform
  images) — don't try to make the scan step multi-arch too.

---

## Open recommendations (not yet implemented)

- **Promotion automation**: nothing currently merges `development` into
  `master`. Today that's a manual PR/merge. Consider an automated PR (e.g.
  after N successful Development runs, or on a schedule) to close this gap,
  or explicitly document it as an intentional manual gate.
- ~~**Branch protection on `master`**: if added, the git-write steps in the
  reusable workflow will need to move to a PR-based flow.~~ **Done** —
  `development` now requires `build_check`, and the reusable workflow's
  `security-findings.md` sync has been moved to the PR-based flow described
  in that workflow's section. If/when `master` gains the same protection,
  no further change is needed there — the same mechanism already targets
  either branch via `inputs.ref` / the counterpart branch.
- **Multi-arch builds**: add `linux/arm64` to the final push step if you
  need Raspberry Pi / Apple Silicon host support; keep the scan step
  single-platform as noted above.
- **Package/tag retention**: every build now publishes a permanent
  date+run-number tag in addition to `dev`/`latest`/sha tags — consider a
  GHCR retention policy to avoid unbounded tag growth over time.