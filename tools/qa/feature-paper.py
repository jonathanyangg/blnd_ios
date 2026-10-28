#!/usr/bin/env python3
"""Generate a one-page "mini paper" for a feature/PR: task, what changed, results, screenshots, risks, verdict.

Output: <out>/index.html (self-contained, open it) and <out>/summary.md
Default out: ~/cursor-work/papers/<YYYY-MM-DD>-<slug>/

Example:
  tools/qa/feature-paper.py --slug recent-searches --pr 123 --repo jonathanyangg/blnd_ios \
      --task "Show recent searches with a clear button" \
      --before ~/cursor-work/qa/artifacts/maestro-dev --after ~/cursor-work/qa/artifacts/maestro-pr123 \
      --flows-after ~/cursor-work/qa/artifacts/maestro-pr123/results.tsv \
      --unit-junit build/unit.xml --video pr123.mp4

Everything except --slug is optional. Missing inputs are shown as "not provided" (never silently green).
"""
import argparse, datetime, html, json, os, re, shutil, subprocess, sys
import xml.etree.ElementTree as ET


def sh(cmd, cwd=None):
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=60).stdout.strip()
    except Exception:
        return ""


def junit_counts(path):
    if not path or not os.path.exists(path):
        return None
    t = f = s = e = 0
    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else root.iter("testsuite")
    for su in suites:
        t += int(su.get("tests", 0)); f += int(su.get("failures", 0)); e += int(su.get("errors", 0)); s += int(su.get("skipped", 0))
    return {"total": t, "passed": t - f - e - s, "failed": f + e, "skipped": s}


def flow_results(path):
    if not path or not os.path.exists(path):
        return None
    rows = []
    for line in open(path):
        p = line.rstrip("\n").split("\t")
        if len(p) >= 2:
            rows.append({"flow": p[0], "result": p[1], "secs": p[2] if len(p) > 2 else ""})
    return rows


def shots(d):
    """flow -> sorted list of screenshot paths in a run-flows.sh output dir"""
    out = {}
    if not d or not os.path.isdir(d):
        return out
    for flow in sorted(os.listdir(d)):
        ts = os.path.join(d, flow, "takeScreenshot")
        if os.path.isdir(ts):
            out[flow] = sorted(os.path.join(ts, x) for x in os.listdir(ts) if x.endswith(".png"))
    return out


