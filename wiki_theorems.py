#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["pyyaml>=6"]
# ///
# wiki_theorems.py v5 — raccolta PER RAMO DI GIOCO, ricorsione nelle sottocategorie
# Avvio:  uv run wiki_theorems.py > teoremi.txt   (log/avvisi su stderr)
# Salva anche teoremi.yaml nella cartella dello script (lista completa, non troncata)
import json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
from datetime import datetime, timezone
from pathlib import Path

import yaml

# La policy Wikimedia chiede un contatto reale nello User-Agent
UA = ("IdleTheorems-research/0.1 "
      "(ricerca per game design matematico; contatto: TU@example.com)")

# Match a inizio parola: niente falsi positivi tipo "Prisoner's dilemma";
# i prefissi coprono anche i plurali (teoremi, lemmi, corollari, congetture...)
KEYWORD_RE = re.compile(
    r"\b(theorem|teorem|lemm|corollar|result|risultat|conjectur|congettur)",
    re.IGNORECASE)
EXCLUDE_PREFIX = ("list of", "lista di", "elenco di")
CAP_PER_BRANCH = 400   # tetto solo per lo stdout (il YAML contiene tutto)
MAX_SUBCATS = 15       # sottocategorie esplorate per nodo
DEPTH = 1              # livelli di ricorsione

YAML_PATH = Path(__file__).resolve().parent / "teoremi.yaml"


class ApiError(RuntimeError):
    pass


def api(base, **p):
    p.update(action="query", format="json", formatversion=2, maxlag=5)
    url = base + "/w/api.php?" + urllib.parse.urlencode(p)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    last = None
    for attempt in range(4):
        wait = 2 ** attempt
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            last = e
            ra = e.headers.get("Retry-After")
            if ra and ra.isdigit():
                wait = int(ra)
            if e.code < 500 and e.code != 429:
                raise                       # errore client: inutile ritentare
        except (OSError, ValueError) as e:  # rete, timeout, JSON malformato
            last = e
        else:
            if "warnings" in d:
                print(f"[api-warn] {d['warnings']}", file=sys.stderr)
            err = d.get("error")
            if not err:
                return d
            last = ApiError(f"API: {err.get('code')} - {err.get('info')}")
            if err.get("code") != "maxlag":
                raise last                  # parametri sbagliati: inutile ritentare
        print(f"[warn] tentativo {attempt + 1}: {last}", file=sys.stderr)
        time.sleep(wait)
    raise last


def members(base, cat):
    """(pagine, sottocategorie) di una categoria, con paginazione completa."""
    pages, subs, cont = [], [], {}
    while True:
        d = api(base, list="categorymembers", cmtitle=cat,
                cmtype="page|subcat", cmprop="title|type", cmlimit="max", **cont)
        for m in d.get("query", {}).get("categorymembers", []):
            (subs if m["type"] == "subcat" else pages).append(m["title"])
        if "continue" not in d:
            return pages, subs
        cont = d["continue"]               # passa tutto il blocco continue
        time.sleep(0.3)


def is_theorem(title):
    tl = title.lower()
    return (KEYWORD_RE.search(title) is not None
            and "disambigua" not in tl
            and not tl.startswith(EXCLUDE_PREFIX)
            and len(title) > 7)


def collect_branch(base, cats, depth=DEPTH):
    """dict: titolo -> set(categorie sorgente), filtrato sui soli teoremi."""
    found, seen = {}, set()

    def walk(cat, d):
        if cat in seen:
            return
        seen.add(cat)
        try:
            pages, subs = members(base, cat)
        except Exception as e:
            print(f"[skip] {cat}: {e}", file=sys.stderr)
            return
        if not pages and not subs:
            print(f"[vuota o inesistente] {cat}", file=sys.stderr)
        for t in pages:
            if is_theorem(t):
                found.setdefault(t, set()).add(cat)
        if d > 0:
            for s in subs[:MAX_SUBCATS]:
                walk(s, d - 1)

    for c in cats:
        walk(c.replace("_", " "), depth)
    return found


def page_url(base, title):
    return base + "/wiki/" + urllib.parse.quote(title.replace(" ", "_"))


EN, IT = "https://en.wikipedia.org", "https://it.wikipedia.org"

