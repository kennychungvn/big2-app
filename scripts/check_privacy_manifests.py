#!/usr/bin/env python3
"""Validate every PrivacyInfo.xcprivacy under the given paths (files or dirs).

Apple's upload/review validator (ITMS-91064) treats the two tracking keys as a pair:
  * NSPrivacyTrackingDomains non-empty  -> NSPrivacyTracking must be true
  * NSPrivacyTracking true              -> NSPrivacyTrackingDomains must be non-empty
The email only spells out the first rule but is sent for both. Exit 1 on any problem.
"""
import pathlib
import plistlib
import subprocess
import sys


def manifests(paths):
    for p in map(pathlib.Path, paths):
        if p.is_file():
            yield p, p.parent
        else:
            for f in sorted(p.rglob("PrivacyInfo.xcprivacy")):
                yield f, p


def main(argv):
    if not argv:
        sys.exit("usage: check_privacy_manifests.py <path> [<path>...]")
    found = bad = 0
    for f, root in manifests(argv):
        found += 1
        rel = f.relative_to(root) if root in f.parents else f
        if sys.platform == "darwin":
            lint = subprocess.run(["plutil", "-lint", str(f)], capture_output=True, text=True)
            if lint.returncode != 0:
                print(f"::error::plutil -lint failed: {rel}: {lint.stdout.strip()} {lint.stderr.strip()}")
                bad += 1
                continue
        try:
            with open(f, "rb") as fh:
                data = plistlib.load(fh)
        except Exception as exc:  # noqa: BLE001
            print(f"::error::Cannot parse {rel}: {exc}")
            bad += 1
            continue
        tracking = data.get("NSPrivacyTracking")
        domains = data.get("NSPrivacyTrackingDomains") or []
        print(f"{rel}: NSPrivacyTracking={tracking!r} NSPrivacyTrackingDomains={domains!r}")
        if domains and tracking is not True:
            print(f"::error::{rel}: NSPrivacyTrackingDomains is not empty but NSPrivacyTracking is not true (ITMS-91064).")
            bad += 1
        if tracking is True and not domains:
            print(f"::error::{rel}: NSPrivacyTracking is true but NSPrivacyTrackingDomains is empty (Apple rejects this as ITMS-91064).")
            bad += 1
    if found == 0:
        print("::error::No PrivacyInfo.xcprivacy found.")
        return 1
    print(f"Checked {found} privacy manifest(s); {bad} problem(s).")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
