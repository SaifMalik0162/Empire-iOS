#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from typing import Dict, List, Optional, Tuple


CONFIGS = {
    "avatars": {
        "bucket": "avatars",
        "max_dimension": 256,
        "max_bytes": 140_000,
        "quality": 55,
    },
    "community": {
        "bucket": "car-photos",
        "max_dimension": 1280,
        "max_bytes": 420_000,
        "quality": 48,
    },
    "cars": {
        "bucket": "car-photos",
        "max_dimension": 1400,
        "max_bytes": 500_000,
        "quality": 50,
    },
}


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        print(f"Missing required env var: {name}", file=sys.stderr)
        sys.exit(1)
    return value


def request_json(url: str, headers: Dict[str, str]) -> List[dict]:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode("utf-8"))


def download_file(url: str, headers: Dict[str, str], destination: str) -> None:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response, open(destination, "wb") as output:
        shutil.copyfileobj(response, output)


def upload_file(url: str, headers: Dict[str, str], source: str) -> None:
    with open(source, "rb") as handle:
        data = handle.read()
    request = urllib.request.Request(url, data=data, method="POST")
    for key, value in headers.items():
        request.add_header(key, value)
    with urllib.request.urlopen(request):
        return


def optimize_with_sips(source: str, destination: str, max_dimension: int, quality: int) -> None:
    subprocess.run(
        [
            "sips",
            "-s",
            "format",
            "jpeg",
            "-s",
            "formatOptions",
            str(quality),
            "-Z",
            str(max_dimension),
            source,
            "--out",
            destination,
        ],
        check=True,
        capture_output=True,
    )


def fetch_avatar_paths(base_url: str, headers: Dict[str, str], limit: Optional[int]) -> List[str]:
    url = (
        f"{base_url}/rest/v1/profiles"
        "?select=avatar_path"
        "&avatar_path=not.is.null"
        "&avatar_path=not.eq."
    )
    if limit:
        url += f"&limit={limit}"
    rows = request_json(url, headers)
    return [row["avatar_path"] for row in rows if row.get("avatar_path")]


def fetch_community_paths(base_url: str, headers: Dict[str, str], limit: Optional[int]) -> List[str]:
    url = (
        f"{base_url}/rest/v1/community_posts"
        "?select=photo_path,photo_paths"
        "&or=(photo_path.not.is.null,photo_paths.not.is.null)"
    )
    if limit:
        url += f"&limit={limit}"
    rows = request_json(url, headers)
    paths: List[str] = []
    for row in rows:
        if row.get("photo_path"):
            paths.append(row["photo_path"])
        for path in row.get("photo_paths") or []:
            if path:
                paths.append(path)
    return paths


def fetch_car_paths(base_url: str, headers: Dict[str, str], limit: Optional[int]) -> List[str]:
    url = f"{base_url}/rest/v1/cars?select=photo_path&photo_path=not.is.null"
    if limit:
        url += f"&limit={limit}"
    rows = request_json(url, headers)
    return [row["photo_path"] for row in rows if row.get("photo_path")]


def unique_preserving_order(values: List[str]) -> List[str]:
    seen: set = set()
    result: List[str] = []
    for value in values:
        trimmed = value.strip()
        if not trimmed or trimmed in seen:
            continue
        seen.add(trimmed)
        result.append(trimmed)
    return result


def process_scope(
    scope: str,
    paths: List[str],
    base_url: str,
    auth_headers: Dict[str, str],
    dry_run: bool,
) -> Tuple[int, int, int]:
    config = CONFIGS[scope]
    bucket = config["bucket"]
    max_dimension = config["max_dimension"]
    max_bytes = config["max_bytes"]
    quality = config["quality"]

    optimized_count = 0
    skipped_count = 0
    failed_count = 0

    with tempfile.TemporaryDirectory(prefix="empire-backfill-") as tempdir:
        for index, path in enumerate(paths, start=1):
            encoded_path = "/".join(urllib.parse.quote(part, safe="") for part in path.split("/"))
            public_url = f"{base_url}/storage/v1/object/public/{bucket}/{encoded_path}"
            upload_url = f"{base_url}/storage/v1/object/{bucket}/{encoded_path}"

            original_path = os.path.join(tempdir, f"{scope}-{index}-original")
            optimized_path = os.path.join(tempdir, f"{scope}-{index}-optimized.jpg")

            try:
                download_file(public_url, auth_headers, original_path)
                original_size = os.path.getsize(original_path)

                optimize_with_sips(
                    original_path,
                    optimized_path,
                    max_dimension=max_dimension,
                    quality=quality,
                )
                optimized_size = os.path.getsize(optimized_path)

                if optimized_size >= original_size or optimized_size > max_bytes:
                    skipped_count += 1
                    print(
                        f"[{scope}] skip {path} "
                        f"(original={original_size} optimized={optimized_size} max={max_bytes})"
                    )
                    continue

                if dry_run:
                    optimized_count += 1
                    print(
                        f"[{scope}] dry-run optimize {path} "
                        f"({original_size} -> {optimized_size})"
                    )
                    continue

                upload_headers = {
                    **auth_headers,
                    "Content-Type": "image/jpeg",
                    "x-upsert": "true",
                    "cache-control": "3600",
                }
                upload_file(upload_url, upload_headers, optimized_path)
                optimized_count += 1
                print(f"[{scope}] optimized {path} ({original_size} -> {optimized_size})")
            except Exception as error:
                failed_count += 1
                print(f"[{scope}] failed {path}: {error}", file=sys.stderr)

    return optimized_count, skipped_count, failed_count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Backfill and recompress existing Supabase-hosted images in place."
    )
    parser.add_argument(
        "--scope",
        choices=["avatars", "community", "cars", "all"],
        default="all",
        help="Which image set to process.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional per-scope row limit for smaller trial runs.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Download and optimize without uploading replacements.",
    )
    args = parser.parse_args()

    base_url = require_env("SUPABASE_URL").rstrip("/")
    service_role_key = require_env("SUPABASE_SERVICE_ROLE_KEY")

    auth_headers = {
        "Authorization": f"Bearer {service_role_key}",
        "apikey": service_role_key,
    }
    rest_headers = {
        **auth_headers,
        "Accept": "application/json",
    }

    scopes = ["avatars", "community", "cars"] if args.scope == "all" else [args.scope]

    fetchers = {
        "avatars": fetch_avatar_paths,
        "community": fetch_community_paths,
        "cars": fetch_car_paths,
    }

    total_optimized = 0
    total_skipped = 0
    total_failed = 0

    for scope in scopes:
        paths = unique_preserving_order(fetchers[scope](base_url, rest_headers, args.limit))
        print(f"[{scope}] found {len(paths)} unique paths")
        optimized, skipped, failed = process_scope(
            scope=scope,
            paths=paths,
            base_url=base_url,
            auth_headers=auth_headers,
            dry_run=args.dry_run,
        )
        total_optimized += optimized
        total_skipped += skipped
        total_failed += failed

    print(
        "Done:"
        f" optimized={total_optimized}"
        f" skipped={total_skipped}"
        f" failed={total_failed}"
        f" dry_run={args.dry_run}"
    )


if __name__ == "__main__":
    main()