BRANCHES_EN = {
    "logica_insiemi":         ["Category:Set_theory", "Category:Mathematical_logic"],
    "algebra_discreta":       ["Category:Combinatorics", "Category:Graph_theory"],
    "analisi":                ["Category:Real_analysis", "Category:Calculus"],
    "geometria":              ["Category:Euclidean_geometry"],
    "probabilita":            ["Category:Probability_theory"],
    "statistica_stocastici":  ["Category:Statistics", "Category:Stochastic_processes"],
    "teoria_numeri":          ["Category:Number_theory"],
    "tna":                    ["Category:Analytic_number_theory"],
    "algebra_astratta":       ["Category:Group_theory", "Category:Ring_theory", "Category:Field_theory"],
    "calcolo_multivariabile": ["Category:Vector_calculus"],
    "topologia":              ["Category:General_topology"],
    "misura":                 ["Category:Measure_theory"],
    "informazione":           ["Category:Information_theory"],
    "sistemi_dinamici":       ["Category:Dynamical_systems"],
    "analisi_complessa":      ["Category:Complex_analysis"],
    "geom_algebrica":         ["Category:Algebraic_geometry"],
    "topol_algebrica":        ["Category:Algebraic_topology"],
    "crittografia":           ["Category:Cryptography"],
    "analisi_funzionale":     ["Category:Functional_analysis"],
    "edp":                    ["Category:Partial_differential_equations"],
    "complessita":            ["Category:Computational_complexity_theory"],
    "categorie":              ["Category:Category_theory"],
}

BRANCHES_IT = {
    "logica_insiemi":         ["Categoria:Teoria degli insiemi", "Categoria:Logica matematica"],
    "algebra_discreta":       ["Categoria:Combinatoria", "Categoria:Teoria dei grafi"],
    "analisi":                ["Categoria:Analisi matematica"],
    "geometria":              ["Categoria:Geometria euclidea"],
    "probabilita":            ["Categoria:Probabilità"],
    "statistica_stocastici":  ["Categoria:Statistica", "Categoria:Processi stocastici"],
    "teoria_numeri":          ["Categoria:Teoria dei numeri"],
    "algebra_astratta":       ["Categoria:Algebra astratta"],
    "topologia":              ["Categoria:Topologia"],
    "misura":                 ["Categoria:Teoria della misura"],
    "informazione":           ["Categoria:Teoria dell'informazione"],
    "sistemi_dinamici":       ["Categoria:Sistemi dinamici"],
    "analisi_complessa":      ["Categoria:Analisi complessa"],
    "geom_algebrica":         ["Categoria:Geometria algebrica"],
    "topol_algebrica":        ["Categoria:Topologia algebrica"],
    "crittografia":           ["Categoria:Crittografia"],
    "analisi_funzionale":     ["Categoria:Analisi funzionale"],
    "edp":                    ["Categoria:Equazioni differenziali parziali"],
    "complessita":            ["Categoria:Complessità computazionale"],
    "categorie":              ["Categoria:Teoria delle categorie"],
}


def save_yaml(doc):
    """Scrittura atomica: un crash a metà non lascia un YAML corrotto."""
    tmp = YAML_PATH.with_suffix(".yaml.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        yaml.safe_dump(doc, f, allow_unicode=True, sort_keys=False,
                       default_flow_style=False, width=1000)
    os.replace(tmp, YAML_PATH)


def dump(label, base, branches, doc):
    print(f"\n########## {label} ##########")
    wiki = doc["wikis"].setdefault(label.lower(), {"base_url": base, "branches": {}})
    for name, cats in branches.items():
        print(f"\n== {name} ==", flush=True)
        entry = {"categories": cats}
        wiki["branches"][name] = entry
        try:
            found = collect_branch(base, cats)
        except Exception as e:
            print(f"[skip ramo] {e}")
            entry.update(status="error", error=str(e), count=0, theorems=[])
            save_yaml(doc)
            continue
        titles = sorted(found)
        total = len(titles)

        # YAML: lista completa
        entry.update(status="ok", count=total, theorems=[
            {"title": t, "url": page_url(base, t), "sources": sorted(found[t])}
            for t in titles])
        doc["meta"]["total_theorems"] += total
        save_yaml(doc)                      # salvataggio progressivo per ramo

        # stdout: troncato come prima
        if total > CAP_PER_BRANCH:
            print(f"[troncato a {CAP_PER_BRANCH} di {total}]")
            titles = titles[:CAP_PER_BRANCH]
        for t in titles:
            print(f"{t}  ({', '.join(sorted(found[t]))})")
        print(f"[ok] {len(titles)} titoli")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    doc = {
        "meta": {
            "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "script_version": 5,
            "depth": DEPTH,
            "max_subcats": MAX_SUBCATS,
            "keyword_regex": KEYWORD_RE.pattern,
            "complete": False,
            "total_theorems": 0,
        },
        "wikis": {},
    }
    dump("EN", EN, BRANCHES_EN, doc)
    dump("IT", IT, BRANCHES_IT, doc)
    doc["meta"]["complete"] = True
    save_yaml(doc)
    print(f"[yaml] salvato in {YAML_PATH}", file=sys.stderr)
