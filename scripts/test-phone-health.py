#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work/phone-health-tests"
SOURCES = WORK / "Sources"
SOURCES.mkdir(parents=True, exist_ok=True)
for source in [
    ROOT / "Apps/iOS/DashboardModel.swift",
    ROOT / "Tests/Apple/PhoneHealthTestAdapters.swift",
    ROOT / "Tests/Apple/PhoneHealthConnectionTests.swift",
]:
    shutil.copy2(source, SOURCES / source.name)
package_path = json.dumps(str(ROOT / "Packages/WristlabCore"))
(WORK / "Package.swift").write_text(f'''// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PhoneHealthConnectionProbe",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: {package_path})],
    targets: [.testTarget(name: "PhoneHealthConnectionTests",
        dependencies: [.product(name: "WristlabCore", package: "WristlabCore")], path: "Sources")]
)
''')
subprocess.run([str(ROOT / "scripts/swift-test.sh"), "--package-path", str(WORK)], cwd=ROOT, check=True, timeout=300)
