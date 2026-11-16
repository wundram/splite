#!/usr/bin/env python3
"""Bundle one real capture and this pipeline for upload to a Colab GPU runtime."""
import argparse
import json
from pathlib import Path
import zipfile


def bundle(capture, output):
    capture, output = Path(capture).resolve(), Path(output).resolve()
    recipe = json.loads((capture / 'recipe.json').read_text())
    if recipe.get('source') == 'builtin:cube' or recipe.get('blender_hash') == 'fixture-cube':
        raise ValueError('Fixture pixels are not training data')
    tf = json.loads((capture / 'transforms.json').read_text())
    if len(tf['frames']) < 16:
        raise ValueError('Use at least 16 real views for a training bundle')
    files = [(capture / name, 'capture/' + name) for name in ('transforms.json', 'recipe.json', 'points3D.ply')]
    for frame in tf['frames']:
        relative = Path(frame['file_path'])
        if relative.suffix != '.png':
            relative = relative.with_suffix('.png')
        source = (capture / relative).resolve()
        if not source.is_relative_to(capture) or not source.is_file():
            raise ValueError(f'Invalid capture image: {relative}')
        files.append((source, 'capture/' + relative.as_posix()))
    pipeline = Path(__file__).resolve().parent
    files.extend((p, 'pipeline/' + p.relative_to(pipeline).as_posix()) for p in pipeline.rglob('*.py'))
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED) as archive:
        for path, name in files:
            archive.write(path, name)
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    bundle(args.data, args.out)
