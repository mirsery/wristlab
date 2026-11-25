#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work/settings-connection-ui"
BUNDLE = "com.mirsery.wristlab.settingsprobe"


def run(arguments, timeout=300):
    return subprocess.run(arguments, cwd=ROOT, check=True, timeout=timeout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device")
    parser.add_argument("--only-testing")
    args = parser.parse_args()
    if "DEVELOPER_DIR" not in os.environ:
        selected = subprocess.check_output(["xcode-select", "-p"], text=True).strip()
        os.environ["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer" if "CommandLineTools" in selected else selected
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))["devices"]
    sdk = tuple(int(part) for part in subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True).strip().split("."))
    versions = {runtime: tuple(int(part) for part in runtime.rsplit(".iOS-", 1)[1].split("-")) for runtime in devices if ".iOS-" in runtime}
    runtimes = [runtime for runtime, version in versions.items() if (17,) <= version <= sdk]
    candidates = [device for runtime in runtimes for device in devices[runtime] if "iPhone" in device["name"]]
    if args.device:
        candidates = [device for device in candidates if device["udid"] == args.device]
    elif runtimes:
        newest = max(runtimes, key=lambda runtime: versions[runtime])
        candidates = [device for device in candidates if device in devices[newest]] or candidates
    if not candidates:
        raise SystemExit("An available iPhone simulator is required")
    device = sorted(candidates, key=lambda item: item["state"] != "Booted")[0]
    identifier = device["udid"]
    sources = WORK / "Sources"
    tests = WORK / "UITests"
    sources.mkdir(parents=True, exist_ok=True)
    tests.mkdir(parents=True, exist_ok=True)
    for source in [ROOT / "Apps/iOS/DashboardModel.swift", ROOT / "Apps/iOS/SettingsView.swift",
                   ROOT / "Tests/Apple/PhoneHealthTestAdapters.swift", ROOT / "Tests/Apple/SettingsConnectionHost.swift"]:
        shutil.copy2(source, sources / source.name)
    shutil.copy2(ROOT / "Tests/Apple/SettingsConnectionUITests.swift", tests / "SettingsConnectionUITests.swift")
    package = json.dumps(str(ROOT / "Packages/WristlabCore"))
    (WORK / "project.yml").write_text(f'''name: SettingsConnectionHost
options:
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
packages:
  WristlabCore:
    path: {package}
targets:
  SettingsConnectionHost:
    type: application
    platform: iOS
    sources: [Sources]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {BUNDLE}
        TARGETED_DEVICE_FAMILY: "1"
    info:
      path: Info.plist
      properties:
        UILaunchScreen: {{}}
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
    dependencies:
      - package: WristlabCore
  SettingsConnectionUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [UITests]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {BUNDLE}.uitests
        TEST_TARGET_NAME: SettingsConnectionHost
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: SettingsConnectionHost
schemes:
  SettingsConnectionHost:
    build:
      targets:
        SettingsConnectionHost: all
    test:
      targets: [SettingsConnectionUITests]
''')
    run(["xcodegen", "generate", "--spec", str(WORK / "project.yml")])
    command = ["xcodebuild", "-project", str(WORK / "SettingsConnectionHost.xcodeproj"), "-scheme", "SettingsConnectionHost",
               "-destination", f"platform=iOS Simulator,id={identifier}", "-derivedDataPath", str(WORK / "DerivedData"),
               "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO", "test"]
    if args.only_testing:
        command.append(f"-only-testing:{args.only_testing}")
    try:
        run(command, timeout=600)
    finally:
        subprocess.run(["xcrun", "simctl", "uninstall", identifier, BUNDLE], cwd=ROOT, capture_output=True, timeout=30)
        subprocess.run(["xcrun", "simctl", "uninstall", identifier, BUNDLE + ".uitests.xctrunner"], cwd=ROOT, capture_output=True, timeout=30)


if __name__ == "__main__":
    main()
