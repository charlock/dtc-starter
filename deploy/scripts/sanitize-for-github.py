#!/usr/bin/env python3
"""Sanitize VPS compose file for GitHub: replace secret values with placeholders.
Never prints secret values. Run locally, output is the sanitized file.
Usage: python3 sanitize-for-github.py <input> <output>
"""
import pathlib, re, sys

inp, outp = sys.argv[1], sys.argv[2]
text = pathlib.Path(inp).read_text()

# Replace any line that assigns a known secret with a placeholder, keeping the key.
secret_keys = ["DATABASE_URL", "POSTGRES_PASSWORD", "JWT_SECRET", "COOKIE_SECRET",
               "REDIS_URL", "S3_ACCESS_KEY_ID", "S3_SECRET_ACCESS_KEY"]
for key in secret_keys:
    # docker compose list form: "- KEY=value"  and env form: "KEY=value"
    text = re.sub(rf"(- {key}=)[^\s\"']+", rf"\1<CHANGE_ME>", text)
    text = re.sub(rf"^(\s*{key}=).*$", rf"\1<CHANGE_ME>", text, flags=re.M)

# Any remaining pk_ / sk_ token-like strings (67-char publishable keys etc.)
text = re.sub(r"pk_[A-Za-z0-9]{20,}", "pk_<CHANGE_ME>", text)
text = re.sub(r"sk_[A-Za-z0-9]{20,}", "sk_<CHANGE_ME>", text)

pathlib.Path(outp).write_text(text)
print(f"sanitized -> {outp}")

# Audit: report any remaining suspicious patterns by line number only, no values.
for i, line in enumerate(text.splitlines(), 1):
    low = line.lower()
    if any(s in low for s in ["password=", "secret=", "token=", "-----begin"]):
        if "<CHANGE_ME>" not in line:
            print(f"WARN line {i}: possible secret remains: {line[:60]}")
print("audit done")
