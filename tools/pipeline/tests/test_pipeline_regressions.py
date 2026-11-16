"""Regression coverage for actual image decoding, coordinate flags and export failures."""
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

PIPELINE = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PIPELINE / name) for name in ('blender', 'train', 'import')]
import cone_render
import train_cloud
import ply_to_cloud


class PipelineTests(unittest.TestCase):
    def test_normal_capture_is_not_used_as_albedo(self):
        with tempfile.TemporaryDirectory() as tmp:
            data = Path(tmp)
            (data/'recipe.json').write_text(json.dumps({'color_mode': 'world-normal-encoded-raw'}))
            with self.assertRaisesRegex(ValueError, 'auxiliary data'):
                train_cloud.main(['--data', tmp, '--pack-only'])

    def test_surface_normals_are_validated(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)/'cloud.tres'
            gs = ply_to_cloud.make_canopy(1)
            for normals in ([], [[0, 0, 0]], [[float('nan'), 0, 1]]):
                with self.assertRaises(ValueError):
                    ply_to_cloud.write_tres(out, gs, 'test', normals)
            ply_to_cloud.write_tres(out, gs, 'test', [[0, 2, 0]])
            self.assertIn('shadow_vecs = PackedVector3Array(0, 1, 0)', out.read_text())

    def test_arbitrary_view_counts(self):
        for count in (1, 4, 17, 64, 128):
            cams = cone_render.hemisphere_cameras(1, count)
            self.assertEqual(len(cams), count)
            self.assertTrue(all(cone_render.camera_elevation_deg(c) >= 55 for c in cams))

    def test_real_png_filters_and_background(self):
        with tempfile.TemporaryDirectory() as tmp:
            cap = Path(tmp) / 'cap'
            cone_render.main(['--fixture', '--out', str(cap), '--views', '4', '--resolution', '32'])
            pixels = [(x * 7, y * 7, 70, (x * 13 + y * 29) % 256) for y in range(32) for x in range(32)]
            image = Image.new('RGBA', (32, 32)); image.putdata(pixels)
            image.save(cap / 'images/0000.png', optimize=True)
            ns = train_cloud.pack(cap)
            mask = Image.open(ns / 'masks/0000.png')
            self.assertEqual(list(mask.tobytes()), [255 if p[3] > 8 else 0 for p in pixels])
            rgb = Image.open(ns / 'images/0000.png')
            expected = Image.new('RGBA', image.size, (0, 0, 0, 255))
            expected.alpha_composite(image)
            self.assertEqual(rgb.tobytes(), expected.convert('RGB').tobytes())
            with self.assertRaises(ValueError):
                train_cloud.pack(cap)

    def test_world_frame_and_albedo_flags(self):
        cmd = train_cloud.training_command(Path('/cap/ns'), Path('/run'), 20)
        for flag, value in {'--orientation-method': 'none', '--center-method': 'none',
                            '--auto-scale-poses': 'False', '--assume-colmap-world-coordinate-convention': 'False',
                            '--pipeline.model.sh-degree': '0', '--pipeline.model.camera-optimizer.mode': 'off'}.items():
            self.assertEqual(cmd[cmd.index(flag) + 1], value)
        self.assertNotIn('--masks-path', cmd)
        self.assertGreater(cmd.index('colmap'), cmd.index('--pipeline.model.sh-degree'))
        self.assertEqual(cmd[cmd.index('--vis') + 1], 'tensorboard')
        self.assertEqual(cmd[cmd.index('--pipeline.model.num-downscales') + 1], '0')

    def test_quaternion_and_duplicate_positions(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'cloud.ply'
            gs = ply_to_cloud.make_canopy(4)
            ply_to_cloud.write_ply(path, gs)
            names, rows = ply_to_cloud.read_ply_vertices(path)
            imported = ply_to_cloud.convert(names, rows, 4, 'volume')
            self.assertEqual(imported[0]['q'], (0, 0, 0, 1))
        self.assertEqual(len(set(ply_to_cloud.farthest_point([(0, 0, 0)] * 6, 4))), 4)

    def test_binary_types_and_crlf(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'cloud.ply'
            path.write_bytes(b'ply\r\nformat binary_little_endian 1.0\r\nelement vertex 1\r\nproperty double x\r\nproperty uchar red\r\nend_header\r\n' + struct.pack('<dB', 1.25, 240))
            self.assertEqual(ply_to_cloud.read_ply_vertices(path), (['x', 'red'], [(1.25, 240)]))

    def test_reference_import_retains_thin_and_faint_gaussians(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'cloud.ply'
            gs = ply_to_cloud.make_canopy(3)
            gs[0]['s'] = (.03, .02, .00001)
            gs[1]['a'] = .01
            ply_to_cloud.write_ply(path, gs)
            names, rows = ply_to_cloud.read_ply_vertices(path)
            reference = ply_to_cloud.convert(names, rows, 1, 'volume',
                                             ((0, 0, 0), (.1, .1, .1)), reference=True)
            self.assertEqual(len(reference), 3)
            self.assertAlmostEqual(reference[0]['s'][2], .00001, places=8)
            self.assertAlmostEqual(reference[1]['a'], .01, places=6)
            self.assertEqual(len(ply_to_cloud.convert(names, rows, 3, 'volume')), 1)

    def test_export_and_failure_propagation(self):
        for fail_stage in (None, 'ns-train', 'ns-eval', 'ns-export'):
            with self.subTest(stage=fail_stage), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); ns = root / 'ns'; ns.mkdir()
                (root / 'recipe.json').write_text('{}')
                output = root / 'result.ply'
                commands = []
                def fake_run(cmd, **kwargs):
                    if cmd[0] in ('ns-eval', 'ns-export'):
                        self.assertEqual(kwargs['env']['TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD'], '1')
                    else:
                        self.assertNotIn('env', kwargs)
                    commands.append(cmd)
                    if cmd[0] == fail_stage:
                        return __import__('subprocess').CompletedProcess(cmd, 7)
                    if cmd[0] == 'ns-train':
                        run_dir = Path(cmd[cmd.index('--output-dir') + 1])
                        config = run_dir / 'splite/splatfacto/fit/config.yml'
                        config.parent.mkdir(parents=True); config.write_text('test')
                    elif cmd[0] == 'ns-export':
                        export = Path(cmd[cmd.index('--output-dir') + 1]); export.mkdir()
                        ply_to_cloud.write_ply(export / 'splat.ply', ply_to_cloud.make_canopy(4))
                    elif cmd[0] == sys.executable:
                        ply_to_cloud.main(cmd[2:])
                    return __import__('subprocess').CompletedProcess(cmd, 0)
                with patch.object(train_cloud, '_which', return_value='/bin/mock'), patch.object(train_cloud.importlib.metadata, 'version', return_value='test'), patch.object(train_cloud.subprocess, 'run', side_effect=fake_run):
                    result = train_cloud.train(ns, output, 20, 3)
                self.assertEqual(result, 7 if fail_stage else 0)
                self.assertEqual(output.exists(), fail_stage is None)
                report = json.loads(next(root.glob('result-*/run.json')).read_text())
                self.assertEqual(report['status'], 'failed' if fail_stage else 'complete')


if __name__ == '__main__':
    unittest.main()
