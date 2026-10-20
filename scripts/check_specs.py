from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
required = ["AGENTS.md", "specs/README.md", "specs/001-product.md", "specs/002-scoring.md", "specs/003-health-and-sync.md", "docs/architecture.md", "docs/development.md"]
for name in required:
    assert (root / name).is_file(), f"Missing required document: {name}"
for name in required:
    content = (root / name).read_text()
    assert content.strip(), f"Empty document: {name}"
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", content):
        if "://" not in target and not target.startswith("#"):
            assert ((root / name).parent / target.split("#")[0]).exists(), f"Broken link in {name}: {target}"
for name in ["001-product.md", "002-scoring.md", "003-health-and-sync.md"]:
    content = (root / "specs" / name).read_text()
    assert "## 验收标准" in content, f"Missing acceptance criteria: {name}"
print("Spec structure and local links passed")
