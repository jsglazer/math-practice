# verify_templates — the offline SymPy gate

Build-time only. Never shipped, never a test dependency. `swift test` passes on a machine
with no Python installed, because the only thing this tool leaves behind is a checked-in
JSON fixture.

## What it guarantees

Every problem template states its own derivative in closed form — there is no CAS in the
app. This gate is what proves those closed forms right: it differentiates each generated
problem with SymPy and refuses to write the fixture unless the template's stated answer
matches, and unless the last stated step of the worked solution lands on that same answer.

## Running it

```sh
python3 -m venv Tools/verify_templates/.venv
Tools/verify_templates/.venv/bin/pip install -r Tools/verify_templates/requirements.txt
Tools/verify_templates/.venv/bin/python Tools/verify_templates/verify_templates.py
```

`--check` verifies without writing. The venv is git-ignored.

## Regenerating goldens

Changing a template, its difficulty band, or the golden seeds changes the fixture. Re-run
this tool to regenerate `Tests/MathPracticeCoreTests/Golden/templates.json`. **Never edit
that file by hand** — a hand-edited golden is an unverified golden.
