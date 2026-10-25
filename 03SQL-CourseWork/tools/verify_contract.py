#!/usr/bin/env python3
"""Check that the documented coursework API matches the registered Go routes."""

from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
METHODS = {"get", "post", "put", "patch", "delete"}
ROUTE = re.compile(r'mux\.HandleFunc\("(GET|POST|PUT|PATCH|DELETE) (/api/v1/[^\"]+)"')


class UniqueKeyLoader(yaml.SafeLoader):
    """Reject duplicate YAML keys instead of silently losing an operation."""


def construct_mapping(loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"duplicate YAML key: {key!r} at line {key_node.start_mark.line + 1}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping
)


def resolve_ref(document: dict, ref: str):
    if not isinstance(ref, str) or not ref.startswith("#/"):
        raise ValueError(f"unsupported external reference: {ref!r}")
    value = document
    for part in ref[2:].split("/"):
        key = part.replace("~1", "/").replace("~0", "~")
        if not isinstance(value, dict) or key not in value:
            raise ValueError(f"unresolved reference: {ref}")
        value = value[key]
    return value


def walk_refs(document: dict, value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "$ref":
                resolve_ref(document, child)
            walk_refs(document, child)
    elif isinstance(value, list):
        for child in value:
            walk_refs(document, child)


def parameters(document: dict, entries: list) -> set[str]:
    names = set()
    for entry in entries:
        parameter = resolve_ref(document, entry["$ref"]) if "$ref" in entry else entry
        if parameter.get("in") == "path":
            if parameter.get("required") is not True:
                raise ValueError(f"path parameter must be required: {parameter.get('name')}")
            names.add(parameter["name"])
    return names


def main() -> int:
    document = yaml.load((ROOT / "api/openapi.yaml").read_text(encoding="utf-8"), Loader=UniqueKeyLoader)
    if document.get("openapi") != "3.1.0":
        raise ValueError("expected OpenAPI 3.1.0")
    walk_refs(document, document)

    documented = set()
    planned = set()
    for path, item in document["paths"].items():
        path_variables = set(re.findall(r"\{([^{}]+)\}", path))
        for method, operation in item.items():
            if method not in METHODS:
                continue
            status = operation.get("x-implementation-status")
            if status not in {"implemented", "unavailable", "planned"}:
                raise ValueError(f"unknown implementation status: {method.upper()} {path}: {status!r}")
            if not operation.get("summary") or not operation.get("responses"):
                raise ValueError(f"missing summary or responses: {method.upper()} {path}")
            declared = parameters(document, item.get("parameters", []) + operation.get("parameters", []))
            if path_variables != declared:
                raise ValueError(f"path parameters differ for {method.upper()} {path}: expected {sorted(path_variables)}, found {sorted(declared)}")
            route = (method.upper(), "/api" + path)
            if status == "planned":
                planned.add(route)
            else:
                documented.add(route)

    go_source = (ROOT / "backend/main.go").read_text(encoding="utf-8")
    registered = set(ROUTE.findall(go_source))
    missing = sorted(registered - documented)
    extra = sorted(documented - registered)
    if missing or extra:
        raise ValueError(f"Go routes absent from OpenAPI: {missing}; OpenAPI routes absent from Go: {extra}")
    if registered & planned:
        raise ValueError(f"planned routes are already registered in Go: {sorted(registered & planned)}")

    rag_responses = document["paths"]["/v1/rag/queries"]["post"]["responses"]
    if "201" not in rag_responses or "503" not in rag_responses:
        raise ValueError("RAG query must document both completed and unavailable responses")
    print(f"OpenAPI contract: {len(documented)} Go routes match; all local references and path parameters resolve")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyError, TypeError, ValueError, yaml.YAMLError) as error:
        print(f"OpenAPI contract invalid: {error}", file=sys.stderr)
        sys.exit(1)
