# Session Log — pandas-dev/pandas#71819

> **Agent disclosure:** This log and everything in it was written by an AI agent.
> - Harness: Claude Code (Claude desktop app, Code tab)
> - Model: Claude Opus 5.5 (`claude-opus-5-5`)
> - Reasoning effort: low
> - Date: 2026-11-08
> - User: Peyton Laudanski (GitHub: `Eagle-Scout`, git user `BornZhenXjell`)
> - Repository: `Eagle-Scout/pandas` (fork of `pandas-dev/pandas`), local checkout `pandas-eaglescout`
>
> Under pandas' automated contributions policy
> (`doc/source/development/contributing.rst`, lines 22–50), any text from this
> file that you quote in an issue or PR must be marked with `>` or a code fence,
> and the PR must say which AI tool was used. The agent took no GitHub actions
> (no pushes, comments, issues or PRs). It only read data with `git fetch` and `gh … view/list`.
>
> This file is local only. It is listed in `.git/info/exclude`, so it can't be
> committed to your PR branch by accident.

---

## Part 1 — Session log

### Exchange 1: "Which issue was I assigned?"
**User:** They were accepted to resolve an issue related to #71819 and weren't sure the agent could see it.

**Agent actions:**
- `git remote -v` → `origin` = `Eagle-Scout/pandas`, `upstream` = `pandas-dev/pandas`.
- `gh issue view 71819 --repo pandas-dev/pandas` (read-only).

**Findings:**
- Title: *"ENH: DataFrame.merge raises bare KeyError without saying which DataFrame is missing the key column"*
- Opened 2026-11-01 by `murainah`. Labels: **Reshaping** and **Error Reporting**. State: open.
- Assignee: **Eagle-Scout** (claimed with a `/take` comment). Two other users had proposed the same approach earlier.
- Local repo: clean `main`, no feature branch, no work started.

### Exchange 2: "Is my fork up to date, and would my fix break anything in the future?"
**Agent actions:** `git fetch upstream main`, `git fetch origin main`, `git rev-list --left-right --count`, and
`gh pr list --search 71819` (read-only). Grepped the tests and source for code that depends on the current `KeyError`.

**Findings:**
- Local `main` is **13 commits behind** `upstream/main`. The fork on GitHub (`origin/main`) is **5 behind**. Neither has extra commits, so syncing is a fast-forward.
- None of the missing commits touch `merge.py`, `generic.py` or the merge tests.
- No PRs on pandas-dev/pandas mention #71819, so nothing competes with this work.
- Only one test checks the exact current message: `pandas/tests/reshape/merge/test_join.py:143`.
- Risks noted: index level names are also valid keys, so don't catch `ValueError`, use `raise … from err`,
  there are 5 call sites, wide frames can make the message very long, column names may not be strings,
  and the existing wording precedent is at `merge.py:633`.

### Exchange 3: "Give me a plan, and log this session to LOG.md"
**Agent actions:** Read `generic.py` (`_get_label_or_level_values`), the `_get_merge_keys` callers, the
`DataFrame.join`/`merge` entry points, the test file layout, the whatsnew sections and the pixi tasks. Wrote this file.

**Environment note:** `python`, `pixi` and `conda` were **not found** on this machine's PATH,
so pandas could not be built or imported. The bug was confirmed by reading the code, not by running it.
Set up a dev environment (Step 0 below) before you work on the fix.

### Exchange 4: "I ran the sync, run the fixes for merge.py, test_join.py and test_merge.py, and tell me how to test them"
**Agent actions:**
- Confirmed the sync: local `main`, `origin/main` and `upstream/main` all at `f1a97d356d`.
- Created branch `enh-merge-keyerror-side-71819` from the synced `main`.
- **`pandas/core/reshape/merge.py`:**
  - Imported `is_hashable`.
  - Added `_MergeOperation._get_merge_key_values(side, key, shared=False)`. It calls
    `_get_label_or_level_values`, catches only `KeyError`, and raises it again with `from err`. The message names the side
    and lists the available columns, plus named index levels if there are any. With `shared=True` (the `on=` case),
    a key missing from both frames is reported as "not found in left or right DataFrame". Keys that
    aren't hashable (wrong-length arrays) keep the original error.
  - Added module-level `_describe_merge_key_options(obj)`, which builds the "columns: […], index levels: […]" text.
  - Replaced all 5 direct `_get_label_or_level_values` calls in `_get_merge_keys` with the helper.
  - Exception type is still `KeyError`. `generic.py` is unchanged.
