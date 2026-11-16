#!/usr/bin/env python3
"""Run a remote pipeline command with durable status and log files.

Usage: python run_job.py --job-dir /content/jobs/calibration -- python train_cloud.py ...
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--job-dir', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('command required after --')
    directory = Path(args.job_dir).resolve()
    directory.mkdir(parents=True, exist_ok=False)
    status = {'status': 'running', 'pid': os.getpid(), 'command': command,
              'started_at': datetime.now(timezone.utc).isoformat()}
    def save():
        temp = directory / 'status.tmp'
        temp.write_text(json.dumps(status, indent=2) + '\n')
        temp.replace(directory / 'status.json')
    save()
    try:
        with (directory / 'output.log').open('w') as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            status['child_pid'] = child.pid
            save()
            code = child.wait()
        status.update(status='complete' if code == 0 else 'failed', returncode=code)
    except Exception as exc:
        status.update(status='failed', error=repr(exc), returncode=1)
    status['finished_at'] = datetime.now(timezone.utc).isoformat()
    save()
    return status['returncode']


if __name__ == '__main__':
    sys.exit(main())
