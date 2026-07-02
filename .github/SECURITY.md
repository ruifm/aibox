# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in `aibox`, report it privately by
emailing **security@ruimarques.xyz**.

Do not open a public issue for security vulnerabilities.

You should receive a response within 48 hours. I will work with you to
understand the issue and coordinate a fix before public disclosure.

## Scope

`aibox` is a Bubblewrap launcher. Issues in scope include:

- unintended host filesystem exposure;
- unintended credential, socket, or environment exposure;
- incorrect writable mount policy;
- command construction bugs that weaken the documented sandbox.

Issues in Bubblewrap, Nix, the Linux kernel, or AI agent CLIs should also be
reported upstream.
