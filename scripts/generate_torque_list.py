#!/usr/bin/env python3
"""Generate the torque (.tq) file list for a V8 version.

Extracts torque file lists from BUILD.gn and verifies they exist on disk.
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parse_gn import GnParser


def find_torque_files_from_gn(source_dir: str) -> list:
    """Extract .tq file list from BUILD.gn."""
    gn_path = os.path.join(source_dir, "BUILD.gn")
    if not os.path.exists(gn_path):
        return []
    parser = GnParser(gn_path)
    return parser.get_torque_files()


def find_torque_files_from_fs(source_dir: str) -> list:
    """Fallback: find all .tq files by scanning the filesystem."""
    tq_files = []
    for root, dirs, files in os.walk(source_dir):
        # Skip third_party and test directories
        dirs[:] = [d for d in dirs if d not in ("third_party", "test", ".git")]
        for f in files:
            if f.endswith(".tq"):
                rel = os.path.relpath(os.path.join(root, f), source_dir)
                tq_files.append(rel.replace("\\", "/"))
    return sorted(tq_files)


def main():
    parser = argparse.ArgumentParser(description="Generate torque file list")
    parser.add_argument("--source-dir", required=True, help="V8 source directory")
    parser.add_argument("--output", default="-", help="Output file (- for stdout)")
    parser.add_argument("--format", choices=["cmake", "json", "plain"], default="cmake")
    args = parser.parse_args()

    # Try GN first, fall back to filesystem
    tq_files = find_torque_files_from_gn(args.source_dir)
    source = "BUILD.gn"
    if not tq_files:
        print("No torque files found in BUILD.gn, scanning filesystem...", file=sys.stderr)
        tq_files = find_torque_files_from_fs(args.source_dir)
        source = "filesystem"

    # Verify files exist
    verified = []
    missing = []
    for f in tq_files:
        if os.path.exists(os.path.join(args.source_dir, f)):
            verified.append(f)
        else:
            missing.append(f)

    print(f"Found {len(verified)} torque files (from {source})", file=sys.stderr)
    if missing:
        print(f"  {len(missing)} listed but missing on disk", file=sys.stderr)

    # Format output
    if args.format == "json":
        output = json.dumps(verified, indent=2)
    elif args.format == "cmake":
        lines = ["# Torque (.tq) file list", f"# {len(verified)} files", "set(V8_TORQUE_FILES"]
        for f in verified:
            lines.append(f'  "${{V8_ROOT}}/{f}"')
        lines.append(")")
        output = "\n".join(lines)
    else:
        output = "\n".join(verified)

    if args.output == "-":
        print(output)
    else:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Written to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
