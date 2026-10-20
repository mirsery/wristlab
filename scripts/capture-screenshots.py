"""Capture the running apps with synthetic --demo input on CI simulators."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
out = root / 'work/screenshots'
out.mkdir(parents=True, exist_ok=True)

def run(*args, check=True, timeout=300):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    with (out / 'capture.log').open('a') as log:
        log.write(' '.join(args) + '\n' + result.stdout + result.stderr + '\n')
    if check and result.returncode:
        print(result.stdout, result.stderr, flush=True)
        raise RuntimeError(f'Simulator command failed ({result.returncode}): {args}')
    return result

devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json').stdout)['devices']
ios = [d for runtime, items in devices.items() if 'iOS-' in runtime for d in items if 'iPhone' in d['name']]
watch = [d for runtime, items in devices.items() if 'watchOS-' in runtime for d in items if 'Apple Watch' in d['name']]
if not ios or not watch:
    raise SystemExit('Both iOS and watchOS simulator runtimes are required for screenshots')
phone = next((d for d in ios if d['name'] == 'iPhone 16 Pro'), ios[0])
watch = next((d for d in watch if 'Series 10' in d['name'] and '46mm' in d['name']), watch[0])
run('xcrun', 'simctl', 'pair', watch['udid'], phone['udid'], check=False)
manifest = []
for device, product, bundle, name in [
    (phone, 'work/DerivedData-iOS/Build/Products/Debug-iphonesimulator/Wristlab.app', 'com.mirsery.wristlab', 'iphone'),
    (watch, 'work/DerivedData-watchOS/Build/Products/Debug-watchsimulator/WristlabWatch.app', 'com.mirsery.wristlab.watchkitapp', 'watch')]:
    print('Capturing', device['name'], flush=True)
    run('xcrun', 'simctl', 'boot', device['udid'], check=False)
    run('xcrun', 'simctl', 'bootstatus', device['udid'], '-b')
    run('xcrun', 'simctl', 'ui', device['udid'], 'appearance', 'dark', check=False)
    run('xcrun', 'simctl', 'status_bar', device['udid'], 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100', check=False)
    run('xcrun', 'simctl', 'install', device['udid'], str(root / product))
    run('xcrun', 'simctl', 'launch', device['udid'], bundle, '--demo', '-AppleLanguages', '(zh-Hans)', '-AppleLocale', 'zh_CN')
    time.sleep(15)
    run('xcrun', 'simctl', 'io', device['udid'], 'screenshot', str(out / f'{name}.png'))
    manifest.append({'file': f'{name}.png', 'device': device['name'], 'data': 'synthetic --demo', 'source': 'running SwiftUI app', 'commit': os.environ.get('GITHUB_SHA'), 'run': f"https://github.com/{os.environ.get('GITHUB_REPOSITORY', 'mirsery/wristlab')}/actions/runs/{os.environ.get('GITHUB_RUN_ID', 'local')}"})
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Screenshots saved to', out)
