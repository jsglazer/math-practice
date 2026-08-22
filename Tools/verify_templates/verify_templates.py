#!/usr/bin/env python3
"""Offline SymPy gate for the MathPractice problem templates.

Build-time only. This script is never shipped, is never a test dependency, and
``swift test`` must pass on a machine with no Python installed.

What it does:

1. runs ``swift run TemplateDump`` to get every template's problem/answer/step triples
   for the fixed golden seeds;
2. re-derives each problem with SymPy and refuses to continue unless the template's
   stated answer is symbolically equal to it;
3. only then writes ``Tests/MathPracticeCoreTests/Golden/templates.json``.

The Swift test suite asserts the generators still reproduce that file exactly, so a
template can only change if this gate is re-run. Goldens are never edited by hand.

Usage:
    Tools/verify_templates/.venv/bin/python Tools/verify_templates/verify_templates.py
    ... --check        verify only, do not write the fixture
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import sympy

REPO_ROOT = Path(__file__).resolve().parents[2]
GOLDEN_PATH = REPO_ROOT / "Tests" / "MathPracticeCoreTests" / "Golden" / "templates.json"

X = sympy.Symbol("x", real=True)

# The only names a canonical expression may use. Anything else is a schema violation.
NAMESPACE = {
    "x": X,
    "Rational": sympy.Rational,
    "sin": sympy.sin,
    "cos": sympy.cos,
    "tan": sympy.tan,
    "sec": sympy.sec,
    "csc": sympy.csc,
    "cot": sympy.cot,
    "log": sympy.log,
    "exp": sympy.exp,
    "sqrt": sympy.sqrt,
}


class VerificationError(Exception):
    """A record the gate refuses to bless."""


def parse(text: str, where: str):
    try:
        return sympy.sympify(text, locals=NAMESPACE, rational=True)
    except Exception as error:  # noqa: BLE001 - any parse failure is a hard stop
        raise VerificationError(f"{where}: cannot parse {text!r} ({error})") from error


def equivalent(left, right) -> bool:
    """Symbolic equality, with a numeric fallback for stubborn trig/radical forms."""
    difference = sympy.simplify(sympy.together(left - right))
    if difference == 0:
        return True
    difference = sympy.simplify(sympy.expand_trig(sympy.expand(difference)))
    if difference == 0:
        return True
    # A last resort: agree to 25 digits at several points that avoid the usual poles.
    for probe in (sympy.Rational(2, 7), sympy.Rational(3, 5), sympy.Rational(11, 4), sympy.Rational(9, 2)):
        try:
            value = complex(difference.subs(X, probe).evalf(25))
        except (TypeError, ValueError):
            return False
        if abs(value) > 1e-18:
            return False
    return True


def verify_record(record: dict, position: int) -> None:
    where = f"record {position} ({record.get('templateID')} d{record.get('difficulty')} seed {record.get('seed')})"

    for field in ("promptLatex", "answerLatex", "canonicalPrompt", "canonicalAnswer", "instruction"):
        if not str(record.get(field, "")).strip():
            raise VerificationError(f"{where}: '{field}' is empty")

    steps = record.get("steps") or []
    if len(steps) < 2:
        raise VerificationError(f"{where}: expected at least 2 solution steps, found {len(steps)}")
    for index, step in enumerate(steps):
        if not str(step.get("title", "")).strip() or not str(step.get("latex", "")).strip():
            raise VerificationError(f"{where}: step {index} missing title or LaTeX")

    problem = parse(record["canonicalPrompt"], f"{where} prompt")
    answer = parse(record["canonicalAnswer"], f"{where} answer")

    rule = record.get("verificationRule")
    if rule != "derivative":
        raise VerificationError(f"{where}: unsupported verification rule {rule!r}")

    derivative = sympy.diff(problem, X)
    if not equivalent(derivative, answer):
        raise VerificationError(
            f"{where}: d/dx[{record['canonicalPrompt']}] = {sympy.simplify(derivative)} "
            f"but the template says {sympy.simplify(answer)}"
        )

    # The last step that states an expression must land on the answer, or the reveal loop
    # would walk the user to something other than what it later shows them.
    stated = [step for step in steps if step.get("canonical")]
    if not stated:
        raise VerificationError(f"{where}: no step states an expression")
    final = parse(stated[-1]["canonical"], f"{where} final step")
    if not equivalent(final, answer):
        raise VerificationError(
            f"{where}: final step {sympy.simplify(final)} does not match the answer "
            f"{sympy.simplify(answer)}"
        )


def dump_templates() -> str:
    result = subprocess.run(
        ["swift", "run", "--package-path", str(REPO_ROOT), "TemplateDump"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"swift run TemplateDump failed with status {result.returncode}")
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify only, do not write the fixture")
    arguments = parser.parse_args()

    payload = dump_templates()
    fixture = json.loads(payload)

    records = fixture.get("records") or []
    if not records:
        raise SystemExit("template dump produced no records")

    failures: list[str] = []
    for position, record in enumerate(records):
        try:
            verify_record(record, position)
        except VerificationError as error:
            failures.append(str(error))

    templates = sorted({record["templateID"] for record in records})
    print(f"verified {len(records)} records across {len(templates)} templates")

    if failures:
        for failure in failures:
            print(f"  FAIL {failure}", file=sys.stderr)
        raise SystemExit(f"{len(failures)} record(s) failed the SymPy gate; fixture not written")

    if arguments.check:
        print("check only — fixture not written")
        return 0

    GOLDEN_PATH.parent.mkdir(parents=True, exist_ok=True)
    GOLDEN_PATH.write_text(payload)
    print(f"wrote {GOLDEN_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
