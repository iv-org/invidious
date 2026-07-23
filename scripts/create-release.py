#!/usr/bin/env python3
"""Prepare a new Invidious release.

This automates the release procedure documented at
https://github.com/iv-org/documentation/blob/master/docs/create-new-invidious-release.md

What it does (all of it, so the GitHub workflow only has to run this script):
  1. Computes the next version `<MAJOR>.<YYYYMMDD>.<PATCH>` from shard.yml.
  2. Collects EVERY pull request merged since the previous release, via `gh`.
  3. Asks an LLM (OpenRouter API) to write only the changelog *prose*
     (wrap-up + categorised sections), using recent CHANGELOG.md as a style
     guide. The exhaustive PR list is generated deterministically so no PR is
     ever missed.
  4. Bumps shard.yml and prepends the new section to CHANGELOG.md.
  5. Creates the `release-vX.Y.Z` branch, commits, pushes, and opens a PR to
     master with the post-merge checklist (tagging + publishing stay manual,
     as the docs require maintainer review and forbid squash-merges/retagging).

The LLM is called through any OpenAI-compatible Chat Completions endpoint,
configured with the standard `OPENAI_API_KEY` / `OPENAI_BASE_URL` environment
variables (as used by the official OpenAI SDK). It defaults to OpenRouter, but
point it at OpenAI, a local server, etc. by setting `OPENAI_BASE_URL`.

Manual usage:
  export OPENAI_API_KEY=sk-or-...              # OpenRouter key by default
  ./scripts/create-release.py                  # full run: edits, commit, push, PR
  ./scripts/create-release.py --dry-run        # only edit files locally
  ./scripts/create-release.py --major 3        # bump major (breaking changes)
  ./scripts/create-release.py --patch 1        # 2nd release on the same day
  ./scripts/create-release.py --model x/y      # override the model
  # Use vanilla OpenAI instead of OpenRouter:
  OPENAI_BASE_URL=https://api.openai.com/v1 \
    ./scripts/create-release.py --model gpt-4o

Requirements: python3, git, and the GitHub CLI (`gh`) authenticated (or
GH_TOKEN set). Only OPENAI_API_KEY is mandatory (skippable with --dry-run
combined with --pr-json for offline testing).
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

DEFAULT_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_MODEL = "deepseek/deepseek-v4-pro"
REPO_URL = "https://github.com/iv-org/invidious"
CHANGELOG_FILE = "CHANGELOG.md"
SHARD_FILE = "shard.yml"


def die(msg):
    prefix = "::error::" if os.environ.get("GITHUB_ACTIONS") else "error: "
    print(f"{prefix}{msg}", file=sys.stderr)
    sys.exit(1)


def run(cmd, capture=False, check=True):
    """Run a subprocess command (list of args)."""
    print(f"$ {' '.join(cmd)}", file=sys.stderr)
    result = subprocess.run(
        cmd, check=False, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if check and result.returncode != 0:
        detail = (result.stderr or "").strip() if capture else ""
        die(f"command failed ({result.returncode}): {' '.join(cmd)}\n{detail}")
    return (result.stdout or "").strip() if capture else ""


# --------------------------------------------------------------------------- #
# Version + git helpers
# --------------------------------------------------------------------------- #
def read_current_version():
    with open(SHARD_FILE, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"^version:\s*(\S+)", line)
            if m:
                return m.group(1)
    die(f"no 'version:' line found in {SHARD_FILE}")


def compute_version(args):
    current = read_current_version()  # e.g. 2.20260626.0-dev
    print(f"Current shard.yml version: {current}", file=sys.stderr)
    major = str(args.major) if args.major is not None else current.split(".", 1)[0]
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d")
    version = f"{major}.{date}.{args.patch}"
    tag = f"v{version}"
    existing = run(["git", "tag", "--list", tag], capture=True)
    if existing:
        die(f"tag {tag} already exists; pass --patch {args.patch + 1}")
    return version, tag


def previous_tag():
    tags = run(["git", "tag", "--list", "v*", "--sort=-creatordate"],
               capture=True)
    return tags.splitlines()[0].strip() if tags else ""


def tag_date(tag):
    return run(["git", "log", "-1", "--format=%cI", tag], capture=True)


# --------------------------------------------------------------------------- #
# Pull request collection
# --------------------------------------------------------------------------- #
def collect_prs(repo, prev_tag, pr_json_path):
    if pr_json_path:
        with open(pr_json_path, encoding="utf-8") as fh:
            prs = json.load(fh)
    else:
        cmd = ["gh", "pr", "list", "--repo", repo, "--base", "master",
               "--state", "merged", "--limit", "1000",
               "--json", "number,title,url,author,mergedAt"]
        if prev_tag:
            since = tag_date(prev_tag)
            print(f"Listing PRs merged after {since} ({prev_tag})",
                  file=sys.stderr)
            cmd += ["--jq", f'[.[] | select(.mergedAt > "{since}")]']
        else:
            print("No previous tag; listing all merged PRs.", file=sys.stderr)
        out = run(cmd, capture=True)
        prs = json.loads(out) if out else []
    prs.sort(key=lambda p: p.get("mergedAt") or "", reverse=True)
    print(f"Collected {len(prs)} merged PR(s).", file=sys.stderr)
    return prs


def format_author(author):
    """Match the CHANGELOG convention (`gh` returns bots as `app/dependabot`,
    but the changelog uses `dependabot[bot]`)."""
    login = (author or {}).get("login") or "ghost"
    if login.startswith("app/"):
        return f"{login[len('app/'):]}[bot]"
    return login


def format_pr_list(prs):
    lines = []
    for pr in prs:
        author = format_author(pr.get("author"))
        title = (pr.get("title") or "").strip()
        lines.append(f"* {title} ({REPO_URL}/pull/{pr.get('number')}, "
                     f"by @{author})")
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# Changelog generation
# --------------------------------------------------------------------------- #
def extract_style_reference(changelog, max_chars=6000):
    matches = list(re.finditer(r"^## v\S+.*$", changelog, flags=re.MULTILINE))
    for i, m in enumerate(matches):
        if "(future)" in m.group(0):
            continue
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(changelog)
        section = changelog[start:end].strip()
        section = re.split(r"^### Full list of pull requests", section,
                           flags=re.MULTILINE)[0].strip()
        return section[:max_chars]
    return ""


def build_prompt(prs, style_ref, version):
    pr_bullets = "\n".join(
        f"- #{p.get('number')}: {(p.get('title') or '').strip()}" for p in prs)
    return f"""You are writing the changelog prose for the Invidious release v{version}.

