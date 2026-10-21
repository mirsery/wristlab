"""Project-local adapter; upstream runtime is unmodified and pinned in upstream.json."""
from pathlib import Path
import argparse
import sys
import runpy

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / ".stdd/vendor"))
from stdd.cli import utils
from stdd.cli.commands import init, guard, upgrade

utils.STDD_SOURCE = ROOT
upgrade._registry_path = lambda: ROOT / "work/stdd-projects.yaml"


def project_guard(project_root):
    guard.cmd_guard_init(argparse.Namespace(platform="codex"))


init._post_init_guard = project_guard
init._post_init_experiences = lambda *_: print("  Wristlab: community downloads are explicit; no automatic pull.")
init._post_init_self_check = lambda *_: print("  Wristlab: run ./scripts/stdd --project-check; Codex uses AGENTS.md, not Claude hooks.")

# Publishing and live upgrades need a separate, reviewed action. An init request
# does not authorize sending experiences to an upstream community repository.
args = sys.argv[1:]
if args == ["--project-check"]:
    runpy.run_path(str(ROOT / "scripts/check_stdd.py"), run_name="__main__")
    raise SystemExit(0)
if args and (args[0] == "upgrade" or (args[0] == "experience" and "share" in args)
             or (args[0] == "knowledge" and any(x in args for x in ("push", "sync", "share")))):
    raise SystemExit("Wristlab: automatic publication/upgrade is disabled; use a separately reviewed change.")

from stdd.cli import main
main()

if args == ["install", "codex"]:
    for path in (ROOT / ".codex/skills").glob("*/SKILL.md"):
        text = path.read_text()
        parts = text.split("---", 4)
        if len(parts) == 5 and not parts[2].strip():
            text = "---" + parts[1] + "---" + parts[4]
        header_end = text.find("---", 3) + 3
        text = (text[:header_end] + "\n\nBefore executing this skill, read STDD_CONSTITUTION.md and docs/stdd.md. "
                "Use ./scripts/stdd for CLI commands; keep experiences local.\n" + text[header_end:])
        path.write_text(text)