- **`pandas/tests/reshape/merge/test_join.py`:** the `join(on="E")` test now expects
  `'E' not found in left DataFrame. Available columns: ['A', 'B', 'C', 'D']`. Also fixed the "p resent" typo in its comment.
- **`pandas/tests/reshape/merge/test_merge.py`:** added `TestMergeMissingKeyError`, which covers:
  `on=` missing right / left / both, typos in `left_on` and `right_on`, `left_on` + `right_index`,
  `left_index` + `right_on`, a chained `__cause__`, index level names in the message, and integer column labels.
- Grepped `pandas/tests` for other tests expecting a `KeyError` from merge or join. None depend on the old message.
  The `merge_ordered` `left_by` test raises before `_get_merge_keys` and is unaffected.

**Example messages:**
```
KeyError: "'customer_id' not found in right DataFrame. Available columns: ['id', 'name']"
KeyError: "'zzz' not found in left or right DataFrame. Left columns: ['customer_id', 'amount']. Right columns: ['id', 'name']"
KeyError: "'zzz' not found in left DataFrame. Available columns: ['a'], index levels: ['lvl']"
```

**Verification status:** **NOT RUN.** The three files were only checked for valid Python syntax (`ast.parse`).
This machine has `python3` 3.14 but no Cython or meson-python, and no pixi or conda, so pandas can't be built and
the tests weren't run. The user has to build and run them (see Part 2, Step 5).

**Still to do (not requested this turn):** release note in `doc/source/whatsnew/v3.2.0.rst`; decide whether to shorten
column lists for very wide frames; run `pre-commit`; commit.

### Exchange 5: "What would a draft for the whatsnew update be?"
**Agent actions:** Read the existing "Other enhancements" entries in `doc/source/whatsnew/v3.2.0.rst` to match their style.
Offered a longer draft and a shorter alternative. Didn't edit anything.

### Exchange 6: "Add it with the more verbose draft"
**Agent actions:** Added this entry as the first item under **Other enhancements** in
`doc/source/whatsnew/v3.2.0.rst`. It sorts before the `:func:`numpy.delete`` entry:
```rst
- :func:`merge`, :meth:`DataFrame.merge` and :meth:`DataFrame.join` now raise a more informative ``KeyError`` when a key passed to ``on``, ``left_on`` or ``right_on`` is missing, saying whether the left DataFrame, the right DataFrame or both are missing it and listing the available columns and index levels (:issue:`71819`)
```
**Verification:** ran the repo's own pre-commit sort check, `python3 -m scripts.sort_whatsnew_note doc/source/whatsnew/v3.2.0.rst`.
It exited 0 and didn't reorder anything, so the entry is in the correct sorted position.

**Remaining:** build pandas and run the tests (still **not run**), run the full `pre-commit`, review the diff, commit.

### Exchange 7: Pixi install, build and first test run
- The user installed Pixi (`~/.pixi/bin`). Their terminal hadn't reloaded `~/.zshrc`, so `pixi` wasn't found
  there. The agent ran the build with the full path: `~/.pixi/bin/pixi run -e py313 build-pandas --editable`.
  It finished with `Successfully installed pandas-3.2.0.dev0+560.gf1a97d356d.dirty` (exit 0).
- **Agent test run:**
  - `pytest pandas/tests/reshape/merge/test_merge.py -k MissingKeyError -v` → **9 passed**
  - `pytest pandas/tests/reshape/merge/test_join.py -k test_join_on -v` → **15 passed** (includes the updated `join(on="E")` check)
- **User test run** (in their own terminal): `pixi run -e py313 pytest pandas/tests/reshape/merge/test_merge.py -k MissingKeyError -v`
  → **9 passed, 1009 deselected**.
- The agent started the full suite (`pandas/tests/reshape`, `pandas/tests/frame/methods/test_join.py`,
  `pandas/tests/series/methods`), but the user stopped it. **The full suite and `pre-commit` have not been run.**

