#!/usr/bin/env python3
"""Write checksums for the final renamed x86 EFI release artifact."""
import hashlib
import json
import os
from pathlib import Path
import sys


def generate(directory, repository, build_id):
    directory = Path(directory).resolve()
    images = sorted(directory.glob('*-openwrt-x86-64-generic-squashfs-combined-efi.img.gz'))
    if len(images) != 1:
        raise RuntimeError(f'Expected one x86-64 squashfs EFI image, found {len(images)} in {directory}')
    image = images[0]
    digest = hashlib.sha256()
    size = 0
    with image.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            size += len(block)
            digest.update(block)
    if not size:
        raise RuntimeError('Firmware image is empty; refusing to publish checksums')
    asset = {'filename': image.name, 'size': size, 'sha256': digest.hexdigest()}
    data = {'schema_version': 1, 'repository': repository, 'build_id': build_id,
            'target': 'x86/64', 'firmware': [asset]}
    outputs = {
        'online-update.json': json.dumps(data, ensure_ascii=False, indent=2) + '\n',
        'sha256sums': f'{asset["sha256"]}  {image.name}\n',
    }
    for name, content in outputs.items():
        pending = directory / (name + '.tmp')
        pending.write_text(content, encoding='utf-8')
        pending.replace(directory / name)
    return asset


def main():
    if len(sys.argv) != 2:
        raise SystemExit('Usage: generate-online-manifest.py FIRMWARE_DIRECTORY')
    repository = os.environ.get('GITHUB_REPOSITORY', 'longdongqiang-jason/X86-daed')
    run = os.environ.get('GITHUB_RUN_ID', 'local')
    attempt = os.environ.get('GITHUB_RUN_ATTEMPT', '1')
    asset = generate(sys.argv[1], repository, f'{run}-{attempt}')
    print(f'Firmware: {asset["filename"]}\nSize: {asset["size"]}\nSHA256: {asset["sha256"]}')
    print('Created online-update.json and sha256sums beside the firmware')


if __name__ == '__main__':
    main()
