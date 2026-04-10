#!/usr/bin/env python3
"""Generate fetch_deps.py for a specific V8 version by parsing its DEPS file.

Fetches the DEPS file from the V8 Git repository for the given version tag
and generates a standalone fetch_deps.py that downloads V8 source and all
required third-party dependencies.
"""

import argparse
import base64
import os
import re
import sys
import urllib.request


GOOGLESOURCE_BASE = "https://chromium.googlesource.com/v8/v8"


def fetch_deps_file(version: str) -> str:
    """Fetch the DEPS file content for a V8 version tag."""
    # Try tag format: X.Y.Z.W or X.Y.Z
    for tag in [version, version.rsplit(".", 1)[0]]:
        url = f"{GOOGLESOURCE_BASE}/+/refs/tags/{tag}/DEPS?format=TEXT"
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=30) as resp:
                return base64.b64decode(resp.read()).decode("utf-8")
        except Exception:
            continue

    # Try branch-heads
    major_minor = ".".join(version.split(".")[:2])
    url = f"{GOOGLESOURCE_BASE}/+/refs/branch-heads/{major_minor}/DEPS?format=TEXT"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=30) as resp:
            return base64.b64decode(resp.read()).decode("utf-8")
    except Exception:
        pass

    return None


def parse_deps(deps_content: str) -> dict:
    """Parse the DEPS file to extract dependency URLs and revisions.

    V8's DEPS file uses two formats for third_party entries:

    Format 1 (simple string, possibly with Var()):
      'third_party/icu':
        Var('chromium_url') + '/chromium/deps/icu.git' + '@' + 'abc123',

    Format 2 (dict with 'url' key):
      'third_party/abseil-cpp': {
        'url': Var('chromium_url') + '/chromium/src/third_party/abseil-cpp.git' + '@' + 'abc123',
        'condition': '...',
      },
    """
    deps = {}

    # Step 1: Resolve Var() definitions
    vars_dict = {}
    # Find the vars = { ... } block by matching balanced braces
    vars_start = re.search(r"vars\s*=\s*\{", deps_content)
    if vars_start:
        depth = 1
        pos = vars_start.end()
        while pos < len(deps_content) and depth > 0:
            if deps_content[pos] == "{":
                depth += 1
            elif deps_content[pos] == "}":
                depth -= 1
            pos += 1
        vars_block = deps_content[vars_start.end() : pos - 1]
        for m in re.finditer(r"'(\w+)':\s*'([^']*)'", vars_block):
            vars_dict[m.group(1)] = m.group(2)

    def resolve_url_expr(expr: str) -> str:
        """Resolve a Var('x') + '/path' + '@' + 'hash' expression into a URL@hash string."""
        # Replace Var('name') with its value
        def replace_var(m):
            name = m.group(1)
            return vars_dict.get(name, f"UNKNOWN_VAR_{name}")
        resolved = re.sub(r"Var\(['\"](\w+)['\"]\)", replace_var, expr)
        # Remove all string concatenation: handle any combo of quotes around +
        # After Var() replacement: `value + '/path' + '@' + 'hash'`
        resolved = re.sub(r"['\"]?\s*\+\s*['\"]?", "", resolved)
        # Strip remaining quotes and whitespace
        resolved = resolved.strip().strip("'\"").strip().rstrip(",").rstrip("'\"")
        return resolved

    # Step 2: Find all third_party dep entries
    # Join multiline entries: a dep key may be followed by its value on the next line
    lines = deps_content.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Match: 'third_party/NAME' or 'third_party/NAME/subdir'
        key_match = re.match(r"'(?:v8/)?third_party/([^']+)':\s*(.*)", line)
        if key_match:
            dep_path = key_match.group(1)
            dep_name = dep_path.split("/")[0]  # e.g., "dragonbox/src" -> "dragonbox"
            rest = key_match.group(2).strip()

            # Collect continuation lines if rest is empty or incomplete
            if not rest or (rest and "@" not in rest and "{" not in rest):
                i += 1
                while i < len(lines):
                    next_line = lines[i].strip()
                    rest += " " + next_line
                    if "@" in next_line or "{" in next_line or next_line == "":
                        break
                    i += 1

            # Format 2: dict with 'url' key
            if "{" in rest:
                # Collect until closing }
                block = rest
                while "}" not in block and i < len(lines) - 1:
                    i += 1
                    block += " " + lines[i].strip()
                url_match = re.search(r"'url':\s*(.*?)(?:,|\})", block)
                if url_match:
                    url_expr = url_match.group(1).strip()
                    resolved = resolve_url_expr(url_expr)
                    if "@" in resolved:
                        url, commit = resolved.rsplit("@", 1)
                        url = url.strip()
                        commit = commit.strip()
                        if len(commit) >= 20:  # valid hash
                            deps[dep_name] = {
                                "url": url,
                                "commit": commit,
                                "path": f"third_party/{dep_path}",
                            }
            # Format 1: simple string value (possibly with Var())
            elif "@" in rest:
                resolved = resolve_url_expr(rest)
                if "@" in resolved:
                    url, commit = resolved.rsplit("@", 1)
                    url = url.strip()
                    commit = commit.strip()
                    if len(commit) >= 20:  # valid hash
                        deps[dep_name] = {
                            "url": url,
                            "commit": commit,
                            "path": f"third_party/{dep_path}",
                        }
        i += 1

    return deps


