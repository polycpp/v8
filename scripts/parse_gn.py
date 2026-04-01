#!/usr/bin/env python3
"""Lightweight GN (Generate Ninja) file parser for V8 BUILD.gn.

This is NOT a full GN evaluator. It extracts source file lists from
source_set/static_library/executable targets with basic conditional support.

Supported conditionals:
  - is_win, is_posix, is_linux, is_mac, is_android
  - target_cpu == "x64", target_cpu == "arm64", etc.
  - v8_enable_webassembly, v8_enable_i18n_support, v8_enable_maglev, etc.
  - v8_current_cpu == "x64"
"""

import os
import re
from typing import Dict, List, Optional, Set, Tuple


class GnCondition:
    """Represents a GN conditional context."""

    # Default values for our target platform (Windows x64)
    DEFAULTS = {
        "is_win": True,
        "is_posix": False,
        "is_linux": False,
        "is_mac": False,
        "is_android": False,
        "is_ios": False,
        "is_fuchsia": False,
        "is_chromeos": False,
        "is_debug": False,
        "target_cpu": "x64",
        "v8_current_cpu": "x64",
        "v8_target_cpu": "x64",
        "host_cpu": "x64",
        "current_cpu": "x64",
        # Feature flags (can be overridden)
        "v8_enable_webassembly": True,
        "v8_enable_i18n_support": True,
        "v8_enable_maglev": True,
        "v8_enable_turbofan": True,
        "v8_enable_sparkplug": True,
        "v8_enable_pointer_compression": True,
        "v8_enable_sandbox": False,
        "v8_enable_etw_stack_walking": True,
        "v8_enable_snapshot": True,
        "v8_use_external_startup_data": False,
    }

    def __init__(self, overrides=None):
        self.vars = dict(self.DEFAULTS)
        if overrides:
            self.vars.update(overrides)

    def evaluate(self, condition_str: str) -> Optional[bool]:
        """Evaluate a simple GN condition string. Returns None if cannot parse."""
        cond = condition_str.strip()

        # Handle negation
        if cond.startswith("!"):
            inner = self.evaluate(cond[1:])
            return None if inner is None else not inner

        # Handle == comparison
        m = re.match(r'(\w+)\s*==\s*"([^"]*)"', cond)
        if m:
            var, val = m.group(1), m.group(2)
            if var in self.vars:
                return str(self.vars[var]) == val
            return None

        # Handle != comparison
        m = re.match(r'(\w+)\s*!=\s*"([^"]*)"', cond)
        if m:
            var, val = m.group(1), m.group(2)
            if var in self.vars:
                return str(self.vars[var]) != val
            return None

        # Handle boolean variable
        if cond in self.vars:
            return bool(self.vars[cond])

        # Handle && (both must be true)
        if "&&" in cond:
            parts = cond.split("&&", 1)
            left = self.evaluate(parts[0])
            right = self.evaluate(parts[1])
            if left is False or right is False:
                return False
            if left is True and right is True:
                return True
            return None

        # Handle || (either can be true)
        if "||" in cond:
            parts = cond.split("||", 1)
            left = self.evaluate(parts[0])
            right = self.evaluate(parts[1])
            if left is True or right is True:
                return True
            if left is False and right is False:
                return False
            return None

        return None  # Cannot evaluate


