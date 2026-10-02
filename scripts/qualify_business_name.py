#!/usr/bin/env python3
"""Prove encoded names and legacy overrides using disposable source and real HTTP.

Run --characterize before the change, --reject-substitution to demonstrate the
old producer defect, and without flags to qualify the JSON consumer contract.
No customer source, records or mail are used. Logs remain outside the repository.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import sys

sys.dont_write_bytecode = True

from qualify_callers import disposable_snapshot, interrupted, output, run, snapshot

ROOT = Path(__file__).resolve().parents[1]
HOSTILE = 'Électricité "北" \\ #{raise "NAME WAS EVALUATED"} <&>\''


def qualify(args):
    env = {key: value for key, value in os.environ.items()
           if key not in ("BUSINESS_NAME", "SHOP_NAME", "PHX_SERVER")}
    suffix = "_name_" + secrets.token_hex(8)
    env.update(MIX_ENV="test", MIX_TEST_PARTITION=suffix, ERL_FLAGS="+S 4:4")
    with disposable_snapshot(None) as app:
        if args.source_revision:
            archive = output(["git", "archive", args.source_revision], cwd=ROOT)
            output(["tar", "-x", "-C", str(app)], input=archive)
            for relative in ("scripts/business_name_probe.exs",):
                shutil.copy2(ROOT / relative, app / relative)
            print("Committed source:", args.source_revision, flush=True)
        else:
            snapshot(app)
        for directory in ("deps", "_build"):
            if (ROOT / directory).exists():
                shutil.copytree(ROOT / directory, app / directory, symlinks=True,
                                dirs_exist_ok=True)
        if args.reject_substitution:
            for relative in ("config/config.exs", "lib/business_web/components/layouts/root.html.heex"):
                path = app / relative
                path.write_text(path.read_text().replace("{{BUSINESS_NAME}}", HOSTILE))
            run(["mix", "format", "--check-formatted"], app, env)
            raise AssertionError("Unsafe source substitution unexpectedly passed")
        # A real generated legacy system: baked configuration and no JSON file.
        config = app / "config/config.exs"
        config.write_text(config.read_text() + '\nconfig :business, :business_name, "Legacy Electric"\n')
        data = app / "priv/business.json"
        data.unlink(missing_ok=True)
        if args.characterize:
            layout = app / "lib/business_web/components/layouts/root.html.heex"
            layout.write_text(layout.read_text().replace("{{BUSINESS_NAME}}", "Legacy Electric"))
        cases = [("legacy", None, {}, "Legacy Electric"),
                 ("legacy-shop", None, {"SHOP_NAME": "Old override"}, "Old override"),
                 ("legacy-business", None, {"BUSINESS_NAME": "New override"}, "New override"),
                 ("legacy-both", None, {"BUSINESS_NAME": "New override", "SHOP_NAME": "Old override"}, "New override"),
                 ("legacy-empty", None, {"BUSINESS_NAME": "", "SHOP_NAME": "Old override"}, "")]
        if not args.characterize:
            boundary_name = HOSTILE + "界" * (120 - len(HOSTILE))
            cases += [("encoded", HOSTILE, {}, HOSTILE),
                      ("63-characters", "N" * 63, {}, "N" * 63),
                      ("120-characters", boundary_name, {}, boundary_name),
                      ("data-shop", HOSTILE, {"SHOP_NAME": "Old override"}, "Old override"),
                      ("data-business", HOSTILE, {"BUSINESS_NAME": HOSTILE}, HOSTILE),
                      ("data-both", HOSTILE, {"BUSINESS_NAME": "New override", "SHOP_NAME": "Old override"}, "New override"),
                      ("data-empty-business", HOSTILE, {"BUSINESS_NAME": "", "SHOP_NAME": "Old override"}, ""),
                      ("data-empty-shop", HOSTILE, {"SHOP_NAME": ""}, "")]
        run(["mix", "format", "--check-formatted"], app, env)
        run(["mix", "compile", "--warnings-as-errors"], app, env)
        try:
            run(["mix", "ecto.create", "--quiet"], app, env)
            run(["mix", "ecto.migrate", "--quiet"], app, env)
            with open("/tmp/bedrock-port-4000.lock", "a") as lock:
                if args.port == 4000:
                    fcntl.flock(lock, fcntl.LOCK_EX)
                for label, name, overrides, expected in cases:
                    if name is None:
                        data.unlink(missing_ok=True)
                    else:
                        data.write_text(json.dumps({"name": name}, ensure_ascii=False) + "\n")
                    case_env = dict(env, **overrides, NAME_EXPECTED=expected, NAME_PORT=str(args.port),
                                    NAME_TITLE_EXPECTED="Legacy Electric" if args.characterize else expected)
                    print("Case:", label, flush=True)
                    if name is not None:
                        run(["mix", "format", "--check-formatted"], app, case_env)
                        run(["mix", "compile", "--warnings-as-errors"], app, case_env)
                    run(["mix", "run", "--no-start", "scripts/business_name_probe.exs"], app, case_env)
        finally:
            run(["dropdb", "--if-exists", "--force", "business_test" + suffix], app, env)
            print("Removed synthetic database business_test" + suffix, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--characterize", action="store_true")
    parser.add_argument("--reject-substitution", action="store_true")
    parser.add_argument("--source-revision", help="Committed starter baseline for characterization or rejection")
    parser.add_argument("--port", type=int, choices=(0, 4000), default=4000,
                        help="Use 0 for an isolated ephemeral HTTP listener")
    options = parser.parse_args()
    for number in (signal.SIGINT, signal.SIGTERM):
        signal.signal(number, interrupted)
    qualify(options)