### Exchange 8: Full reshape/join suite (run by the user)
- **User ran:** `pixi run -e py313 pytest pandas/tests/reshape pandas/tests/frame/methods/test_join.py -n 4 -m "not slow and not network and not db and not single_cpu"`
- **Result:** **3062 passed, 17 skipped, 6 xfailed in 28.05s**, with **0 failures and 0 errors**.
- The skips and xfails come from markers already in the test suite, not from this change. Nothing outside the
  updated test depended on the old bare `KeyError` message.
- **Still not run:** `pre-commit` on the changed files. Nothing is committed yet.

### Exchange 9: "Run pre-commit"
- `pixi run -e py313 pre-commit …` failed with `pre-commit: command not found`, because in `pixi.toml` pre-commit is only in the
  `typing` environment. The agent ran `~/.pixi/bin/pixi exec pre-commit run --files <the 4 changed files>` instead.
- **First run:** every hook passed except **`ruff format`**, which reformatted `pandas/tests/reshape/merge/test_merge.py`.
  It joined two pairs of split strings in the new test parameters onto single lines because they fit in the line limit.
  The tests are otherwise unchanged.
- **Second run:** **all hooks passed** (exit 0). That includes ruff check/format, vulture, codespell, isort, Sphinx Lint,
  the rst checks, "Unwanted patterns", the private-function checks and "sort whatsnew entries alphabetically".
