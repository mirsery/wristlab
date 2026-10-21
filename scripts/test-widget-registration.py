#!/usr/bin/env python3
"""Execute the production Widget configurations in a disposable watchOS or iOS host.

Compilation alone misses WidgetKit runtime metadata preconditions. The host uses
synthetic UI only, never invokes a provider, and never opens a health container.
"""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work" / "widget-registration-test"
EXECUTABLE = "WidgetRegistrationTest"
# Each platform lists its production widget source and the configurations to execute.
PLATFORMS = {
    "watchos": {
        "runtime": "watchOS", "device": "", "source": "Apps/Widgets/WristlabWidget.swift",
        "widgets": [("energy", "EnergyWidget"), ("readiness", "ReadinessWidget"), ("stress", "StressWidget"), ("overview", "OverviewWidget")],
        "deployment": 'watchOS: "10.0"', "platform": "watchOS", "products": "Debug-watchsimulator",
        "info": "WKApplication: true\n        WKWatchOnly: true", "bundle": "com.mirsery.wristlab.registrationtest", "work": "widget-registration-test",
    },
    "ios": {
        "runtime": "iOS", "device": "iPhone", "source": "Apps/PhoneWidgets/WristlabPhoneWidget.swift",
        "widgets": [("phone", "WristlabPhoneSummaryWidget")],
        "deployment": 'iOS: "17.0"', "platform": "iOS", "products": "Debug-iphonesimulator",
        "info": "UILaunchScreen: {}", "bundle": "com.mirsery.wristlab.registrationtest.ios", "work": "widget-registration-test-ios",
    },
}


def run(args, *, capture=False, timeout=180):
    return subprocess.run(
        args, cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None, timeout=timeout,
    ).stdout


def diagnose(udid, since):
    """Print what the simulator recorded about the probe after a failed launch.

    A probe can exit without any marker or fatal message; the crash report and
    the simulator log are the only evidence left. Best effort: it only runs on a
    failure path, so a collection error can never turn a failure into a pass.
    """
    try:
        log = subprocess.run([
            "xcrun", "simctl", "spawn", udid, "log", "show", "--style", "compact",
            "--start", since.strftime("%Y-%m-%d %H:%M:%S"),
            "--predicate", f'process == "{EXECUTABLE}" OR eventMessage CONTAINS "{EXECUTABLE}"',
        ], text=True, capture_output=True, timeout=120)
        lines = (log.stdout + log.stderr).splitlines()[-200:]
        log_section = "--- simulator log (last 200 lines)\n" + "\n".join(lines)
    except (OSError, subprocess.TimeoutExpired) as error:
        log_section = f"--- simulator log unavailable: {error}"
    # ReportCrash writes asynchronously, seconds after the process is gone.
    deadline = time.monotonic() + 10
    while True:
        reports = sorted(
            p for p in (Path.home() / "Library/Logs/DiagnosticReports").glob(f"{EXECUTABLE}*")
            if p.stat().st_mtime >= since.timestamp()
        )
        if reports or time.monotonic() >= deadline:
            break
        time.sleep(1)
    sections = [f"--- crash report {p.name}\n{p.read_text(errors='replace')[:20000]}" for p in reports]
    sections = (sections or ["--- crash report: none written within 10 seconds"]) + [log_section]
    text = "\n".join(sections)
    (WORK / "diagnostics.log").write_text(text)
    print(text)


def main():
    global WORK
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=sorted(PLATFORMS), default="watchos")
    parser.add_argument("--device", help="Available simulator UDID for the platform")
    parser.add_argument("--widget-source", type=Path, help="Production source or a saved baseline for RED replay")
    args = parser.parse_args()
    config = PLATFORMS[args.platform]
    WORK = ROOT / "work" / config["work"]
    widget_source = args.widget_source or ROOT / config["source"]
    # Keep this process on one full Xcode toolchain; do not modify xcode-select.
    if "DEVELOPER_DIR" not in os.environ:
        selected = subprocess.check_output(["xcode-select", "-p"], text=True).strip()
        os.environ["DEVELOPER_DIR"] = (
            "/Applications/Xcode.app/Contents/Developer"
            if "CommandLineTools" in selected else selected
        )
    devices = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"], capture=True))["devices"]
    def version(runtime):
        return tuple(int(part) for part in runtime.rsplit(f".{config['runtime']}-", 1)[1].split("-") if part.isdigit())
    # Newest runtime first, so an old installed runtime below the deployment target is not picked.
    runtimes = sorted((r for r in devices if f".{config['runtime']}-" in r), key=version, reverse=True)
    candidates = [d for runtime in runtimes for d in devices[runtime] if config["device"] in d["name"]]
    if args.device:
        candidates = [d for d in candidates if d["udid"] == args.device]
    if not candidates:
        raise SystemExit(f"Install an available {config['runtime']} simulator runtime first.")
    newest = [d for d in candidates if d in devices[runtimes[0]]] or candidates
    device = sorted(newest, key=lambda d: d["state"] != "Booted")[0]
    udid = device["udid"]
    if device["state"] != "Booted":
        run(["xcrun", "simctl", "boot", udid])
    run(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=300)
    sources = WORK / "Sources"
    sources.mkdir(parents=True, exist_ok=True)
    widget = widget_source.read_text()
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
''' + "".join(f"                withExtendedLifetime({type_name}().body) {{ print(\"REGISTRATION: {name} OK\") }}\n" for name, type_name in config["widgets"]) + '''                print("REGISTRATION: PASS")
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
    {config["deployment"]}
settings:
  base:
    SWIFT_VERSION: "6.0"
packages:
  WristlabCore:
    path: {package}
targets:
  WidgetRegistrationTest:
    type: application
    platform: {config["platform"]}
    sources: [Sources]
    info:
      path: Info.plist
      properties:
        {config["info"]}
        CFBundleDisplayName: Widget Registration Test
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {config["bundle"]}
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - package: WristlabCore
''')
    run(["xcodegen", "generate", "--spec", str(WORK / "project.yml")])
    # A cold CI runner compiles the package for the probe from scratch; the iOS probe took over 4 minutes there.
    with (WORK / "build.log").open("w") as log:
        subprocess.run([
            "xcodebuild", "-project", str(WORK / "WidgetRegistrationTest.xcodeproj"),
            "-scheme", "WidgetRegistrationTest", "-configuration", "Debug",
            "-destination", f"id={udid}", "-derivedDataPath", str(WORK / "DerivedData"),
            "CODE_SIGNING_ALLOWED=NO", "build",
        ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
    app = WORK / f"DerivedData/Build/Products/{config['products']}/{EXECUTABLE}.app"
    bundle = config["bundle"]
    run(["xcrun", "simctl", "install", udid, str(app)])
    since = datetime.now()
    try:
        output = run(["xcrun", "simctl", "launch", "--console", "--terminate-running-process", udid, bundle], capture=True, timeout=45)
        (WORK / "runtime.log").write_text(output)
        print(output)
        # simctl can return zero even when the child traps: require every marker.
        markers = [f"REGISTRATION: {name} OK" for name, _ in config["widgets"]] + ["REGISTRATION: PASS"]
        if not all(marker in output for marker in markers) or "Fatal error:" in output:
            diagnose(udid, since)
            raise SystemExit("FAIL: production Widget configuration trapped or did not finish.")
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (WORK / "runtime.log").write_text(output + "\n" + str(error))
        diagnose(udid, since)
        raise
    finally:
        run(["xcrun", "simctl", "uninstall", udid, bundle])


if __name__ == "__main__":
    main()
