#!/usr/bin/env python3
"""Execute the production Widget configurations in a disposable watchOS host.

Compilation alone misses WidgetKit runtime metadata preconditions. The host uses
synthetic UI only, never invokes a provider, and never opens a health container.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work" / "widget-registration-test"


def run(args, *, capture=False, timeout=180):
    return subprocess.run(
        args, cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None, timeout=timeout,
    ).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", help="Available watchOS simulator UDID")
    parser.add_argument("--widget-source", type=Path,
                        default=ROOT / "Apps/Widgets/WristlabWidget.swift",
                        help="Production source or a saved baseline for RED replay")
    args = parser.parse_args()
    # Keep this process on one full Xcode toolchain; do not modify xcode-select.
    if "DEVELOPER_DIR" not in os.environ:
        selected = subprocess.check_output(["xcode-select", "-p"], text=True).strip()
        os.environ["DEVELOPER_DIR"] = (
            "/Applications/Xcode.app/Contents/Developer"
            if "CommandLineTools" in selected else selected
        )
    devices = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"], capture=True))["devices"]
    watches = [d for runtime, group in devices.items() if "watchOS" in runtime for d in group]
    if args.device:
        watches = [d for d in watches if d["udid"] == args.device]
    if not watches:
        raise SystemExit("Install an available watchOS simulator runtime first.")
    device = sorted(watches, key=lambda d: d["state"] != "Booted")[0]
    udid = device["udid"]
    if device["state"] != "Booted":
        run(["xcrun", "simctl", "boot", udid])
    run(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=300)
    sources = WORK / "Sources"
    sources.mkdir(parents=True, exist_ok=True)
    widget = args.widget_source.read_text()
    if widget.count("@main\n") != 1:
        raise SystemExit("Review probe extraction: expected one WidgetBundle entry point.")
    # Copy the real views/configuration bodies, changing only the entry point.
    (sources / "WidgetUnderTest.swift").write_text(widget.replace("@main\n", ""))
    (sources / "ProbeApp.swift").write_text('''import SwiftUI
import Darwin
@main struct RegistrationProbe: App {
    var body: some Scene {
        WindowGroup {
            Text("Widget registration test").task {
                withExtendedLifetime(EnergyWidget().body) { print("REGISTRATION: energy OK") }
                withExtendedLifetime(ReadinessWidget().body) { print("REGISTRATION: readiness OK") }
                withExtendedLifetime(StressWidget().body) { print("REGISTRATION: stress OK") }
                withExtendedLifetime(OverviewWidget().body) { print("REGISTRATION: overview OK") }
                print("REGISTRATION: PASS")
                fflush(stdout)
                exit(0)
            }
        }
    }
}
''')
    package = json.dumps(str(ROOT / "Packages/WristlabCore"))
    (WORK / "project.yml").write_text(f'''name: WidgetRegistrationTest
options:
  deploymentTarget:
    watchOS: "10.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
packages:
  WristlabCore:
    path: {package}
targets:
  WidgetRegistrationTest:
    type: application
    platform: watchOS
    sources: [Sources]
    info:
      path: Info.plist
      properties:
        WKApplication: true
        WKWatchOnly: true
        CFBundleDisplayName: Widget Registration Test
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mirsery.wristlab.registrationtest
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - package: WristlabCore
''')
    run(["xcodegen", "generate", "--spec", str(WORK / "project.yml")])
    with (WORK / "build.log").open("w") as log:
        subprocess.run([
            "xcodebuild", "-project", str(WORK / "WidgetRegistrationTest.xcodeproj"),
            "-scheme", "WidgetRegistrationTest", "-configuration", "Debug",
            "-destination", f"id={udid}", "-derivedDataPath", str(WORK / "DerivedData"),
            "CODE_SIGNING_ALLOWED=NO", "build",
        ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=240)
    app = WORK / "DerivedData/Build/Products/Debug-watchsimulator/WidgetRegistrationTest.app"
    bundle = "com.mirsery.wristlab.registrationtest"
    run(["xcrun", "simctl", "install", udid, str(app)])
    try:
        output = run(["xcrun", "simctl", "launch", "--console", "--terminate-running-process", udid, bundle], capture=True, timeout=45)
        (WORK / "runtime.log").write_text(output)
        print(output)
        # simctl can return zero even when the child traps: require every marker.
        markers = [f"REGISTRATION: {kind} OK" for kind in ["energy", "readiness", "stress", "overview"]] + ["REGISTRATION: PASS"]
        if not all(marker in output for marker in markers) or "Fatal error:" in output:
            raise SystemExit("FAIL: production Widget configuration trapped or did not finish.")
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (WORK / "runtime.log").write_text(output + "\n" + str(error))
        raise
    finally:
        run(["xcrun", "simctl", "uninstall", udid, bundle])


if __name__ == "__main__":
    main()