- After the reformat, `pytest pandas/tests/reshape/merge/test_merge.py -k MissingKeyError` still gives **9 passed**.
- **Status:** the code, tests, release note, full reshape/join suite (user's run: 3062 passed, 0 failed) and pre-commit are all done.
  **Not done:** mypy (`ci-typing`) wasn't run. Nothing is committed or pushed.

---

## Part 2 — Plan

### Step 0 — Get set up
1. Sync your fork:
   ```bash
   git checkout main
   git pull --ff-only upstream main
   git push origin main
   ```
2. Create a branch:
   ```bash
   git checkout -b enh-merge-keyerror-side-71819
   ```
3. Install a dev environment. pandas CI uses Pixi (see `doc/source/development/contributing_environment.rst`, around line 179):
   ```bash
   pixi run -e py313 build-pandas --editable
   ```
   You can also use conda with `environment.yml`.
4. Install the pre-commit hooks (`pre-commit install`) so linting runs on every commit.

### Step 1 — Understand the issue (reproduce it)
```python
import pandas as pd
orders = pd.DataFrame({"customer_id": [1, 2, 3], "amount": [10, 20, 30]})
customers = pd.DataFrame({"id": [1, 2, 3], "name": ["A", "B", "C"]})
orders.merge(customers, on="customer_id")   # KeyError: 'customer_id'
```
The problem: with `on=`, the key must be present in **both** frames. The error names the key
but not **which side** is missing it, so the user has to inspect both frames themselves.
Also try `on="id"` (missing on the left), `on="zzz"` (missing on both), a typo in `left_on`, a typo in `right_on`,
and `df.join(other, on="missing")`.

### Step 2 — Understand the cause (call path)
```
DataFrame.merge                    pandas/core/frame.py:16037  → merge() at :16266
DataFrame.join(on=...)             pandas/core/frame.py:15750  → merge() at :15965/:15974/:16025
  └─ merge()                       pandas/core/reshape/merge.py:155
      └─ _MergeOperation.__init__  pandas/core/reshape/merge.py:960
          └─ self._get_merge_keys()          merge.py:1017
              └─ _get_merge_keys()           merge.py:1573
                  └─ left/right._get_label_or_level_values(key)
                       lookups at merge.py:1625, 1637, 1650, 1667, 1687
                      └─ NDFrame._get_label_or_level_values   pandas/core/generic.py (~1698)
                           raise KeyError(key)                generic.py:1743   ← bare error comes from here
```
`_get_label_or_level_values` is a general helper that doesn't know about "left" or "right".
Only `_get_merge_keys` knows which frame it is looking at, so that's where the extra context belongs.
`_OrderedMerge` (merge.py:2355, used by `merge_ordered`) and `_AsOfMerge` (merge.py:2420, used by `merge_asof`)
inherit from `_MergeOperation`, so they get the improved message too.

**Don't** change `generic.py`. That helper is used in many places outside merge (groupby, sort_values, …),
and changing it would affect error messages across the library.

### Step 3 — The fix
In `pandas/core/reshape/merge.py`:
1. Add a small helper (a private method on `_MergeOperation` or a module-level function) that:
   - calls `obj._get_label_or_level_values(key)`
   - catches **only** `KeyError` (not the `ValueError` raised for ambiguous names)
   - raises it again as `KeyError(...)` **`from err`**, with a message naming the side and the available keys, for example:
     `"'customer_id' not found in right DataFrame. Available columns: ['id', 'name']"`
2. Replace the 5 direct calls (lines 1625, 1637, 1650, 1667, 1687) with this helper, passing `"left"` or `"right"`.
3. Edge cases to handle:
   - **Index level names are valid keys.** Mention them in the message as well
     (for example "columns or index levels"), or the message will be misleading.
     See `pandas/tests/reshape/merge/test_merge_index_as_string.py`.
   - **Column names that aren't strings** (ints, tuples from MultiIndex columns): use `repr()` / `!r`.
   - **Very wide frames:** consider shortening long column lists.
   - **Consistency:** the existing message at `merge.py:633` is `f"{check} not found in left columns"`.
     Use similar wording.
4. Keep the exception type as **`KeyError`**. Changing it (for example to `MergeError`) would be an API change and break
   user code that catches `KeyError`.

**Missing on both sides (`on="zzz"`):** the code checks the right frame before the left in the `on=` path
(see lines 1637 → 1650), so as written, only the right side would be reported. Decide whether to report
both sides (check both before raising) or only the first one found. Reviewers may ask about this either way.

### Step 4 — Files to change
| File | Change |
|---|---|
| `pandas/core/reshape/merge.py` | New helper + replace 5 lookups in `_get_merge_keys` |
| `pandas/tests/reshape/merge/test_join.py:143` | Update `match="^'E'$"` to the new message |
| `pandas/tests/reshape/merge/test_merge.py` | New tests for `on`, `left_on`, `right_on` (left / right / both missing) |
| `doc/source/whatsnew/v3.2.0.rst` | Release note under **Other enhancements** (line 29), referencing `:issue:\`71819\`` |

Not changing: `pandas/core/generic.py` (shared helper), `pandas/core/frame.py` (only passes calls through).

### Step 5 — Testing
You're right about `test_join.py`, but it only covers part of this. The main new tests belong in `test_merge.py`.

**Existing test to update:**
- `pandas/tests/reshape/merge/test_join.py:143`: `target.join(source, on="E")` currently expects `match="^'E'$"`.
  Update it to match the new message. This also covers the `DataFrame.join(on=...)` path.

**New tests** (in `test_merge.py`, use `pytest.mark.parametrize`, and add a `# GH#71819` comment):
- `on=` key missing from the right → message says "right"
- `on=` key missing from the left → message says "left"
- `on=` key missing from both → whatever behaviour you chose in Step 3
- typo in `left_on=` → "left"; typo in `right_on=` → "right"
- the message lists the available column names
- the exception is still a `KeyError` (`pytest.raises(KeyError, match=...)`)
- optional: a `merge_asof` / `merge_ordered` case with a missing key

**Run them:**
```bash
pytest pandas/tests/reshape/merge/test_merge.py -k 71819 -v
pytest pandas/tests/reshape/merge/test_join.py
pytest pandas/tests/reshape/merge/          # full merge suite, catches regressions
pytest pandas/tests/frame/methods/test_join.py
pre-commit run --files pandas/core/reshape/merge.py pandas/tests/reshape/merge/test_merge.py pandas/tests/reshape/merge/test_join.py doc/source/whatsnew/v3.2.0.rst
```
Or with pixi: `pixi run -e py313 ci-test-pandas "-m not single_cpu" auto pandas/tests/reshape/merge`.

**What a passing result means:** your new tests pass, the updated `test_join.py` test passes,
and **no other** merge, join or reshape test fails. Other failures would mean another test
depended on the old bare message.

### Step 6 — Before opening the PR (you do this yourself, not the agent)
- Read the diff yourself. The policy requires you to review and change any agent-generated code.
- In the PR description, write `closes #71819`, disclose the AI tool (Claude Code, Claude Opus 5.5, low reasoning effort),
  and mark any quoted agent text with `>` or a code fence.
- Write review replies yourself, not with an AI.