Below is an example of a PAST release entry from CHANGELOG.md. Match its \
Markdown structure, tone and heading style EXACTLY (a "### Wrap-up" narrative \
of 2-3 short paragraphs, then "### New features & important changes" with \
"#### For Users", "#### For instance owners" and "#### For developers" \
sub-sections, then a "### Bugs fixed" section when relevant).

--- STYLE EXAMPLE START ---
{style_ref}
--- STYLE EXAMPLE END ---

Here is the complete list of pull requests merged since the last release, \
which you must summarise (reference PRs inline as "(#1234)"). Sort content by \
user impact, with new features and breaking changes first:

{pr_bullets}

Rules:
- Output ONLY the Markdown body starting at "### Wrap-up". Do NOT include the \
"## v{version}" header.
- Do NOT include the exhaustive "### Full list of pull requests merged since \
the last release" section; it is appended separately.
- Do NOT invent PRs or changes that are not in the list above.
- Keep it concise and factual."""


def call_llm(base_url, api_key, model, prompt):
    url = base_url.rstrip("/") + "/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a meticulous release "
             "manager for the Invidious project who writes clear, accurate "
             "changelogs in Markdown."},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.3,
    }
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            # OpenRouter-specific attribution headers; ignored by other APIs.
            "HTTP-Referer": REPO_URL,
            "X-Title": "Invidious release changelog",
        }, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        die(f"LLM API HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')}")
    except urllib.error.URLError as exc:
        die(f"LLM API request failed: {exc}")
    try:
        content = body["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError):
        die(f"unexpected LLM API response: {json.dumps(body)[:1000]}")
    if not content:
        die("LLM API returned empty content")
    return content


def generate_prose(prs, version, base_url, api_key, model):
    if not prs:
        return ("### Wrap-up\n\nNo pull requests were merged since the "
                "previous release.")
    with open(CHANGELOG_FILE, encoding="utf-8") as fh:
        changelog = fh.read()
    prompt = build_prompt(prs, extract_style_reference(changelog), version)
    return call_llm(base_url, api_key, model, prompt)


# --------------------------------------------------------------------------- #
# File edits
# --------------------------------------------------------------------------- #
def update_changelog(version, entry_body):
    with open(CHANGELOG_FILE, encoding="utf-8") as fh:
        content = fh.read()
    section = f"## v{version}\n\n{entry_body}\n"
    future = re.search(r"^## v\S*\s*\(future\)\s*$", content, flags=re.MULTILINE)
    if future:
        at = future.end()
        rest = content[at:].lstrip("\n")
        content = content[:at] + "\n\n" + section + "\n" + rest
    else:
        title = re.search(r"^# CHANGELOG\s*$", content, flags=re.MULTILINE)
        at = title.end() if title else 0
        content = (content[:at] + "\n\n" + section + "\n"
                   + content[at:].lstrip("\n"))
    with open(CHANGELOG_FILE, "w", encoding="utf-8") as fh:
        fh.write(content)


def update_shard(version):
    with open(SHARD_FILE, encoding="utf-8") as fh:
        content = fh.read()
    content, n = re.subn(r"^version:\s*.*$", f"version: {version}", content,
                         count=1, flags=re.MULTILINE)
    if n != 1:
        die(f"could not update 'version:' in {SHARD_FILE}")
    with open(SHARD_FILE, "w", encoding="utf-8") as fh:
        fh.write(content)


# --------------------------------------------------------------------------- #
# Git / GitHub
# --------------------------------------------------------------------------- #
def detect_repo(explicit):
    if explicit:
        return explicit
    env = os.environ.get("GITHUB_REPOSITORY")
    if env:
        return env
    url = run(["git", "remote", "get-url", "origin"], capture=True, check=False)
    m = re.search(r"github\.com[:/](.+?)(?:\.git)?$", url)
    return m.group(1) if m else "iv-org/invidious"


def create_pull_request(repo, tag, branch, model, summary):
    if run(["git", "config", "user.name"], capture=True, check=False) == "":
        run(["git", "config", "user.name", "github-actions[bot]"])
        run(["git", "config", "user.email",
             "41898282+github-actions[bot]@users.noreply.github.com"])
    run(["git", "checkout", "-b", branch])
    run(["git", "add", CHANGELOG_FILE, SHARD_FILE])
    run(["git", "commit", "-m", f"Release {tag}"])
    run(["git", "push", "-u", "origin", branch])

    body = f"""Automated release preparation for **{tag}**.