def generate_fetch_script(version: str, deps: dict) -> str:
    """Generate the fetch_deps.py script content."""
    # Map dep names to our expected directory structure
    known_deps = {
        "abseil-cpp": "abseil-cpp",
        "icu": "icu",
        "zlib": "zlib",
        "googletest": "googletest",
        "highway": "highway",
        "simdutf": "simdutf",
        "fp16": "fp16",
        "dragonbox": "dragonbox",
        "fast_float": "fast_float",
    }

    deps_entries = []
    for name, info in sorted(deps.items()):
        mapped = known_deps.get(name)
        if mapped:
            dep_path = info.get("path", f"third_party/{name}")
            deps_entries.append(
                f'    "{mapped}": {{\n'
                f'        "url": "{info["url"]}",\n'
                f'        "commit": "{info["commit"]}",\n'
                f'        "path": "v8-src/{dep_path}",\n'
                f"    }},"
            )

    deps_block = "\n".join(deps_entries)

    return f'''#!/usr/bin/env python3
"""Fetch pinned V8 {version} source and third-party dependencies.

Auto-generated by scripts/generate_fetch_deps.py
"""

import os
import subprocess

V8_VERSION = "{version}"
V8_REPO = "https://chromium.googlesource.com/v8/v8.git"
V8_DIR = "v8-src"

DEPS = {{
{deps_block}
}}


def run(cmd, cwd=None, capture_output=False):
    print(f"  > {{' '.join(cmd)}}")
    if capture_output:
        return subprocess.check_output(cmd, cwd=cwd, text=True).strip()
    subprocess.check_call(cmd, cwd=cwd)
    return ""


def is_git_repo(path):
    return os.path.isdir(os.path.join(path, ".git"))


def ensure_commit(repo_path, commit):
    has_commit = subprocess.call(
        ["git", "cat-file", "-e", f"{{commit}}^{{{{commit}}}}"],
        cwd=repo_path,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if has_commit != 0:
        run(["git", "fetch", "--depth=1", "origin", commit], cwd=repo_path)
    run(["git", "checkout", "--force", commit], cwd=repo_path)


def ensure_v8_checkout(v8_path, v8_version):
    if os.path.exists(v8_path):
        if not is_git_repo(v8_path):
            raise RuntimeError(f"{{v8_path}} exists but is not a git repo.")
        print(f"  Existing V8 checkout found: {{v8_path}}")
        run(
            [
                "git",
                "fetch",
                "--depth=1",
                "origin",
                f"refs/tags/{{v8_version}}:refs/tags/{{v8_version}}",
            ],
            cwd=v8_path,
        )
        run(["git", "checkout", "--force", f"refs/tags/{{v8_version}}"], cwd=v8_path)
        return

    run(["git", "clone", "--depth=1", "--branch", v8_version, V8_REPO, v8_path])


def ensure_dep(dep_name, dep_info):
    dep_path = dep_info["path"]
    dep_dir = os.path.dirname(dep_path)
    os.makedirs(dep_dir, exist_ok=True)
    commit = dep_info["commit"]
    url = dep_info["url"]

    print(f"\\n=== Fetching {{dep_name}} ===")
    if os.path.exists(dep_path):
        if not is_git_repo(dep_path):
            raise RuntimeError(
                f"{{dep_path}} exists but is not a git repo. Remove it and retry."
            )
        ensure_commit(dep_path, commit)
        return

    run(["git", "clone", "--depth=1", url, dep_path])
    ensure_commit(dep_path, commit)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    v8_path = os.path.join(script_dir, V8_DIR)

    print(f"\\n=== Ensuring V8 {{V8_VERSION}} ===")
    ensure_v8_checkout(v8_path, V8_VERSION)

    for dep_name, dep_info in DEPS.items():
        dep_info["path"] = os.path.join(script_dir, dep_info["path"])
        ensure_dep(dep_name, dep_info)

    head = run(["git", "rev-parse", "--short", "HEAD"], cwd=v8_path, capture_output=True)
    print("\\n=== All dependencies fetched successfully ===")
    print(f"V8 source is at: {{v8_path}}")
    print(f"V8 HEAD: {{head}} (expected tag {{V8_VERSION}})")


if __name__ == "__main__":
    main()
'''


def main():
    parser = argparse.ArgumentParser(
        description="Generate fetch_deps.py for a V8 version"
    )
    parser.add_argument("--version", required=True, help="V8 version (e.g., 13.6.233.17)")
    parser.add_argument("--output", default="fetch_deps.py", help="Output file path")
    parser.add_argument("--deps-file", help="Use local DEPS file instead of fetching")
    args = parser.parse_args()

    if args.deps_file:
        with open(args.deps_file, "r") as f:
            deps_content = f.read()
    else:
        print(f"Fetching DEPS for V8 {args.version}...")
        deps_content = fetch_deps_file(args.version)
        if deps_content is None:
            print(f"Error: Could not fetch DEPS for V8 {args.version}", file=sys.stderr)
            sys.exit(1)

    deps = parse_deps(deps_content)
    print(f"Found {len(deps)} third-party dependencies")
    for name in sorted(deps.keys()):
        print(f"  - {name}: {deps[name]['commit'][:12]}")

    script = generate_fetch_script(args.version, deps)
    with open(args.output, "w") as f:
        f.write(script)
    print(f"\nGenerated {args.output}")


if __name__ == "__main__":
    main()
