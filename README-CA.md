# pytest MonkeyPatch stale-undo fix (DevOps CA)

This repository is a focused, attributable contribution based on [pytest](https://github.com/pytest-dev/pytest). It fixes [pytest issue #14909](https://github.com/pytest-dev/pytest/issues/14909): a failed `MonkeyPatch.delattr`, `setitem`, or `delitem` mutation left an undo record for a mutation that never occurred.

## Problem statement

Fix stale undo entries in pytest's `MonkeyPatch` utility so that failed attribute or mapping mutations do not cause a secondary exception during fixture teardown.

Short sheet version: **pytest #14909 — prevent stale MonkeyPatch undo entries after failed mutations.**

## Root cause and solution

`MonkeyPatch` records each successful mutation so `undo()` can restore it at fixture teardown. Before this fix, three methods appended an undo record *before* mutating the target. Immutable mappings and undeletable attributes raise during the mutation, leaving the target unchanged but retaining an invalid record. Teardown then attempted a second, invalid mutation.

The fix is deliberately small: read the old value, perform the mutation, then append the undo record only if the mutation succeeded. The established `setattr` implementation already uses this ordering.

| Scenario | Before | After |
| --- | --- | --- |
| Failed mutation | stale undo record remains | no undo record is created |
| Fixture teardown | secondary error | clean teardown |
| Successful mutation | reversible | unchanged, still reversible |

## Architecture

`testing/test_monkeypatch.py` exercises the public `monkeypatch` fixture. The fixture owns a `MonkeyPatch` instance, whose methods are implemented in `src/_pytest/monkeypatch.py`; pytest invokes `undo()` during teardown. The three regression tests use `MappingProxyType` and a slotted object to force real Python mutation failures. They catch the primary exception, assert that the target is unchanged, and rely on fixture teardown to prove no stale undo operation exists.

## Local verification

Requires Python 3.10 or newer.

```bash
python -m venv .venv
export SETUPTOOLS_SCM_PRETEND_VERSION_FOR_PYTEST=9.2.0
.venv/bin/python -m pip install -e .
.venv/bin/python -m pytest testing/test_monkeypatch.py -q
```

Expected result: all focused tests pass, including the three `*_failure_does_not_corrupt_undo` regressions. Run the upstream test suite separately when contributing upstream.

## Container verification

This is a library/test-runner project, not a web service, so it exposes no ports or HTTP health endpoint. The container's test exit code is the health signal.

```bash
docker build -t pytest-issue-14909 .
docker run --rm pytest-issue-14909
```

The image uses `python:3.13-slim`, installs the local package, runs as a non-root `pytest` user, and executes the focused regression module by default. `.dockerignore` keeps build context small and excludes local environments and Git metadata.

## CI and security

`.github/workflows/ca-issue-14909.yml` runs on pushes, pull requests, and manually. It tests Python 3.10 and 3.13, lints only touched source/test files with Ruff, runs the focused regression module, scans installed dependencies with `pip-audit`, then builds and executes the Docker image. Minimal read-only GitHub token permissions are declared.

The upstream project already has a broader multi-platform CI suite in `.github/workflows/test.yml`; the CA workflow is a focused, readable verification pipeline for this issue.

## Evidence for the viva

To demonstrate the old defect, temporarily move each undo-record append above its mutation, run the focused module, and observe the test body catch the original `AttributeError`/`TypeError` but fixture teardown fail. Restore the fixed ordering and rerun: the module passes cleanly. Do not commit that temporary reversal.

## Team split

| Student | Deliverable |
| --- | --- |
| 1 | Issue analysis, root-cause explanation, and core fix |
| 2 | Regression, edge, and full-suite testing evidence |
| 3 | Docker image and GitHub Actions verification pipeline |
| 4 | Documentation, dependency-scan reporting, and viva demo |

## Attribution and licence

pytest is maintained by the pytest-dev community and is distributed under the [MIT License](LICENSE). This repository retains upstream licensing and is intended as an academic, focused contribution branch. Any upstream pull request should follow [pytest's contribution guide](CONTRIBUTING.rst).
