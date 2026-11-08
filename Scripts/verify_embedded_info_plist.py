#!/usr/bin/env python3
"""Check that an agenda binary embeds the EventKit usage strings.

The release binary must carry Sources/Agenda/Info.plist in the Mach-O
section __TEXT,__info_plist. This script decodes `otool -s __TEXT __info_plist`
output and checks the plist keys. It also checks that codesign still reports
an ad-hoc signature and a bound Info.plist.

--self-test runs against synthetic otool and codesign fixtures and does not
read a binary, a calendar, or a reminder.
"""

from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys
from pathlib import Path

BUNDLE_IDENTIFIER = "cloud.rives.agenda"
REQUIRED_KEYS = (
    "CFBundleIdentifier",
    "CFBundleName",
    "CFBundleShortVersionString",
    "NSCalendarsFullAccessUsageDescription",
    "NSRemindersFullAccessUsageDescription",
    "NSCalendarsUsageDescription",
    "NSRemindersUsageDescription",
)


class VerifyError(Exception):
    """The binary or a fixture failed a check."""


def is_hex_group(token: str) -> bool:
    if token == "" or len(token) > 8 or len(token) % 2 != 0:
        return False
    return all(character in "0123456789abcdefABCDEF" for character in token)


def otool_token_bytes(token: str) -> bytes:
    """Turn one `otool -s` hex group back into section bytes.

    On little-endian hosts (Apple silicon and Intel), `otool -s` prints each
    full 4-byte group as a native uint32, so the bytes inside an 8-digit group
    are reversed. A short trailing group is printed as raw bytes, in order.
    """
    raw = bytes.fromhex(token)
    if len(raw) == 4:
        return raw[::-1]
    return raw


def decode_otool_section(text: str) -> bytes:
    """Decode the hex dump from `otool -s __TEXT __info_plist`."""
    if "(__TEXT,__info_plist)" not in text:
        raise VerifyError("otool output has no __TEXT,__info_plist section")

    blob = bytearray()
    started = False
    for line in text.splitlines():
        if "(__TEXT,__info_plist)" in line:
            started = True
            continue
        if not started:
            continue
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("Contents of"):
            break
        tokens = stripped.split()
        if len(tokens) < 2:
            continue
        address = tokens[0].rstrip(":")
        if not address or not all(character in "0123456789abcdefABCDEF" for character in address):
            continue
        for token in tokens[1:]:
            if is_hex_group(token):
                blob.extend(otool_token_bytes(token))
            else:
                break

    if not blob:
        raise VerifyError("__TEXT,__info_plist section was empty")

    data = bytes(blob)
    end_tag = b"</plist>"
    if end_tag in data:
        data = data[: data.index(end_tag) + len(end_tag)]
    else:
        data = data.rstrip(b"\x00")
    return data


def load_plist(data: bytes) -> dict:
    try:
        parsed = plistlib.loads(data)
    except Exception as error:  # plistlib raises several exception types
        raise VerifyError(f"embedded section is not a plist: {error}") from error
    if not isinstance(parsed, dict):
        raise VerifyError("embedded plist is not a dictionary")
    return parsed


def require_keys(plist: dict) -> None:
    missing = []
    for key in REQUIRED_KEYS:
        value = plist.get(key)
        if not isinstance(value, str) or not value.strip():
            missing.append(key)
    if missing:
        raise VerifyError("embedded plist is missing keys: " + ", ".join(missing))
    if plist.get("CFBundleIdentifier") != BUNDLE_IDENTIFIER:
        raise VerifyError(
            "CFBundleIdentifier is "
            f"{plist.get('CFBundleIdentifier')!r}, expected {BUNDLE_IDENTIFIER!r}"
        )


def assert_adhoc_and_bound(codesign_output: str) -> None:
    if "Info.plist=not bound" in codesign_output:
        raise VerifyError("codesign reports Info.plist=not bound")
    if "Info.plist entries=" not in codesign_output:
        raise VerifyError("codesign did not report Info.plist entries")
    if "(adhoc" not in codesign_output and "Signature=adhoc" not in codesign_output:
        raise VerifyError("codesign did not report an ad-hoc signature")
    if f"Identifier={BUNDLE_IDENTIFIER}" not in codesign_output:
        raise VerifyError(
            f"codesign Identifier is not {BUNDLE_IDENTIFIER}; the embedded plist is not bound"
        )


def format_as_otool(data: bytes) -> str:
    """Build an `otool -s` dump the way little-endian macOS prints it."""
    lines = ["./agenda:", "Contents of (__TEXT,__info_plist) section"]
    address = 0x100000000
    for offset in range(0, len(data), 16):
        chunk = data[offset : offset + 16]
        words: list[str] = []
        index = 0
        while index < len(chunk):
            piece = chunk[index : index + 4]
            if len(piece) == 4:
                words.append(piece[::-1].hex())
            else:
                words.extend(f"{byte:02x}" for byte in piece)
            index += 4
        lines.append(f"{address:016x}\t" + " ".join(words))
        address += 16
    return "\n".join(lines) + "\n"


