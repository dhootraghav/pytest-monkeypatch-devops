# Viva quick reference

## Three-minute presentation

Our project fixes pytest issue #14909 in the `MonkeyPatch` fixture helper. `MonkeyPatch` temporarily changes attributes and mappings during a test, then reverses those changes at teardown. We found that `delattr`, `setitem`, and `delitem` saved an undo instruction before attempting the change. If Python rejected the change, for example because a mapping was read-only, the original error was correctly raised, but teardown later tried to undo a change that never happened and raised a second error.

We changed only the ordering: save the old value, attempt the mutation, and record the undo action after it succeeds. This preserves successful behavior and makes failed operations leave no state behind. Three regression tests use real immutable Python objects and the normal fixture lifecycle, so they prove both the failure path and clean teardown.

For DevOps, the repository uses a focused GitHub Actions workflow across Python 3.10 and 3.13. It runs Ruff linting, the tests, `pip-audit`, and a Docker build/run. The Docker image uses a slim Python base, a non-root user, and has no network port because pytest is a library rather than a service. Our proof is reproducible locally, in CI, and in a container.

## Likely questions and short answers

1. **What was the bug?** Failed mutations created undo entries, causing a second teardown error.
2. **Where was it?** `src/_pytest/monkeypatch.py`, in `delattr`, `setitem`, and `delitem`.
3. **What caused it?** Undo state was recorded before the mutation outcome was known.
4. **Why is the second error harmful?** It obscures the real test failure and breaks teardown.
5. **What is the fix?** Append undo state only after the mutation succeeds.
6. **Why save the old value first?** It is needed to restore a successful mutation.
7. **How did you test it?** With an undeletable slotted object and immutable `MappingProxyType` mappings.
8. **How do tests prove teardown?** They use pytest's fixture; its automatic teardown runs after each test.
9. **Why not catch and ignore teardown errors?** That would hide real failures and retain invalid state.
10. **Why is this a regression test?** It fails on the old ordering and passes only with the fix.
11. **Why Docker?** It provides the same Python/test command on any machine.
12. **Why no exposed port?** pytest is not a network service.
13. **What is the container health signal?** A zero test-process exit code.
14. **Why run as non-root?** It reduces the impact of a compromised process.
15. **Why GitHub Actions?** It validates every push and pull request automatically.
16. **Why two Python versions?** The project supports multiple Python versions; the fix uses core semantics that should remain portable.
17. **What does Ruff do?** It checks code style and common static errors.
18. **What does pip-audit do?** It reports known vulnerabilities in installed dependencies.
19. **What happens if CI fails?** The change is not considered verified; fix or investigate before merge.
20. **What is a future improvement?** Run the complete upstream matrix and submit the focused patch as an upstream PR after maintainer review.