def plain_changes(files):
    """Bucket changed files into plain-English areas."""
    buckets = {}
    def add(k, f): buckets.setdefault(k, []).append(f)
    for f in files:
        l = f.lower()
        if "/views/" in l or l.endswith("view.swift"): add("Screens / UI", f)
        elif "viewmodel" in l or "/models/" in l or "state" in l: add("App logic and data", f)
        elif "/services/" in l or "api" in l: add("Networking / backend calls", f)
        elif "test" in l or ".maestro" in l: add("Tests", f)
        elif l.endswith((".md", ".yml", ".yaml")): add("Docs / config", f)
        elif l.startswith("routers/") or l.startswith("services/") or l.startswith("migrations") or l.endswith(".sql"): add("Backend / database", f)
        else: add("Other", f)
    return buckets


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--title")
    ap.add_argument("--task", help="original task statement, verbatim if possible")
    ap.add_argument("--pr", help="PR number (needs gh)")
    ap.add_argument("--repo", help="owner/name for --pr")
    ap.add_argument("--base", default="dev"); ap.add_argument("--head", help="branch to diff against base")
    ap.add_argument("--git-dir", default=os.getcwd())
    ap.add_argument("--summary", help="plain-English what changed (overrides PR body)")
    ap.add_argument("--before"); ap.add_argument("--after")
    ap.add_argument("--flows-after"); ap.add_argument("--flows-before")
    ap.add_argument("--unit-junit"); ap.add_argument("--backend-junit")
    ap.add_argument("--video", help="mp4 to embed/copy")
    ap.add_argument("--risk", action="append", default=[])
    ap.add_argument("--verdict", help="override automatic one-line verdict")
    ap.add_argument("--out")
    a = ap.parse_args()

    date = datetime.date.today().isoformat()
    out = os.path.expanduser(a.out or f"~/cursor-work/papers/{date}-{a.slug}")
    os.makedirs(os.path.join(out, "img"), exist_ok=True)

    title, body, url, files, stat = a.title, a.summary or "", "", [], ""
    if a.pr:
        j = sh(["gh", "pr", "view", a.pr, "--repo", a.repo or "", "--json", "title,body,url,files,additions,deletions,headRefName,baseRefName"] if a.repo
               else ["gh", "pr", "view", a.pr, "--json", "title,body,url,files,additions,deletions,headRefName,baseRefName"], a.git_dir)
        if j:
            d = json.loads(j)
            title = title or d["title"]; url = d["url"]
            body = body or d.get("body") or ""
            files = [f["path"] for f in d["files"]]
            stat = f'{len(files)} files, +{d["additions"]} / -{d["deletions"]} ({d["headRefName"]} into {d["baseRefName"]})'
    elif a.head:
        files = sh(["git", "diff", "--name-only", f"{a.base}...{a.head}"], a.git_dir).splitlines()
        stat = sh(["git", "diff", "--shortstat", f"{a.base}...{a.head}"], a.git_dir)
    title = title or a.slug

    # tests
    unit = junit_counts(a.unit_junit); be = junit_counts(a.backend_junit)
    fa = flow_results(a.flows_after); fb = flow_results(a.flows_before)
    bad = []
    if unit and unit["failed"]: bad.append(f'{unit["failed"]} unit test(s) failing')
    if be and be["failed"]: bad.append(f'{be["failed"]} backend test(s) failing')
    if fa:
        f_failed = [r["flow"] for r in fa if r["result"] != "PASS"]
        if f_failed: bad.append("UI flows failing: " + ", ".join(f_failed))
    missing = [n for n, v in (("unit tests", unit or be), ("UI flows", fa)) if not v]
    if a.verdict: verdict = a.verdict
    elif bad: verdict = "RED: " + "; ".join(bad)
    elif missing: verdict = "UNVERIFIED: no results provided for " + ", ".join(missing)
    else:
        verdict = "GREEN: all provided tests pass; review the screenshots below for look and feel"

    # screenshots (copy so the paper is portable)
    sa, sb = shots(a.after), shots(a.before)
    gallery = []
    for flow, imgs in sa.items():
        for p in imgs:
            name = os.path.basename(p)
            dest_a = f"img/after-{flow}-{name}"; shutil.copy(p, os.path.join(out, dest_a))
            bp = next((q for q in sb.get(flow, []) if os.path.basename(q) == name), None)
            dest_b = None
            if bp:
                dest_b = f"img/before-{flow}-{name}"; shutil.copy(bp, os.path.join(out, dest_b))
            gallery.append((flow, name[:-4], dest_b, dest_a))
    video = None
    if a.video and os.path.exists(os.path.expanduser(a.video)):
        video = "img/" + os.path.basename(a.video); shutil.copy(os.path.expanduser(a.video), os.path.join(out, video))

    changes = plain_changes(files)
    risks = list(a.risk)
    if any("migrations" in f or f.endswith(".sql") for f in files): risks.append("Touches the database schema; needs a migration run on deploy.")
    if any("Info.plist" in f or ".entitlements" in f or "pbxproj" in f for f in files): risks.append("Changes app config or entitlements; check App Store review impact.")
    if not fa: risks.append("No UI flow results attached; the UI is not verified.")
    if fa and any(r["result"] != "PASS" for r in fa): risks.append("At least one UI flow failed; see screenshots.")
    if not risks: risks.append("None identified beyond the usual: real-device behavior and live network data are not covered by sim flows.")

    # ---- summary.md
    md = [f"# {title}", f"**Verdict:** {verdict}", ""]
    if url: md.append(f"PR: {url}  ")
    if stat: md.append(f"Size: {stat}")
    md += ["", "## Original task", a.task or "_not provided_", "", "## What changed"]
    md.append(body.strip() or "_No description; see areas below._")
    for k, v in changes.items(): md.append(f"- {k}: {len(v)} file(s)")
    md += ["", "## Results"]
    if unit: md.append(f'- iOS unit tests: {unit["passed"]}/{unit["total"]} passed, {unit["failed"]} failed, {unit["skipped"]} skipped')
    if be: md.append(f'- Backend tests: {be["passed"]}/{be["total"]} passed, {be["failed"]} failed, {be["skipped"]} skipped')
    if fa:
        md.append(f'- UI flows (Maestro): {sum(r["result"]=="PASS" for r in fa)}/{len(fa)} passed')
        for r in fa: md.append(f'  - {r["flow"]}: {r["result"]} ({r["secs"]}s)')
    if not (unit or be or fa): md.append("_no results provided_")
    md += ["", "## Risks"] + [f"- {r}" for r in risks]
    open(os.path.join(out, "summary.md"), "w").write("\n".join(md) + "\n")

    # ---- index.html
    e = html.escape
    vcls = "green" if verdict.startswith("GREEN") else "red" if verdict.startswith("RED") else "amber"
    h = [f"""<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>{e(title)}</title><style>
body{{font:16px/1.5 -apple-system,system-ui,sans-serif;max-width:1100px;margin:24px auto;padding:0 16px;color:#111}}
h1{{margin:0 0 4px}} h2{{margin-top:28px;border-bottom:1px solid #ddd;padding-bottom:4px}}
.v{{padding:12px 16px;border-radius:10px;font-weight:600;margin:12px 0}}
.green{{background:#e3f7e8;color:#116b2b}}.red{{background:#fde4e4;color:#a11}}.amber{{background:#fff3d6;color:#7a5200}}
table{{border-collapse:collapse}}td,th{{padding:4px 12px;border-bottom:1px solid #eee;text-align:left}}
.pass{{color:#116b2b}}.fail{{color:#a11;font-weight:700}}
.g{{display:flex;gap:8px;flex-wrap:wrap}}.pair{{display:inline-flex;gap:8px;margin:0 14px 14px 0;vertical-align:top}}.pair figure{{margin:0;text-align:center;font-size:12px}}.pair img{{height:420px;width:auto;border-radius:12px;border:1px solid #ddd}}.g figure{{margin:0;text-align:center;font-size:12px}}.g img{{height:420px;border-radius:12px;border:1px solid #ddd}}
.pair{{display:flex;gap:12px;margin:8px 0;align-items:flex-start}}pre{{white-space:pre-wrap}}video{{max-height:560px}}</style>
<h1>{e(title)}</h1><div class="v {vcls}">{e(verdict)}</div>
<p>{('<a href="%s">%s</a> · ' % (e(url), e(url))) if url else ''}{e(stat)} · generated {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}</p>
<h2>Original task</h2><p>{e(a.task or 'not provided')}</p>
<h2>What changed</h2><pre>{e(body.strip() or 'No description; see areas below.')}</pre><ul>"""]
    for k, v in changes.items(): h.append(f"<li>{e(k)}: {len(v)} file(s)</li>")
    h.append("</ul><h2>Results</h2><ul>")
    if unit: h.append(f'<li>iOS unit tests: <b>{unit["passed"]}/{unit["total"]}</b> passed, {unit["failed"]} failed, {unit["skipped"]} skipped</li>')
    if be: h.append(f'<li>Backend tests: <b>{be["passed"]}/{be["total"]}</b> passed, {be["failed"]} failed, {be["skipped"]} skipped</li>')
    h.append("</ul>")
    if fa:
        bm = {r["flow"]: r["result"] for r in (fb or [])}
        h.append("<table><tr><th>UI flow</th><th>now</th><th>before</th><th>secs</th></tr>")
        for r in fa:
            c = "pass" if r["result"] == "PASS" else "fail"
            h.append(f'<tr><td>{e(r["flow"])}</td><td class={c}>{e(r["result"])}</td><td>{e(bm.get(r["flow"], "-"))}</td><td>{e(r["secs"])}</td></tr>')
        h.append("</table>")
    if not (unit or be or fa): h.append("<p><i>no results provided</i></p>")
    if video: h.append(f'<h2>Video</h2><video src="{e(video)}" controls></video>')
    h.append("<h2>Screenshots (before | after)</h2>")
    cur = None
    for flow, name, b, af in gallery:
        if flow != cur:
            if cur: h.append("</div>")
            h.append(f"<h3>{e(flow)}</h3><div>"); cur = flow
        h.append('<div class="pair">' + (f'<figure><img src="{b}"><figcaption>before</figcaption></figure>' if b else '') +
                 f'<figure><img src="{af}"><figcaption>{e(name)}</figcaption></figure></div>')
    if cur: h.append("</div>")
    if not gallery: h.append("<p><i>no screenshots provided</i></p>")
    h.append("<h2>Risks</h2><ul>" + "".join(f"<li>{e(r)}</li>" for r in risks) + "</ul>")
    open(os.path.join(out, "index.html"), "w").write("\n".join(h))
    print(out)


main()