def run_self_test() -> None:
    plist = {
        "CFBundleIdentifier": BUNDLE_IDENTIFIER,
        "CFBundleName": "Agenda",
        "CFBundleShortVersionString": "0.2.0",
        "NSCalendarsFullAccessUsageDescription": "Agenda reads and updates Calendar events when you ask it to.",
        "NSRemindersFullAccessUsageDescription": "Agenda reads and updates Reminders when you ask it to.",
        "NSCalendarsUsageDescription": "Agenda reads and updates Calendar events when you ask it to.",
        "NSRemindersUsageDescription": "Agenda reads and updates Reminders when you ask it to.",
    }
    payload = plistlib.dumps(plist, fmt=plistlib.FMT_XML)
    decoded = load_plist(decode_otool_section(format_as_otool(payload)))
    require_keys(decoded)

    # First and last lines from a real macos-15 `otool -s` dump. Each 8-digit
    # group is a little-endian word; the short tail is raw bytes.
    observed = """\
.build/release/agenda:
Contents of (__TEXT,__info_plist) section
000000010007f1c4	6d783f3c 6576206c 6f697372 31223d6e 
000000010007f654	74732f3c 676e6972 2f3c0a3e 73696c70 74 3e 0a 
"""
    observed_bytes = decode_otool_section(observed)
    if not observed_bytes.startswith(b"<?xml version=\"1"):
        raise VerifyError(f"self-test: header decoded as {observed_bytes[:16]!r}")
    if not observed_bytes.endswith(b"</plist>"):
        raise VerifyError(f"self-test: tail decoded as {observed_bytes[-16:]!r}")

    try:
        decode_otool_section("./agenda:\n")
    except VerifyError:
        pass
    else:
        raise VerifyError("self-test: missing section was accepted")

    incomplete = dict(plist)
    del incomplete["NSCalendarsFullAccessUsageDescription"]
    try:
        require_keys(load_plist(plistlib.dumps(incomplete, fmt=plistlib.FMT_XML)))
    except VerifyError:
        pass
    else:
        raise VerifyError("self-test: missing usage key was accepted")

    bound = "\n".join(
        [
            f"Identifier={BUNDLE_IDENTIFIER}",
            "Signature=adhoc",
            "flags=0x20002(adhoc,linker-signed)",
            "Info.plist entries=11",
        ]
    )
    assert_adhoc_and_bound(bound)

    for sample, label in (
        ("Identifier=agenda\nSignature=adhoc\nInfo.plist=not bound\n", "not bound"),
        (f"Identifier={BUNDLE_IDENTIFIER}\nSignature=adhoc\n", "no entries"),
        (
            f"Identifier={BUNDLE_IDENTIFIER}\nInfo.plist entries=11\n",
            "no adhoc",
        ),
    ):
        try:
            assert_adhoc_and_bound(sample)
        except VerifyError:
            pass
        else:
            raise VerifyError(f"self-test: {label} sample was accepted")

    print("info plist verifier self-test passed")


def read_otool_output(binary: Path, otool_output: Path | None) -> str:
    if otool_output is not None:
        return otool_output.read_text(encoding="utf-8", errors="replace")
    completed = subprocess.run(
        ["otool", "-s", "__TEXT", "__info_plist", str(binary)],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise VerifyError(completed.stderr.strip() or "otool failed")
    return completed.stdout


def verify_binary(binary: Path, otool_output: Path | None) -> None:
    if not binary.is_file():
        raise VerifyError(f"binary not found: {binary}")
    section = decode_otool_section(read_otool_output(binary, otool_output))
    require_keys(load_plist(section))

    completed = subprocess.run(
        ["codesign", "-d", "--verbose=4", str(binary)],
        check=False,
        capture_output=True,
        text=True,
    )
    details = completed.stdout + completed.stderr
    if completed.returncode != 0 and "Identifier=" not in details:
        raise VerifyError(details.strip() or "codesign failed")
    assert_adhoc_and_bound(details)
    print(f"embedded Info.plist ok: {binary}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--binary", type=Path)
    parser.add_argument(
        "--otool-output",
        type=Path,
        help="Use this `otool -s __TEXT __info_plist` dump instead of running otool",
    )
    args = parser.parse_args(argv)

    try:
        if args.self_test:
            run_self_test()
        if args.binary is not None:
            verify_binary(args.binary, args.otool_output)
        if not args.self_test and args.binary is None:
            parser.error("pass --self-test, --binary, or both")
    except VerifyError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
