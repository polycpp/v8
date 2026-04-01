#!/usr/bin/env python3
"""Detect V8 version features by scanning the source tree.

Produces a JSON manifest describing which features, third-party deps,
and build characteristics are present for a given V8 version.
"""

import argparse
import json
import os
import re
import sys


def read_version(source_dir):
    """Read V8 version from v8-version.h."""
    path = os.path.join(source_dir, "include", "v8-version.h")
    if not os.path.exists(path):
        return None
    with open(path, "r") as f:
        content = f.read()
    major = re.search(r"#define V8_MAJOR_VERSION\s+(\d+)", content)
    minor = re.search(r"#define V8_MINOR_VERSION\s+(\d+)", content)
    build = re.search(r"#define V8_BUILD_NUMBER\s+(\d+)", content)
    patch = re.search(r"#define V8_PATCH_LEVEL\s+(\d+)", content)
    if not all([major, minor, build, patch]):
        return None
    return {
        "major": int(major.group(1)),
        "minor": int(minor.group(1)),
        "build": int(build.group(1)),
        "patch": int(patch.group(1)),
        "string": f"{major.group(1)}.{minor.group(1)}.{build.group(1)}.{patch.group(1)}",
    }


def detect_features(source_dir):
    """Detect which V8 features are present in the source tree."""
    features = {}

    # Maglev (mid-tier compiler, added ~V8 10.x, stabilized ~V8 11.x)
    features["maglev"] = os.path.isdir(os.path.join(source_dir, "src", "maglev"))

    # Turboshaft (next-gen compiler IR, added ~V8 11.x)
    features["turboshaft"] = os.path.isdir(
        os.path.join(source_dir, "src", "compiler", "turboshaft")
    )

    # Sparkplug (baseline compiler, added ~V8 9.1)
    features["sparkplug"] = os.path.isfile(
        os.path.join(source_dir, "src", "baseline", "baseline-compiler.cc")
    )

    # WebAssembly
    features["webassembly"] = os.path.isdir(
        os.path.join(source_dir, "src", "wasm")
    )

    # Sandbox (added ~V8 12.x)
    features["sandbox"] = os.path.isdir(
        os.path.join(source_dir, "src", "sandbox")
    )

    # I18N/ICU
    features["i18n"] = os.path.isdir(
        os.path.join(source_dir, "third_party", "icu")
    )

    # Pointer compression (present in most modern versions)
    features["pointer_compression"] = _grep_file(
        os.path.join(source_dir, "BUILD.gn"), "v8_enable_pointer_compression"
    )

    # Leaptiering (added ~V8 14.x)
    features["leaptiering"] = _grep_file(
        os.path.join(source_dir, "BUILD.gn"), "v8_enable_leaptiering"
    ) or _grep_dir(source_dir, "src/flags", "leaptiering")

    # CppGC young generation
    features["cppgc_young_generation"] = _grep_file(
        os.path.join(source_dir, "BUILD.gn"), "cppgc_young_generation"
    )

    # Continuation-preserved embedder data
    features["continuation_preserved_embedder_data"] = _grep_file(
        os.path.join(source_dir, "BUILD.gn"),
        "v8_enable_continuation_preserved_embedder_data",
    )

    # ETW (Windows event tracing)
    features["etw"] = _grep_file(
        os.path.join(source_dir, "BUILD.gn"), "v8_enable_etw"
    ) or os.path.isdir(os.path.join(source_dir, "src", "diagnostics", "etw-jit-win"))

    return features


def detect_third_party(source_dir):
    """Detect which third-party dependencies are present."""
    tp = os.path.join(source_dir, "third_party")
    deps = {}

    deps["abseil"] = os.path.isdir(os.path.join(tp, "abseil-cpp"))
    deps["highway"] = os.path.isdir(os.path.join(tp, "highway"))
    deps["simdutf"] = os.path.isdir(os.path.join(tp, "simdutf"))
    deps["fp16"] = os.path.isdir(os.path.join(tp, "fp16"))
    deps["dragonbox"] = os.path.isdir(os.path.join(tp, "dragonbox"))
    deps["fast_float"] = os.path.isdir(os.path.join(tp, "fast_float"))
    deps["icu"] = os.path.isdir(os.path.join(tp, "icu"))
    deps["zlib"] = os.path.isdir(os.path.join(tp, "zlib"))
    deps["googletest"] = os.path.isdir(os.path.join(tp, "googletest"))

    return deps


def detect_cxx_standard(source_dir):
    """Detect the minimum C++ standard required."""
    config_path = os.path.join(source_dir, "include", "v8config.h")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            content = f.read()
        if "202002L" in content or "__cplusplus <= 201703L" in content:
            return 20
        if "201703L" in content or "__cplusplus <= 201402L" in content:
            return 17
    # Check BUILD.gn for cxx_std
    gn_path = os.path.join(source_dir, "BUILD.gn")
    if os.path.exists(gn_path):
        with open(gn_path, "r") as f:
            content = f.read()
        if "c++20" in content or "cxx_std_20" in content:
            return 20
        if "c++17" in content or "cxx_std_17" in content:
            return 17
    return 17  # default to C++17


def detect_build_gn_targets(source_dir):
    """List which GN targets exist in BUILD.gn."""
    gn_path = os.path.join(source_dir, "BUILD.gn")
    if not os.path.exists(gn_path):
        return []
    with open(gn_path, "r") as f:
        content = f.read()
    # Find source_set and static_library definitions
    targets = re.findall(
        r'(?:source_set|static_library|executable)\("([^"]+)"\)', content
    )
    return sorted(set(targets))


def _grep_file(filepath, pattern):
    """Check if a pattern exists in a file."""
    if not os.path.exists(filepath):
        return False
    with open(filepath, "r", errors="ignore") as f:
        return pattern in f.read()


def _grep_dir(source_dir, subdir, pattern):
    """Check if pattern exists in any file in a subdirectory."""
    dirpath = os.path.join(source_dir, subdir)
    if not os.path.isdir(dirpath):
        return False
    for fname in os.listdir(dirpath):
        fpath = os.path.join(dirpath, fname)
        if os.path.isfile(fpath):
            if _grep_file(fpath, pattern):
                return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Detect V8 version features")
    parser.add_argument(
        "--source-dir", required=True, help="Path to V8 source tree"
    )
    parser.add_argument(
        "--output", default="-", help="Output JSON file (- for stdout)"
    )
    args = parser.parse_args()

    if not os.path.isdir(args.source_dir):
        print(f"Error: {args.source_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    version = read_version(args.source_dir)
    if not version:
        print("Error: Could not read V8 version", file=sys.stderr)
        sys.exit(1)

    result = {
        "version": version["string"],
        "major": version["major"],
        "minor": version["minor"],
        "build": version["build"],
        "patch": version["patch"],
        "cxx_standard": detect_cxx_standard(args.source_dir),
        "features": detect_features(args.source_dir),
        "third_party": detect_third_party(args.source_dir),
        "gn_targets": detect_build_gn_targets(args.source_dir),
    }

    output = json.dumps(result, indent=2)
    if args.output == "-":
        print(output)
    else:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Feature manifest written to {args.output}")


if __name__ == "__main__":
    main()
