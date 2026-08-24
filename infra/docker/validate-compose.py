#!/usr/bin/env python3
"""
validate-compose.py  --  Strict YAML duplicate-key validator for docker-compose.yml
=====================================================================================
Usage:
    python infra/docker/validate-compose.py
    python infra/docker/validate-compose.py --path path/to/docker-compose.yml

PyYAML's safe_load silently deduplicates keys, hiding errors.
This script uses a custom Loader that raises on any duplicate key at any depth.

Exit codes:
    0  -- no duplicate keys, YAML is valid
    1  -- duplicate key found or YAML parse error
"""
import argparse
import sys
import yaml


class DuplicateKeyError(Exception):
    pass


class StrictLoader(yaml.SafeLoader):
    """SafeLoader variant that raises DuplicateKeyError on repeated mapping keys."""
    pass


def _construct_mapping_strict(loader, node):
    loader.flatten_mapping(node)
    pairs = loader.construct_pairs(node)
    seen = []
    for key, _ in pairs:
        if key in seen:
            raise DuplicateKeyError(
                f"Duplicate YAML key {key!r} at line {node.start_mark.line + 1}"
            )
        seen.append(key)
    return dict(pairs)


StrictLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_mapping_strict,
)


def validate(path: str) -> bool:
    try:
        with open(path, encoding="utf-8") as fh:
            content = fh.read()
        yaml.load(content, Loader=StrictLoader)
        print(f"PASS  No duplicate keys in: {path}")
        return True
    except DuplicateKeyError as exc:
        print(f"FAIL  Duplicate key -- {path}: {exc}", file=sys.stderr)
        return False
    except yaml.YAMLError as exc:
        print(f"FAIL  YAML parse error -- {path}: {exc}", file=sys.stderr)
        return False
    except OSError as exc:
        print(f"FAIL  Cannot open file -- {path}: {exc}", file=sys.stderr)
        return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Strict YAML duplicate-key validator")
    parser.add_argument(
        "--path",
        default="infra/docker/docker-compose.yml",
        help="Path to the docker-compose.yml to validate",
    )
    args = parser.parse_args()
    sys.exit(0 if validate(args.path) else 1)
