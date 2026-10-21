"""Structural STDD gate, separate from business correctness and user approvals."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import yaml

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        raise SystemExit("STDD check failed: " + message)


manifest = json.loads((ROOT / ".stdd/upstream.json").read_text())
for name, digest in manifest["runtimeSHA256"].items():
    path = ROOT / ".stdd/vendor" / name
    require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest,
            "vendored source mismatch: " + name)
configs = {}
for path in sorted((ROOT / ".stdd/config.d").glob("*.yaml")):
    data = yaml.safe_load(path.read_text())
    require(isinstance(data, dict), "invalid config: " + path.name)
    configs.update(data)
require(configs["project"]["language"] == "swift", "expected Swift configuration")
require(configs["stdd_version"] == manifest["version"], "pinned version drift")
require(configs.get("enforce_stdd") is True, "STDD must be enabled")
require(configs["quality"]["test"] == "./scripts/check.sh", "test command drift")
require(not configs["community"]["registries"], "community publication is opt-in")
for gate in ("phase1_understand", "phase2_spec", "phase3_build"):
    require(configs["gates"][gate]["required"] is True, "required Gate missing: " + gate)
for mode in configs["scaling"].values():
    require(mode["spec"]["gate2"] == "mandatory", "mode bypasses Gate 2")
require("STDD_CONSTITUTION.md" in (ROOT / "AGENTS.md").read_text(), "agent entry missing")
require((ROOT / ".agents/skills").resolve() == (ROOT / ".codex/skills").resolve(),
        "Codex skill discovery link missing")
for phase in ("understand", "spec", "build", "deliver", "upgrade"):
    text = (ROOT / f".agents/skills/stdd-{phase}/SKILL.md").read_text()
    require(text.startswith("---\n"), "skill frontmatter missing")
    require("STDD_CONSTITUTION.md" in text, "project adapter pointer missing")
for name in ("confirm-gate", "mode-selection", "long-range-auth", "version-check"):
    require((ROOT / f".stdd/skills/_shared/{name}.md").is_file(), "shared skill missing")
active = 0
for state_path in (ROOT / ".stdd/changes").glob("*/.stdd.yaml"):
    state = yaml.safe_load(state_path.read_text())
    require(isinstance(state, dict), "invalid change state")
    if state.get("status") != "active":
        continue
    active += 1
    phase = state.get("current_phase")
    require(phase in ("understand", "spec", "build", "deliver"), "invalid phase")
    # A newly created Understand draft intentionally has no approved proposal yet.
    if phase != "understand":
        subprocess.run([sys.executable, str(ROOT / "scripts/stdd_cli.py"), "validate", state_path.parent.name],
                       cwd=ROOT, check=True)
    if phase in ("build", "deliver"):
        phases = state.get("phases", {})
        for previous in ("understand", "spec"):
            require(phases.get(previous, {}).get("confirmed_at"), "missing Gate evidence: " + previous)
    if phase == "deliver":
        require(state.get("phases", {}).get("build", {}).get("confirmed_at"), "missing Gate 3 evidence")
print(f"STDD source/config/skills passed; {active} active changes. Historical baseline is not retroactively certified.")