Bumps `{SHARD_FILE}` and updates `{CHANGELOG_FILE}` (prose generated by the \
`{model}` model; the PR list is generated deterministically so every merged \
PR is included).

## Before merging
- [ ] Review the generated changelog for accuracy
- [ ] Confirm the version number and major bump (if any)

## After merging (maintainer, per the release docs)
- Do **not** squash-merge; keep the release commit distinct.
- Tag the merge commit: `git tag -as {tag}` using the changelog summary as \
the annotation, then `git push origin {tag}`.
- Run the "Prepare for next release" step (append `-dev` in {SHARD_FILE}, add \
a new `(future)` changelog header).
- Create the GitHub release from the tag with the changelog summary + PR list.

Refer to the documentation for more details:
https://github.com/iv-org/documentation/blob/master/docs/create-new-invidious-release.md

### Proposed tag annotation (changelog summary)
```markdown
{summary}
```
"""
    run(["gh", "pr", "create", "--repo", repo, "--base", "master",
         "--head", branch, "--title", f"Release {tag}", "--body", body])


# --------------------------------------------------------------------------- #
def main():
    parser = argparse.ArgumentParser(description="Prepare an Invidious release.")
    parser.add_argument("--major", type=int, default=None,
                        help="major version (default: keep current)")
    parser.add_argument("--patch", type=int, default=0,
                        help="patch number (default: 0)")
    parser.add_argument("--model", default=os.environ.get(
        "LLM_MODEL", DEFAULT_MODEL),
        help=f"model name (default: {DEFAULT_MODEL})")
    parser.add_argument("--base-url", default=os.environ.get(
        "OPENAI_BASE_URL", DEFAULT_BASE_URL),
        help=f"OpenAI-compatible API base URL (default: {DEFAULT_BASE_URL})")
    parser.add_argument("--repo", default=None,
                        help="owner/repo (default: autodetect)")
    parser.add_argument("--pr-json", default=None,
                        help="read PR list from a JSON file instead of gh")
    parser.add_argument("--dry-run", action="store_true",
                        help="edit files only; no branch/commit/push/PR")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        die("OPENAI_API_KEY is not set")

    repo = detect_repo(args.repo)
    version, tag = compute_version(args)
    branch = f"release-{tag}"
    prev = previous_tag()
    print(f"Preparing {tag} (previous: {prev or '<none>'}) on {repo}",
          file=sys.stderr)

    prs = collect_prs(repo, prev, args.pr_json)
    prose = generate_prose(prs, version, args.base_url, api_key, args.model)

    entry_body = prose
    pr_list = format_pr_list(prs)
    if pr_list:
        entry_body += ("\n\n### Full list of pull requests merged since the "
                       "last release (newest first)\n\n" + pr_list)

    update_changelog(version, entry_body)
    update_shard(version)
    print(f"Updated {CHANGELOG_FILE} and {SHARD_FILE} for {tag}.",
          file=sys.stderr)

    if args.dry_run:
        print(f"\n--- Dry run complete. Review the diff, then:\n"
              f"  git checkout -b {branch}\n"
              f"  git add {CHANGELOG_FILE} {SHARD_FILE}\n"
              f"  git commit -m 'Release {tag}'\n"
              f"  git push -u origin {branch}\n"
              f"  gh pr create --base master --head {branch} "
              f"--title 'Release {tag}'", file=sys.stderr)
        return

    create_pull_request(repo, tag, branch, args.model, prose)
    print(f"\nOpened release PR for {tag}.", file=sys.stderr)


if __name__ == "__main__":
    main()
