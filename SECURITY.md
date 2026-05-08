# Security Policy

## Supported Versions

Security updates are provided for the latest published `viva_telemetry` release
on Hex and the current `master` branch.

| Version | Supported |
| ------- | --------- |
| latest  | Yes       |
| older releases | Best effort |

## Reporting a Vulnerability

Please do not open a public issue for a security vulnerability.

Report security concerns through GitHub's private vulnerability reporting when
available, or contact the maintainer directly through the repository owner
profile.

Include as much detail as possible:

- affected version or commit;
- runtime target and OTP/Gleam versions;
- minimal reproduction steps;
- expected and actual behavior;
- impact assessment, if known.

## Scope

Security-sensitive areas include:

- file logging paths and file writes;
- JSON log output containing sensitive fields;
- Erlang FFI modules;
- ETS-backed metric storage;
- Prometheus output escaping;
- benchmark functions that execute caller-provided code.

## Disclosure Process

After a report is received, the maintainer will triage the issue, confirm the
affected versions, prepare a fix, and publish a patched release when needed.
Public disclosure should wait until a fixed version is available.
