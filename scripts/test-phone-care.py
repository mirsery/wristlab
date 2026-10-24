#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work/phone-care-ui"
BUNDLE = "com.mirsery.wristlab.careprobe"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", default=os.environ.get("WRISTLAB_PHONE_CARE_SIMULATOR"))
    parser.add_argument("--legacy", action="store_true")
    parser.add_argument("--only-testing")
    parser.add_argument("--full-app", action="store_true")
    args = parser.parse_args()
    if args.full_app and (not args.device or args.legacy):
        parser.error("--full-app requires an explicit isolated --device and cannot use --legacy")
    if "DEVELOPER_DIR" not in os.environ:
        selected = subprocess.check_output(["xcode-select", "-p"], text=True).strip()
        os.environ["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer" if "CommandLineTools" in selected else selected
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))["devices"]
    sdk = tuple(int(part) for part in subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True).strip().split("."))
    versions = {runtime: tuple(int(part) for part in runtime.rsplit(".iOS-", 1)[1].split("-")) for runtime in devices if ".iOS-" in runtime}
    runtimes = [runtime for runtime, version in versions.items() if (17,) <= version <= sdk]
    candidates = [device for runtime in runtimes for device in devices[runtime]
                  if "iPhone" in device.get("deviceTypeIdentifier", device["name"])]
    if args.device:
        candidates = [device for device in candidates if device["udid"] == args.device]
    elif runtimes:
        newest = max(runtimes, key=lambda runtime: versions[runtime])
        candidates = [device for device in candidates if device in devices[newest]] or candidates
    if not candidates:
        raise SystemExit("An available compatible iPhone simulator is required")
    identifier = sorted(candidates, key=lambda item: item["state"] != "Booted")[0]["udid"]
    sources = WORK / "Sources"
    tests = WORK / "UITests"
    sources.mkdir(parents=True, exist_ok=True)
    tests.mkdir(parents=True, exist_ok=True)
    names = ["Apps/Shared/MetricPresentation.swift", "Tests/Apple/PhoneCareHost.swift"]
    if not args.legacy:
        names += ["Apps/iOS/PhoneCareViews.swift", "Apps/iOS/MetricDetailView.swift"]
    for old in sources.glob("*.swift"):
        old.unlink()
    for name in names:
        source = ROOT / name
        shutil.copy2(source, sources / source.name)
    shutil.copy2(ROOT / "Tests/Apple/PhoneCareUITests.swift", tests / "PhoneCareUITests.swift")
    package = json.dumps(str(ROOT / "Packages/WristlabCore"))
    flags = "$(inherited) LEGACY_CARE_PROBE" if args.legacy else "$(inherited) FULL_APP_CARE_PROBE" if args.full_app else "$(inherited)"
    (WORK / "project.yml").write_text(f'''name: PhoneCareHost
options:
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_ACTIVE_COMPILATION_CONDITIONS: "{flags}"
packages:
  WristlabCore:
    path: {package}
targets:
  PhoneCareHost:
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
  PhoneCareUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [UITests]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {BUNDLE}.uitests
        TEST_TARGET_NAME: PhoneCareHost
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: PhoneCareHost
schemes:
  PhoneCareHost:
    build:
      targets:
        PhoneCareHost: all
    test:
      targets: [PhoneCareUITests]
''')
    subprocess.run(["xcodegen", "generate", "--spec", str(WORK / "project.yml")], cwd=ROOT, check=True)
    command = ["xcodebuild", "-project", str(WORK / "PhoneCareHost.xcodeproj"), "-scheme", "PhoneCareHost",
               "-destination", f"platform=iOS Simulator,id={identifier}", "-derivedDataPath", str(WORK / "DerivedData"),
               "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO", "test"]
    if args.full_app:
        for name in ["testFullAppTodayNavigation_TC_PTC_005_006", "testScrolledContentStaysOutOfStatusBar_TC_PCL_003",
                     "testLastTodayCardClearsTabBar_TC_PCL_004"]:
            command.append(f"-only-testing:PhoneCareUITests/PhoneCareUITests/{name}")
    elif args.only_testing:
        command.append(f"-only-testing:{args.only_testing}")
    try:
        subprocess.run(command, cwd=ROOT, check=True, timeout=900)
    finally:
        for bundle in [BUNDLE, BUNDLE + ".uitests.xctrunner"]:
            subprocess.run(["xcrun", "simctl", "uninstall", identifier, bundle], cwd=ROOT, capture_output=True, timeout=30)


if __name__ == "__main__":
    main()
