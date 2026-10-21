"""Validate specification structure and traceability, not algorithm correctness."""
from pathlib import Path
from urllib.parse import unquote, urlsplit
import hashlib
import json
import math
import re

root = Path(__file__).resolve().parents[1]
required = [
    'AGENTS.md', 'GLOSSARY.md', 'README.md', 'README.en.md', 'docs/validation.md',
    'docs/screenshots/README.md', 'docs/screenshots/manifest.json', 'specs/README.md',
    'specs/000-reference-behavior.md', 'specs/001-product.md',
    'specs/002-scoring.md', 'specs/003-health-and-sync.md',
    'specs/004-sleep.md', 'specs/005-activity.md',
    'specs/006-acceptance.md', 'specs/007-implementation-plan.md',
    'docs/architecture.md', 'docs/development.md',
    'specs/008-development-workflow.md', 'docs/stdd.md', 'STDD_CONSTITUTION.md',
]

def require(condition, message):
    if not condition:
        raise SystemExit(message)

for name in required:
    require((root / name).is_file(), f'Missing document: {name}')

markdown = sorted(p for p in root.rglob('*.md')
                  if not any(part in {'.git', '.build', 'work', '.swiftpm'}
                             for part in p.relative_to(root).parts))
for path in markdown:
    content = path.read_text()
    require(content.strip(), f'Empty document: {path.relative_to(root)}')
    targets = re.findall(r'\[[^\]]+\]\(([^)]+)\)', content)
    targets += re.findall(r'<img[^>]+src="([^"]+)"', content)
    for target in targets:
        parsed = urlsplit(target)
        if not parsed.scheme and parsed.path:
            require((path.parent / unquote(parsed.path)).is_file(),
                    f'Broken link in {path.relative_to(root)}: {target}')

specs = sorted((root / 'specs').glob('[0-9][0-9][0-9]-*.md'))
all_specs = '\n'.join(p.read_text() for p in specs)
ids = re.findall(r'^- ([A-Z]+-(?:A)?\d{2,3})：', all_specs, re.M)
require(len(ids) == len(set(ids)), 'Duplicate acceptance ID')
for path in specs:
    require('## 验收标准' in path.read_text(), f'Missing acceptance section: {path.name}')
for reference in re.findall(r'\b(?:P|A|H|SL|TR|QA|PLAN)-\d{3}\b', all_specs):
    require(reference in ids, f'Undefined acceptance ID: {reference}')

scenarios = re.findall(r'^\| (SCN-\d{3}) \|', (root / 'specs/006-acceptance.md').read_text(), re.M)
require(len(scenarios) == len(set(scenarios)) and len(scenarios) >= 31,
        'Acceptance matrix has duplicate or missing scenarios')

def reject_constant(value):
    raise ValueError(f'Non-finite JSON number: {value}')

fixture = json.loads((root / 'specs/fixtures/business-v1.json').read_text(),
                     parse_constant=reject_constant)
require(fixture['schemaVersion'] == 1 and fixture['syntheticOnly'] is True,
        'Fixture must be schema 1 and synthetic only')
require(math.isfinite(fixture['tolerance']) and fixture['tolerance'] > 0,
        'Invalid fixture tolerance')
operations = {'readiness', 'stress', 'batteryStep', 'exertion', 'targetRange', 'sleepDebt', 'regularity'}
seen = set()
for vector in fixture['vectors']:
    require(vector['id'] not in seen, f'Duplicate vector: {vector["id"]}')
    seen.add(vector['id'])
    require(vector['scenario'] in scenarios, f'Unknown scenario: {vector["scenario"]}')
    require(vector['operation'] in operations, f'Unknown operation: {vector["operation"]}')
    require(isinstance(vector['input'], dict) and isinstance(vector['expected'], dict)
            and vector['expected'], f'Incomplete vector: {vector["id"]}')

require((root / 'specs/fixtures/business-v1.json').read_bytes() ==
        (root / 'Packages/WristlabCore/Tests/WristlabCoreTests/Fixtures/business-v1.json').read_bytes(),
        'Swift test fixtures differ from the specification source')

print(f'Spec structure, local links, {len(ids)} acceptance IDs, '
      f'{len(scenarios)} scenarios, and {len(seen)} fixture structures passed')
print('Algorithm correctness and device behavior are not validated by this check.')

manifest = json.loads((root / 'docs/screenshots/manifest.json').read_text())
require({item['file'] for item in manifest} == {'iphone.png', 'watch.png'}, 'Missing screenshot entries')
for item in manifest:
    picture = root / 'docs/screenshots' / item['file']
    require(picture.is_file() and picture.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), 'Invalid screenshot PNG')
    require(hashlib.sha256(picture.read_bytes()).hexdigest() == item['imageSHA256'], 'Screenshot hash mismatch')
    require(re.fullmatch(r'[0-9a-f]{64}', item['sourceFingerprint']) is not None, 'Missing app-source fingerprint')
    require(re.fullmatch(r'[0-9a-f]{40}', item['commit']) is not None and '/actions/runs/' in item['run'], 'Missing capture provenance')
print('Bilingual README image links, screenshot hashes and capture provenance passed')
