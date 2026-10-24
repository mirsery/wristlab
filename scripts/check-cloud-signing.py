import pathlib
import plistlib
import subprocess
import sys


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/check-cloud-signing.py path/to/Wristlab.app")
    bundle = pathlib.Path(sys.argv[1])
    with (bundle / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    if info.get("WristlabCloudKitEnabled") is not True:
        raise SystemExit("FAIL: this bundle does not enable CloudKit; do not claim cloud sync is available")
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise SystemExit("FAIL: signed entitlements cannot be read")
    try:
        entitlements = plistlib.loads(result.stdout)
    except (plistlib.InvalidFileException, ValueError):
        raise SystemExit("FAIL: missing or invalid signed entitlements")
    container = info.get("WristlabCloudContainer")
    environment = info.get("WristlabCloudEnvironment")
    valid = (
        isinstance(container, str)
        and container.startswith("iCloud.")
        and container in entitlements.get("com.apple.developer.icloud-container-identifiers", [])
        and "CloudKit" in entitlements.get("com.apple.developer.icloud-services", [])
        and environment in ("Development", "Production")
        and entitlements.get("com.apple.developer.icloud-container-environment") == environment
    )
    if not valid:
        raise SystemExit("FAIL: signed CloudKit container, service or environment does not match Info.plist")
    verification = subprocess.run(["codesign", "--verify", "--strict", str(bundle)], capture_output=True)
    if verification.returncode:
        raise SystemExit("FAIL: bundle signature verification failed")
    print("PASS: signed CloudKit container, service and environment match; server availability remains unverified")


if __name__ == "__main__":
    main()
