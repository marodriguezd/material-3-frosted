#!/usr/bin/env python3
"""
scan_ui.py — static UI/UX reconnaissance for Android projects.

Phase 0 of the material-3-frosted workflow. Detects the stack, the versions, and the
mechanical signals of an outdated UI layer. It cannot see hierarchy, taste, or visual
balance — cross-check every hit by opening the file.

Usage:
    python3 scan_ui.py <path-to-android-project> [--format markdown|json|text]
                       [--max-hits N] [--fail-on LEVEL]

Exit codes:
    0  scan completed
    1  scan failed (bad path, etc.)
    2  --fail-on threshold reached (only with --fail-on)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Iterable, Iterator

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SKIP_DIRS = {
    ".git", ".gradle", ".idea", "build", "out", ".kotlin", "captures",
    ".cxx", "node_modules", "external", "generated",
}

SOURCE_EXTS = {".kt", ".java", ".xml", ".kts", ".gradle"}
COMPOSE_EXTS = {".kt"}

# Off-scale dp values that should not appear outside of a token definition.
ON_GRID_DP = {1, 2, 4, 8, 12, 16, 24, 32, 48, 56, 64, 72, 96, 128}

SEVERITY_ORDER = {"critical": 0, "warning": 1, "info": 2}

# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------


@dataclass
class Finding:
    id: str
    severity: str          # critical | warning | info
    dimension: str         # which of the 12 audit dimensions
    title: str
    detail: str
    locations: list[str] = field(default_factory=list)
    fix: str = ""

    def count(self) -> int:
        return len(self.locations)


@dataclass
class ProjectFacts:
    root: str
    modules: list[str] = field(default_factory=list)
    gradle_plugins: list[str] = field(default_factory=list)
    compile_sdk: list[str] = field(default_factory=list)
    target_sdk: list[str] = field(default_factory=list)
    min_sdk: list[str] = field(default_factory=list)
    compose_bom: list[str] = field(default_factory=list)
    material3_version: list[str] = field(default_factory=list)
    material_components_version: list[str] = field(default_factory=list)
    activity_version: list[str] = field(default_factory=list)
    haze_version: list[str] = field(default_factory=list)
    uses_compose: bool = False
    uses_views: bool = False
    uses_material_components: bool = False
    uses_material3_compose: bool = False
    uses_flutter: bool = False
    kotlin_files: int = 0
    java_files: int = 0
    xml_layouts: int = 0
    xml_themes: int = 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def iter_source_files(root: Path) -> Iterator[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if Path(name).suffix in SOURCE_EXTS:
                yield Path(dirpath) / name


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def grep(pattern: str, files: Iterable[tuple[Path, str]], limit: int = 40) -> list[str]:
    rx = re.compile(pattern)
    hits: list[str] = []
    for path, text in files:
        for i, line in enumerate(text.splitlines(), start=1):
            if rx.search(line):
                hits.append(f"{path}:{i}: {line.strip()[:160]}")
                if len(hits) >= limit:
                    return hits
    return hits


def small_touch_targets(files: Iterable[tuple[Path, str]], limit: int = 20) -> list[str]:
    """`.size(N.dp)` on an interactive element means its tap area is too small."""
    size_rx = re.compile(r"\.size\s*\(\s*(?:[0-3]?\d)\s*\.dp\s*\)")
    interactive_rx = re.compile(
        r"clickable|combinedClickable|pointerInput|toggleable|selectable|"
        r"IconButton|FloatingActionButton|Checkbox|Switch|RadioButton"
    )
    hits: list[str] = []
    for path, text in files:
        for i, line in enumerate(text.splitlines(), start=1):
            if "Icon(" in line:
                continue
            if size_rx.search(line) and interactive_rx.search(line):
                hits.append(f"{path}:{i}: {line.strip()[:160]}")
                if len(hits) >= limit:
                    return hits
    return hits


def unique(values: Iterable[str]) -> list[str]:
    seen, out = set(), []
    for v in values:
        if v and v not in seen:
            seen.add(v)
            out.append(v)
    return out


# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------


def catalog_versions(text: str) -> dict[str, str]:
    """Map `group:artifact` -> version from a Gradle version catalog (libs.versions.toml)."""
    version_aliases: dict[str, str] = {}
    artifacts: dict[str, str] = {}
    section = ""
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("["):
            section = line.strip("[]").strip()
            continue
        if section == "versions":
            m = re.match(r'([A-Za-z0-9_.-]+)\s*=\s*"([^"]+)"', line)
            if m:
                version_aliases[m.group(1)] = m.group(2)
        elif section == "libraries":
            m = re.match(r'([A-Za-z0-9_.-]+)\s*=\s*(.+)', line)
            if not m:
                continue
            spec = m.group(2)
            module = re.search(r'module\s*=\s*"([^"]+)"', spec)
            artifact = module.group(1) if module else None
            if artifact is None:
                group = re.search(r'group\s*=\s*"([^"]+)"', spec)
                name = re.search(r'name\s*=\s*"([^"]+)"', spec)
                if group and name:
                    artifact = f"{group.group(1)}:{name.group(1)}"
            if artifact is None:
                continue
            direct = re.search(r'version\s*=\s*"([^"]+)"', spec)
            ref = re.search(r'version\.ref\s*=\s*"([^"]+)"', spec)
            if direct:
                artifacts[artifact] = direct.group(1)
            elif ref and ref.group(1) in version_aliases:
                artifacts[artifact] = version_aliases[ref.group(1)]
    return artifacts


def collect_facts(root: Path) -> ProjectFacts:
    facts = ProjectFacts(root=str(root))
    files = list(iter_source_files(root))
    kt_files = [(p, read_text(p)) for p in files if p.suffix == ".kt"]
    java_files = [(p, read_text(p)) for p in files if p.suffix == ".java"]
    xml_files = [(p, read_text(p)) for p in files if p.suffix == ".xml"]
    kts_files = [(p, read_text(p)) for p in files if p.suffix == ".kts"]
    gradle_files = [(p, read_text(p)) for p in files if p.name.endswith((".gradle", ".gradle.kts"))]
    # A version catalog is where most modern projects keep every dependency.
    catalog = root / "gradle" / "libs.versions.toml"
    catalog_text = read_text(catalog) if catalog.exists() else ""
    if catalog_text:
        gradle_files.append((catalog, catalog_text))

    facts.kotlin_files = len(kt_files)
    facts.java_files = len(java_files)
    facts.xml_layouts = sum(1 for p, _ in xml_files if "/layout" in p.as_posix())
    facts.xml_themes = sum(1 for p, _ in xml_files if "/values" in p.as_posix())

    kt_all = "\n".join(t for _, t in kt_files)
    java_all = "\n".join(t for _, t in java_files)
    xml_all = "\n".join(t for _, t in xml_files)
    gradle_all = "\n".join(t for _, t in gradle_files)

    facts.uses_compose = "androidx.compose" in kt_all or "androidx.compose" in gradle_all
    facts.uses_material3_compose = (
        "androidx.compose.material3" in kt_all or "androidx.compose.material3" in gradle_all
    )
    facts.uses_material_components = (
        "com.google.android.material" in kt_all
        or "com.google.android.material" in java_all
        or "com.google.android.material" in xml_all
        or "Theme.MaterialComponents" in xml_all
    )
    facts.uses_views = (
        "androidx.appcompat" in kt_all
        or "android.widget" in java_all
        or "androidx.constraintlayout" in gradle_all
        or "androidx.recyclerview" in gradle_all
    )
    facts.uses_flutter = "flutter" in gradle_all.lower() or any(
        p.name == "pubspec.yaml" for p in root.rglob("pubspec.yaml")
        if ".git" not in p.parts
    )

    for p, text in gradle_files:
        m = re.search(r"compileSdk(?:Version)?\s*=?\s*(\d+)", text)
        if m:
            facts.compile_sdk.append(m.group(1))
        m = re.search(r"targetSdk(?:Version)?\s*=?\s*(\d+)", text)
        if m:
            facts.target_sdk.append(m.group(1))
        m = re.search(r"minSdk(?:Version)?\s*=?\s*(\d+)", text)
        if m:
            facts.min_sdk.append(m.group(1))

    def dep_version(artifact: str, text: str) -> list[str]:
        """Version literal, or "via BOM" when the artifact is declared without one."""
        out = []
        for m in re.finditer(re.escape(artifact) + r"[^\"'\n]*?[:\"']([0-9][^\"':\s]*)", text):
            out.append(m.group(1))
        if not out and re.search(re.escape(artifact) + r"[\"']", text):
            out.append("via BOM / no explicit version")
        return out

    facts.compose_bom = dep_version("androidx.compose:compose-bom", gradle_all)
    facts.material3_version = dep_version("androidx.compose.material3:material3", gradle_all)
    facts.material_components_version = dep_version("com.google.android.material:material", gradle_all)
    facts.activity_version = dep_version("androidx.activity:activity-compose", gradle_all)
    facts.haze_version = dep_version("dev.chrisbanes.haze:haze", gradle_all)

    # Version catalogs declare the version once, under [versions]; resolve it here.
    from_catalog = catalog_versions(catalog_text)
    for attr, artifact in (
        ("compose_bom", "androidx.compose:compose-bom"),
        ("material3_version", "androidx.compose.material3:material3"),
        ("material_components_version", "com.google.android.material:material"),
        ("activity_version", "androidx.activity:activity-compose"),
        ("haze_version", "dev.chrisbanes.haze:haze"),
    ):
        current = getattr(facts, attr)
        if (not current or current[0].startswith("via BOM")) and artifact in from_catalog:
            setattr(facts, attr, [from_catalog[artifact]])

    facts.compile_sdk = unique(facts.compile_sdk)
    facts.target_sdk = unique(facts.target_sdk)
    facts.min_sdk = unique(facts.min_sdk)
    facts.compose_bom = unique(facts.compose_bom)
    facts.material3_version = unique(facts.material3_version)
    facts.material_components_version = unique(facts.material_components_version)
    facts.activity_version = unique(facts.activity_version)
    facts.haze_version = unique(facts.haze_version)

    # Modules
    modules = []
    for name in ("settings.gradle.kts", "settings.gradle"):
        settings = root / name
        if not settings.exists():
            continue
        text = read_text(settings)
        modules.extend(re.findall(r'include\s*\(\s*"([^"]+)"', text))
        modules.extend(re.findall(r"include\s+['\"]([^'\"]+)['\"]", text))
    facts.modules = unique(modules)

    return facts


def analyze(root: Path, facts: ProjectFacts, max_hits: int = 40) -> list[Finding]:
    files = list(iter_source_files(root))
    kt_files = [(rel(root, p), read_text(p)) for p in files if p.suffix == ".kt"]
    java_files = [(rel(root, p), read_text(p)) for p in files if p.suffix == ".java"]
    xml_files = [(rel(root, p), read_text(p)) for p in files if p.suffix == ".xml"]
    code = kt_files + java_files
    findings: list[Finding] = []

    def add(fid, severity, dimension, title, detail, locations, fix=""):
        """Fire only when there is at least one concrete location to point at."""
        locs = list(locations)
        if not locs:
            return
        findings.append(Finding(fid, severity, dimension, title, detail, locs[:max_hits], fix))

    def add_missing(fid, severity, dimension, title, detail, present_hits, fix="", where=None):
        """Fire only when the thing is ABSENT (no grep hit). `where` says where to look."""
        if present_hits:
            return
        locs = list(where) if where else ["<project root>"]
        findings.append(Finding(fid, severity, dimension, title, detail, locs[:max_hits], fix))

    def theme_files() -> list[str]:
        out = [p for p, _ in kt_files
               if re.search(r"(Theme|Colors|Type|Shape|Style)\w*\.kt$", p)]
        out += [p for p, _ in xml_files if "/values" in p and "themes" in p]
        out += [p for p, _ in xml_files if "/values" in p and "colors" in p]
        out += [p for p, _ in xml_files if "/values" in p and "styles" in p]
        if not out:
            out = [p for p, _ in kt_files][:1]
        return out or ["<project root>"]

    def build_files() -> list[str]:
        out = [rel(root, f) for f in root.rglob("build.gradle.kts")
               if not any(s in f.parts for s in SKIP_DIRS)]
        return out or ["<project root>"]

    # -- Platform readiness ------------------------------------------------
    target = facts.target_sdk[0] if facts.target_sdk else None
    compile = facts.compile_sdk[0] if facts.compile_sdk else None
    if target and int(target) < 35:
        add("sdk.target.old", "critical", "Platform readiness",
            f"targetSdk {target} is below 35",
            "Android 15+ enforces edge-to-edge for apps targeting 35+. Older targets keep the "
            "legacy system-bar behaviour, so the app will not look or behave like a modern app.",
            [f"build.gradle(.kts): targetSdk = {target}"],
            "Raise targetSdk to 37 (or at minimum 35) in a dedicated, separately tested change.")
    if compile and int(compile) < 36:
        add("sdk.compile.old", "warning", "Platform readiness",
            f"compileSdk {compile} cannot see the Android 17 APIs",
            "Window blur APIs, the newest Material 3 Expressive components and predictive-back "
            "helpers may be unavailable.",
            [f"build.gradle(.kts): compileSdk = {compile}"],
            "Raise compileSdk to 37, then opt in to targetSdk separately.")

    # -- Expressive / theme ------------------------------------------------
    kt_all = "\n".join(t for _, t in kt_files)
    if facts.uses_compose:
        add_missing("theme.not.expressive", "warning", "Motion",
            "MaterialExpressiveTheme is not used",
            "The app is on plain Material 3, so it misses the expressive motion scheme, the "
            "expressive shapes and the expressive component set.",
            grep(r"MaterialExpressiveTheme", kt_files, 5),
            "Switch MaterialTheme(...) to MaterialExpressiveTheme(...) and pass "
            "motionScheme = MotionScheme.expressive().",
            where=theme_files())
        add("theme.motion.hardcoded", "warning", "Motion",
            "Hardcoded tween/easing instead of the motion scheme",
            "Component state animations should come from MaterialTheme.motionScheme so the whole "
            "app shares one physics.",
            grep(r"\btween\s*\(|LinearEasing|CubicBezierEasing", kt_files),
            "Replace with MaterialTheme.motionScheme.defaultSpatialSpec() / defaultEffectsSpec().")

    # -- Expressive availability ------------------------------------------
    if facts.uses_material3_compose:
        m3 = facts.material3_version[0] if facts.material3_version else None
        if m3 is None or m3.startswith("via BOM") or m3.startswith("1.4") or m3.startswith("1.3"):
            add_missing("theme.expressive.unavailable", "warning", "Motion",
                "The resolved material3 version hides the Expressive APIs",
                "In material3 1.4.0 (the Compose BOM default) MaterialExpressiveTheme, "
                "MotionScheme.expressive() and Shapes.largeIncreased are `internal`. They only "
                "become public in 1.5.0-beta01, so the expressive layer cannot be adopted without "
                "an explicit version override.",
                [],
                'Add implementation("androidx.compose.material3:material3:1.5.0-beta01") explicitly, '
                "then confirm with ./gradlew :app:dependencies | grep material3.",
                where=build_files())

    # -- Colour tokens -----------------------------------------------------
    raw_colors = grep(r"Color\(\s*0x[0-9A-Fa-f]{6,8}\s*\)", code)
    add("color.raw", "warning", "Color tokens",
        "Hardcoded colours in code",
        "Raw colours break dark mode and dynamic colour. Surfaces, text and containers must come "
        "from the theme.",
        raw_colors,
        "Move the value into the theme and reference a colorScheme role.")
    add("color.alpha.surface", "warning", "Color tokens",
        "Alpha-blended pseudo-surfaces",
        "Color.Black.copy(alpha=…) used as a card or surface background is a common MD2 habit; "
        "it stacks unpredictably and breaks contrast in dark mode.",
        grep(r"(Color\.(Black|White)\.copy\s*\(\s*alpha\s*=\s*0?\.\d+f?\s*\))", code, 20),
        "Use a surfaceContainer* role as the container colour.")

    if facts.uses_compose and "dynamicLightColorScheme" not in kt_all and "dynamicDarkColorScheme" not in kt_all:
        add_missing("color.dynamic.missing", "warning", "Color tokens",
            "Dynamic colour is not wired",
            "Apps on Android 12+ are expected to follow the user's wallpaper palette unless the "
            "product explicitly opts out.",
            [],
            "Use dynamicLightColorScheme/dynamicDarkColorScheme on API 31+ with a branded fallback "
            "for older devices, and document the opt-out if there is one.",
            where=theme_files())

    # -- Typography --------------------------------------------------------
    add("type.raw.size", "warning", "Typography",
        "Raw font sizes instead of type roles",
        "Text should use MaterialTheme.typography roles so the scale stays coherent and the app "
        "respects the user's font-size preference consistently.",
        grep(r"fontSize\s*=\s*\d+(\.\d+)?\.sp", code),
        "Map the size to the closest MaterialTheme.typography role.")
    add("type.small", "info", "Typography",
        "Very small text",
        "Anything under 11sp is below the Material minimum and is hard to read for many users.",
        grep(r"fontSize\s*=\s*(?:[0-9]|10)\.sp", code, 20),
        "Use at least labelSmall (11sp).")

    # -- Shape -------------------------------------------------------------
    off_grid = []
    for path, text in code:
        for i, line in enumerate(text.splitlines(), start=1):
            for m in re.finditer(r"RoundedCornerShape\s*\(\s*(\d+(?:\.\d+)?)\s*\.dp", line):
                value = float(m.group(1))
                if value not in ON_GRID_DP:
                    off_grid.append(f"{path}:{i}: {line.strip()[:160]}")
                    break
    add("shape.offgrid", "info", "Shape",
        "Off-scale corner radii",
        "Corner radii outside the Material shape scale make surfaces look accidental.",
        off_grid,
        "Use MaterialTheme.shapes.* (medium for cards, extraLarge for sheets, full for buttons).")

    # -- Components --------------------------------------------------------
    if facts.uses_compose:
        add("component.custom.button", "warning", "Components",
            "Hand-rolled clickable surfaces instead of Material components",
            "A Box/Text with a clickable modifier loses the component's states, semantics and "
            "expressive behaviour.",
            grep(r"\.clickable\s*\(", kt_files, 20),
            "Replace with the matching Material3 component (Button, Card, ListItem, IconButton…).")

    icons_without_desc = []
    for path, text in kt_files:
        for m in re.finditer(r"Icon\s*\(", text):
            snippet = text[m.start():m.start() + 400]
            if "contentDescription" not in snippet:
                line = text[:m.start()].count("\n") + 1
                icons_without_desc.append(f"{path}:{line}: Icon(...) without contentDescription nearby")
                if len(icons_without_desc) >= 20:
                    break
        if len(icons_without_desc) >= 20:
            break
    add("a11y.contentdescription", "warning", "Accessibility",
        "Icons without a contentDescription",
        "Icon-only controls must describe the action for TalkBack. Decorative icons should pass "
        "an explicit null so they are not announced.",
        icons_without_desc,
        "Add contentDescription to every interactive icon; pass null for decorative ones.")

    add("a11y.touchtarget", "warning", "Accessibility",
        "Explicit small touch targets",
        "Interactive elements must be at least 48dp in both dimensions.",
        small_touch_targets(code),
        "Use Modifier.defaultMinSize(minWidth = 48.dp, minHeight = 48.dp) or "
        "Modifier.minimumInteractiveComponentSize().")

    # -- Strings -----------------------------------------------------------
    hardcoded_strings = []
    for path, text in kt_files:
        for i, line in enumerate(text.splitlines(), start=1):
            if re.search(r'\bText\s*\(\s*"', line) and "stringResource" not in line:
                hardcoded_strings.append(f"{path}:{i}: {line.strip()[:160]}")
                if len(hardcoded_strings) >= 20:
                    break
        if len(hardcoded_strings) >= 20:
            break
    add("i18n.hardcoded", "info", "Accessibility",
        "Hardcoded user-facing strings",
        "Hardcoded strings block localisation and make translation impossible.",
        hardcoded_strings,
        "Move them to strings.xml and use stringResource().")

    # -- Glass / blur ------------------------------------------------------
    add("glass.wrong.mechanism", "critical", "Glass/translucency",
        "Modifier.blur() used where a backdrop blur was meant",
        "Modifier.blur() blurs the composable's OWN content — it cannot see what is behind it. "
        "It is the classic 'frosted card that is just a blurry card' bug.",
        grep(r"\.blur\s*\(", kt_files, 20),
        "Use Haze: hazeSource on the content, hazeBlur/hazeGlass on a sibling surface.")

    if facts.haze_version:
        add("glass.version", "info", "Glass/translucency",
            "Haze dependency detected",
            "Haze " + ", ".join(facts.haze_version) + " in use. Keep every Haze artifact on the "
            "same version — they are released in lockstep.",
            build_files(),
            "Align haze, haze-blur, haze-blur-materials, haze-glass and their material3 variants.")
    else:
        add_missing("glass.missing", "info", "Glass/translucency",
            "No frosted-glass dependency present",
            "If the upgrade calls for a frosted layer, the app needs the Haze artifacts "
            "(dev.chrisbanes.haze:haze, haze-blur, haze-glass at one version).",
            [],
            "Add the artifacts in the app module, all on the same version.",
            where=build_files())

    # -- Edge to edge ------------------------------------------------------
    if facts.uses_compose and "enableEdgeToEdge" not in kt_all and "setDecorFitsSystemWindows" not in kt_all:
        add_missing("edge.toedge.missing", "warning", "Platform readiness",
            "Edge-to-edge is not enabled",
            "Without edge-to-edge the app is letterboxed by the system bars and the glass chrome "
            "has nothing to sit against.",
            [],
            "Call enableEdgeToEdge() in the activity and handle WindowInsets in the scaffold.",
            where=build_files())

    # -- Adaptive layout ---------------------------------------------------
    if facts.uses_compose and "currentWindowAdaptiveInfo" not in kt_all and "NavigationSuiteScaffold" not in kt_all:
        add_missing("adaptive.missing", "warning", "Layout/adaptive",
            "No adaptive navigation or window size handling",
            "A fixed bottom navigation bar breaks on tablets and foldables.",
            [],
            "Use NavigationSuiteScaffold and currentWindowAdaptiveInfo() to pick bar/rail/drawer.",
            where=build_files())

    # -- Views / MD2 -------------------------------------------------------
    if facts.uses_material_components:
        add("md2.leftover", "critical", "Components",
            "Material Components (MD2 themes) still in use",
            "com.google.android.material with Theme.MaterialComponents is the pre-Material-3 "
            "look: no surface-container roles, no expressive components.",
            grep(r"Theme\.MaterialComponents", xml_files, 20),
            "Migrate to Theme.Material3.* and the MD3 attribute set.")

    # -- Performance -------------------------------------------------------
    if not any("baselineprofile" in p.lower() for p in facts.modules):
        add_missing("perf.baseline", "info", "Performance",
            "No baseline profile module detected",
            "A BaselineProfile module measurably improves startup and scroll performance in release "
            "builds — especially relevant once a glass layer is added.",
            [],
            "Add a :baselineprofile module and generate a profile with macrobenchmark.",
            where=build_files())

    findings.sort(key=lambda f: (SEVERITY_ORDER.get(f.severity, 9), -f.count()))
    return findings


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


def render_markdown(facts: ProjectFacts, findings: list[Finding]) -> str:
    lines: list[str] = []
    lines.append("# UI scan report")
    lines.append("")
    lines.append(f"**Project**: `{facts.root}`")
    lines.append("")

    lines.append("## Stack detected")
    lines.append("")
    lines.append("| Item | Value |")
    lines.append("|------|-------|")
    lines.append(f"| UI stack | {_stack_summary(facts)} |")
    lines.append(f"| Compose BOM | {', '.join(facts.compose_bom) or '—'} |")
    lines.append(f"| material3 | {', '.join(facts.material3_version) or '—'} |")
    lines.append(f"| Material Components (Views) | {', '.join(facts.material_components_version) or '—'} |")
    lines.append(f"| activity-compose | {', '.join(facts.activity_version) or '—'} |")
    lines.append(f"| Haze | {', '.join(facts.haze_version) or '—'} |")
    lines.append(f"| compileSdk | {', '.join(facts.compile_sdk) or '—'} |")
    lines.append(f"| targetSdk | {', '.join(facts.target_sdk) or '—'} |")
    lines.append(f"| minSdk | {', '.join(facts.min_sdk) or '—'} |")
    lines.append(f"| Kotlin files | {facts.kotlin_files} |")
    lines.append(f"| Java files | {facts.java_files} |")
    lines.append(f"| Layout XML | {facts.xml_layouts} |")
    lines.append(f"| Values XML (themes) | {facts.xml_themes} |")
    lines.append("")

    critical = [f for f in findings if f.severity == "critical"]
    warning = [f for f in findings if f.severity == "warning"]
    info = [f for f in findings if f.severity == "info"]
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- **{len(critical)}** critical · **{len(warning)}** warnings · **{len(info)}** notes")
    lines.append("")

    if not findings:
        lines.append("No mechanical issues detected. Continue with the manual audit in "
                     "`references/audit-rubric.md` — the scanner cannot judge hierarchy, taste "
                     "or visual balance.")
        lines.append("")
        return "\n".join(lines)

    for group, label in ((critical, "Critical"), (warning, "Warnings"), (info, "Notes")):
        if not group:
            continue
        lines.append(f"## {label}")
        lines.append("")
        for f in group:
            lines.append(f"### {f.title}  `[{f.dimension}]`")
            lines.append("")
            lines.append(f.detail)
            lines.append("")
            if f.fix:
                lines.append(f"**Fix**: {f.fix}")
                lines.append("")
            if f.locations:
                lines.append("<details><summary>Locations</summary>")
                lines.append("")
                lines.append("```")
                for loc in f.locations[:20]:
                    lines.append(loc)
                if f.count() > 20:
                    lines.append(f"... and {f.count() - 20} more")
                lines.append("```")
                lines.append("")
                lines.append("</details>")
                lines.append("")

    lines.append("## Next")
    lines.append("")
    lines.append("1. Open every critical location and confirm it by reading the file.")
    lines.append("2. Build the screen matrix from `references/audit-rubric.md` — the scanner "
                 "cannot see hierarchy.")
    lines.append("3. Plan the workstreams in `assets/templates/upgrade-plan.md`.")
    lines.append("")
    return "\n".join(lines)


def render_text(facts: ProjectFacts, findings: list[Finding]) -> str:
    lines = [f"UI scan: {facts.root}",
             f"  stack: {_stack_summary(facts)}",
             f"  targetSdk: {', '.join(facts.target_sdk) or '-'}  compileSdk: {', '.join(facts.compile_sdk) or '-'}",
             f"  findings: {len(findings)}"]
    for f in findings:
        lines.append("")
        lines.append(f"[{f.severity.upper()}] {f.title} ({f.dimension}) x{f.count()}")
        lines.append(f"  {f.detail}")
        if f.fix:
            lines.append(f"  fix: {f.fix}")
        for loc in f.locations[:5]:
            lines.append(f"    {loc}")
        if f.count() > 5:
            lines.append(f"    ... and {f.count() - 5} more")
    return "\n".join(lines)


def _stack_summary(facts: ProjectFacts) -> str:
    parts = []
    if facts.uses_flutter:
        parts.append("Flutter")
    if facts.uses_compose:
        parts.append("Compose" + (" (Material 3)" if facts.uses_material3_compose else ""))
    if facts.uses_views:
        parts.append("Views")
    if facts.uses_material_components and not facts.uses_compose:
        parts.append("Material Components (MD2/MD3)")
    if not parts:
        parts.append("unknown")
    return " + ".join(parts)


def render_json(facts: ProjectFacts, findings: list[Finding]) -> str:
    return json.dumps({
        "project": asdict(facts),
        "findings": [asdict(f) for f in findings],
    }, indent=2)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Static UI/UX reconnaissance for Android projects (material-3-frosted phase 0).")
    parser.add_argument("path", help="Path to the Android project root")
    parser.add_argument("--format", choices=("markdown", "json", "text"), default="markdown")
    parser.add_argument("--max-hits", type=int, default=40, help="Max locations per finding (default 40)")
    parser.add_argument("--fail-on", choices=("critical", "warning", "info"), default=None,
                        help="Exit with code 2 if any finding at this severity or worse exists")
    args = parser.parse_args(argv)

    root = Path(args.path).expanduser().resolve()
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 1

    facts = collect_facts(root)
    findings = analyze(root, facts, max_hits=args.max_hits)

    if args.format == "markdown":
        print(render_markdown(facts, findings))
    elif args.format == "json":
        print(render_json(facts, findings))
    else:
        print(render_text(facts, findings))

    if args.fail_on:
        threshold = SEVERITY_ORDER[args.fail_on]
        if any(SEVERITY_ORDER.get(f.severity, 9) <= threshold for f in findings):
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