class GnParser:
    """Parse GN build files and extract source lists."""

    def __init__(self, filepath: str, condition: GnCondition = None):
        self.filepath = filepath
        self.condition = condition or GnCondition()
        with open(filepath, "r", errors="ignore") as f:
            self.content = f.read()
        self.lines = self.content.split("\n")

    def get_targets(self) -> List[Tuple[str, str]]:
        """Return list of (type, name) for all targets."""
        targets = []
        pattern = r'(source_set|static_library|executable|v8_source_set|v8_component)\("([^"]+)"\)'
        for m in re.finditer(pattern, self.content):
            targets.append((m.group(1), m.group(2)))
        return targets

    def get_sources(self, target_name: str) -> List[str]:
        """Extract source files for a named target, respecting conditionals."""
        # Find the target block
        block = self._find_target_block(target_name)
        if block is None:
            return []
        return self._extract_sources_from_block(block)

    def get_all_sources(self) -> Dict[str, List[str]]:
        """Extract sources for all targets."""
        result = {}
        for ttype, tname in self.get_targets():
            sources = self.get_sources(tname)
            if sources:
                result[tname] = sources
        return result

    def get_torque_files(self) -> List[str]:
        """Extract .tq file lists (torque sources)."""
        tq_files = []
        # Look for torque_files = [...] or similar patterns
        in_tq_list = False
        for line in self.lines:
            stripped = line.strip()
            if re.match(r'torque_files\s*=\s*\[', stripped) or \
               re.match(r'torque_sources\s*=\s*\[', stripped):
                in_tq_list = True
                continue
            if in_tq_list:
                if stripped == "]":
                    in_tq_list = False
                    continue
                m = re.match(r'"([^"]+\.tq)"', stripped.rstrip(","))
                if m:
                    tq_files.append(m.group(1))
        return tq_files

    def _find_target_block(self, target_name: str) -> Optional[str]:
        """Find the { ... } block for a target definition."""
        # Pattern: type("name") {
        patterns = [
            rf'(?:source_set|static_library|executable|v8_source_set|v8_component)\("{re.escape(target_name)}"\)\s*\{{',
        ]
        for pattern in patterns:
            m = re.search(pattern, self.content)
            if m:
                start = m.end()
                return self._extract_balanced_block(start)
        return None

    def _extract_balanced_block(self, start_pos: int) -> str:
        """Extract content of a balanced { } block starting after the opening {."""
        depth = 1
        pos = start_pos
        while pos < len(self.content) and depth > 0:
            ch = self.content[pos]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            pos += 1
        return self.content[start_pos : pos - 1]

    def _extract_sources_from_block(self, block: str) -> List[str]:
        """Extract source file paths from a block, respecting if conditions."""
        sources = []
        lines = block.split("\n")
        i = 0
        condition_stack = []  # Stack of (condition_result, is_else_branch)

        while i < len(lines):
            line = lines[i].strip()
            i += 1

            # Handle if/else if/else
            m = re.match(r'if\s*\((.+)\)\s*\{', line)
            if m:
                result = self.condition.evaluate(m.group(1))
                condition_stack.append((result, False))
                continue

            if line.startswith("} else if"):
                m = re.match(r'\}\s*else\s+if\s*\((.+)\)\s*\{', line)
                if m and condition_stack:
                    prev_result, _ = condition_stack[-1]
                    if prev_result is True:
                        # Previous branch was taken, skip this
                        condition_stack[-1] = (False, True)
                    else:
                        result = self.condition.evaluate(m.group(1))
                        condition_stack[-1] = (result, True)
                continue

            if line == "} else {":
                if condition_stack:
                    prev_result, _ = condition_stack[-1]
                    if prev_result is True:
                        condition_stack[-1] = (False, True)
                    else:
                        condition_stack[-1] = (True, True)
                continue

            if line == "}" and condition_stack:
                condition_stack.pop()
                continue

            # Check if we're in an excluded conditional
            if condition_stack and any(r is False for r, _ in condition_stack):
                continue

            # Extract source file strings
            m = re.match(r'"([^"]+\.(?:cc|c|cpp|S|asm))"', line.rstrip(","))
            if m:
                sources.append(m.group(1))
                continue

            # Handle sources = [...] or sources += [...]
            if re.match(r'sources\s*\+?=\s*\[', line):
                # Inline list may span multiple lines
                if "]" not in line:
                    # Multi-line list
                    while i < len(lines):
                        inner = lines[i].strip()
                        i += 1
                        if inner == "]":
                            break
                        m = re.match(r'"([^"]+\.(?:cc|c|cpp|S|asm))"', inner.rstrip(","))
                        if m:
                            sources.append(m.group(1))

        return sources


def main():
    """CLI: parse a BUILD.gn and print sources per target."""
    import argparse
    import json

    parser = argparse.ArgumentParser(description="Parse GN build file")
    parser.add_argument("gn_file", help="Path to BUILD.gn")
    parser.add_argument("--target", help="Specific target to extract")
    parser.add_argument("--torque", action="store_true", help="Extract torque files")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    gn = GnParser(args.gn_file)

    if args.torque:
        files = gn.get_torque_files()
        if args.json:
            print(json.dumps(files, indent=2))
        else:
            for f in files:
                print(f)
    elif args.target:
        sources = gn.get_sources(args.target)
        if args.json:
            print(json.dumps(sources, indent=2))
        else:
            for s in sources:
                print(s)
    else:
        all_sources = gn.get_all_sources()
        if args.json:
            print(json.dumps(all_sources, indent=2))
        else:
            for target, sources in sorted(all_sources.items()):
                print(f"\n=== {target} ({len(sources)} files) ===")
                for s in sources:
                    print(f"  {s}")


if __name__ == "__main__":
    main()
