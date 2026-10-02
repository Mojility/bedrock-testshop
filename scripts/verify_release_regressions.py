#!/usr/bin/env python3
"""Demonstrate rejection of broken readiness or CSS in a disposable real release.

Build the candidate with qualify_release.py first. This command must fail at the
named boundary; it deliberately propagates that failure for behavioral evidence.
No authored application source or original artifact is modified.
"""
import argparse
import os
from pathlib import Path
import shutil
import signal
import sys

sys.dont_write_bytecode = True
import qualify_callers as callers
import qualify_release as release_gate


def verify(args):
    with callers.disposable_snapshot(Path("/tmp")) as scratch:
        artifact = scratch / "release"
        shutil.copytree(args.release.resolve(), artifact)
        if args.case == "readiness":
            # Replace only this copy's readiness BEAM with an actual compiled
            # controller that incorrectly reports ready without querying SQL.
            source = (release_gate.ROOT / "lib/business_web/controllers/health_controller.ex").read_text()
            assert 'SQL.query(Business.Repo, "SELECT 1", [])' in source
            source = source.replace("  alias Ecto.Adapters.SQL\n", "")
            source = source.replace('SQL.query(Business.Repo, "SELECT 1", [])', "{:ok, :regression}")
            candidate = scratch / "health_controller.ex"
            candidate.write_text(source)
            target = next(artifact.glob("lib/business-*/ebin/Elixir.BusinessWeb.HealthController.beam"))
            env = dict(os.environ, ERL_FLAGS="+S 2:2", REGRESSION_SOURCE=str(candidate), REGRESSION_BEAM=str(target))
            expression = '''
            [{_, binary}] = Code.compile_file(System.fetch_env!("REGRESSION_SOURCE"))
            File.write!(System.fetch_env!("REGRESSION_BEAM"), binary)
            '''
            release_gate.run(["elixir", "-pa", str(artifact / "lib/*/ebin"), "-e", expression],
                             release_gate.ROOT, env)
            options = ["--proof"]
            print("Disposable regression: readiness skips its database query", flush=True)
        else:
            styles = list(artifact.glob("lib/business-*/priv/static/assets/**/*.css"))
            assert styles, "Build deployed CSS before the regression experiment"
            for style in styles:
                style.write_text("")
                for suffix in (".gz", ".br"):
                    Path(str(style) + suffix).unlink(missing_ok=True)
            options = []
            print("Disposable regression: deployed CSS is empty over HTTP", flush=True)
        release_gate.run([sys.executable, str(release_gate.ROOT / "scripts/qualify_release.py"),
                          "--release", str(artifact), *options], release_gate.ROOT, os.environ.copy())
        raise AssertionError("Release gate accepted a deliberate regression")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, required=True)
    parser.add_argument("--case", choices=["readiness", "smoke"], required=True)
    for number in (signal.SIGINT, signal.SIGTERM):
        signal.signal(number, callers.interrupted)
    verify(parser.parse_args())
