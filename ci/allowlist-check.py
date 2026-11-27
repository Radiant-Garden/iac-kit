#!/usr/bin/env python3
"""Fail if a file in the repository names a host or address outside the allowlist.

The kit is public and must not contain customer data. This is an allowlist, not
a denylist of customer names (a denylist would itself publish them):

- IPv4/IPv6 literals must lie in the documentation ranges (RFC 5737, RFC 3849),
  the shared address space (RFC 6598), loopback or the unspecified address.
- Names under a real TLD must equal or end in a domain from ci/allowlist.txt.
  Only names under the TLDs below are checked, so file names (catalog.yml,
  main.tf) and code paths (module.catalog.site, var.catalog) are not domains;
  a dotted token whose first label is a known code root is skipped as well.

Usage: ci/allowlist-check.py [files...]   (default: every file git knows about)
"""

import ipaddress
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent

ALLOWED_NETWORKS = [
    ipaddress.ip_network(n)
    for n in (
        "192.0.2.0/24",  # RFC 5737 TEST-NET-1
        "198.51.100.0/24",  # RFC 5737 TEST-NET-2
        "203.0.113.0/24",  # RFC 5737 TEST-NET-3
        "100.64.0.0/10",  # RFC 6598 shared address space (NetBird)
        "127.0.0.0/8",  # loopback
        "0.0.0.0/32",  # unspecified
        "2001:db8::/32",  # RFC 3849 documentation
        "::1/128",
        "::/128",
    )
]

# Real TLDs a leaked name would most likely use, plus private-use suffixes that
# would still identify a customer network. File extensions that are also TLDs
# (md, sh, py, rs, ...) are left out on purpose.
TLDS = {
    # generic
    "com", "org", "net", "io", "info", "biz", "dev", "app", "cloud", "ai",
    "me", "tech", "online", "site", "xyz", "co", "tv", "page", "software",
    "systems", "services", "solutions", "consulting", "digital", "gmbh", "ag",
    # European and other common country codes
    "de", "at", "ch", "eu", "uk", "fr", "nl", "be", "lu", "it", "es", "pt",
    "pl", "cz", "sk", "hu", "se", "dk", "no", "fi", "ie", "us", "ca",
    # private use: names under these still identify a network
    "internal", "lan", "corp", "home", "intranet", "local",
}

CODE_ROOTS = {
    "var", "local", "locals", "module", "each", "data", "output", "path",
    "self", "count", "terraform", "tofu", "run", "item", "ansible", "site",
    "apps", "instances", "catalog", "sign_in", "guest", "guests", "policies",
    "domains",
}

IPV4 = re.compile(r"(?<![\w.])(\d{1,3}(?:\.\d{1,3}){3})(?:/(\d{1,2}))?(?![\w.])")
IPV6 = re.compile(r"(?<![\w:.])([0-9A-Fa-f]{0,4}(?::[0-9A-Fa-f]{0,4}){2,7})(?:/(\d{1,3}))?(?![\w:])")
NAME = re.compile(r"(?<![\w.@-])((?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+([A-Za-z]{2,63}))(?![\w-])")
EMAIL_DOMAIN = re.compile(r"@((?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+([A-Za-z]{2,63}))\b")


def load_allowed_domains():
    lines = (REPO / "ci" / "allowlist.txt").read_text().splitlines()
    return [l.strip().lower() for l in lines if l.strip() and not l.lstrip().startswith("#")]


def tracked_files():
    out = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=REPO, check=True, capture_output=True,
    ).stdout
    return [REPO / p for p in out.decode().split("\0") if p]


def address_allowed(text, prefix):
    try:
        net = ipaddress.ip_network(f"{text}/{prefix}" if prefix else text, strict=False)
    except ValueError:
        return None  # not an address (a version number, 192.0.2.300, ...)
    return any(net.version == a.version and net.subnet_of(a) for a in ALLOWED_NETWORKS)


def domain_allowed(name, allowed):
    name = name.lower().rstrip(".")
    return any(name == d or name.endswith("." + d) for d in allowed)


def check_file(path, allowed):
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        return []
    rel = path.relative_to(REPO) if path.is_relative_to(REPO) else path
    problems = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in IPV4.finditer(line):
            if address_allowed(m.group(1), m.group(2)) is False:
                problems.append(f"{rel}:{lineno}: address {m.group(0)}")
        for m in IPV6.finditer(line):
            if m.group(1).count(":") < 2 or "::" not in m.group(1) and m.group(1).count(":") < 7:
                continue
            if address_allowed(m.group(1), m.group(2)) is False:
                problems.append(f"{rel}:{lineno}: address {m.group(0)}")
        names = [(m.group(1), m.group(2)) for m in NAME.finditer(line)]
        names += [(m.group(1), m.group(2)) for m in EMAIL_DOMAIN.finditer(line)]
        for name, tld in names:
            if tld.lower() not in TLDS:
                continue
            labels = name.split(".")
            if labels[0].lower() in CODE_ROOTS:
                continue
            if len(labels) == 2 and len(labels[0]) == 1:
                continue  # attribute access on a loop variable: i.app, a.host
            if not domain_allowed(name, allowed):
                problems.append(f"{rel}:{lineno}: name {name}")
    return problems


def self_test():
    """The checker must flag what it is for. Samples are built at run time so
    this file itself stays clean."""
    import tempfile
    leaks = [
        "server " + ".".join(["10", "1", "4", "30"]),
        "ip: " + ".".join(["192", "168", "200", "3"]),
        "host: app." + "customer" + ".de",
        "mail " + "ops@" + "customer" + ".io",
        "peer x." + "customer" + ".internal",
        "range " + ":".join(["2a01", "4f8", "1", "", "/64"]),
    ]
    clean = [
        "svc.example.org 192.0.2.11 100.64.0.0/10 127.0.0.1:8080 2001:db8::1",
        "module.catalog.site main.tf catalog.yml version 1.11.5 at 11:35:00 i.app",
        "https://github.com/opentofu/setup-opentofu",
    ]
    allowed = load_allowed_domains()
    ok = True
    with tempfile.TemporaryDirectory() as d:
        for i, sample in enumerate(leaks + clean):
            f = pathlib.Path(d) / f"s{i}.txt"
            f.write_text(sample + "\n")
            flagged = bool(check_file(f, allowed))
            if flagged != (sample in leaks):
                print(f"self-test: {'missed' if sample in leaks else 'false positive'}: {sample}")
                ok = False
    print("self-test passed" if ok else "self-test FAILED")
    return 0 if ok else 1


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    allowed = load_allowed_domains()
    files = [pathlib.Path(a).resolve() for a in argv] if argv else tracked_files()
    problems = sorted(set(p for f in files if f.is_file() for p in check_file(f, allowed)))
    for p in problems:
        print(p)
    if problems:
        print(f"{len(problems)} name(s) or address(es) outside the allowlist "
              "(ci/allowlist.txt, ci/allowlist-check.py)", file=sys.stderr)
        return 1
    print(f"allowlist: {len(files)} files clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
