#!/usr/bin/env python3
"""Regenerate deployment docs from recipes/recipe.yml and modules/.

This script is idempotent and makes no external API calls.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RECIPE_PATH = PROJECT_ROOT / "recipes" / "recipe.yml"
DEPLOYMENT_PATH = PROJECT_ROOT / "docs" / "DEPLOYMENT.md"
MODULES_DIR = PROJECT_ROOT / "modules"


def load_recipe(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def format_yaml_block(label: str, data: object) -> str:
    return f"""### {label}

```yaml
{yaml.safe_dump(data, default_flow_style=False).strip()}
```
"""


def discover_modules(modules_dir: Path) -> list[dict]:
    if not modules_dir.exists():
        return []

    modules: list[dict] = []
    for entry in sorted(modules_dir.iterdir()):
        module_yml = entry / "module.yml"
        if not module_yml.is_file():
            continue
        try:
            with module_yml.open("r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
        except yaml.YAMLError as exc:
            data = {"_error": str(exc)}

        description = data.get("description") if isinstance(data, dict) else None
        modules.append(
            {
                "name": entry.name,
                "description": description or "Custom BlueBuild module.",
                "path": str(module_yml.relative_to(modules_dir.parent)),
            }
        )
    return modules


def get_modules(recipe: dict) -> list[dict]:
    mods = recipe.get("modules")
    return mods if isinstance(mods, list) else []


def build_kargs_section(recipe: dict) -> str:
    kargs: list[str] = []
    for mod in get_modules(recipe):
        if isinstance(mod, dict) and mod.get("type") == "kargs":
            kargs.extend(mod.get("kargs", []))
    if not kargs:
        return "### Kernel arguments\n\nNo kernel arguments declared in recipe.\n"
    return format_yaml_block("Kernel arguments", {"kargs": kargs})


def build_services_section(recipe: dict) -> str:
    system_services: list[str] = []
    user_services: list[str] = []
    for mod in get_modules(recipe):
        if isinstance(mod, dict) and mod.get("type") == "systemd":
            system_cfg = mod.get("system", {})
            user_cfg = mod.get("user", {})
            if isinstance(system_cfg, dict):
                system_services.extend(system_cfg.get("enabled", []))
            if isinstance(user_cfg, dict):
                user_services.extend(user_cfg.get("enabled", []))
    if not system_services and not user_services:
        return "### Enabled systemd services\n\nNo systemd services declared in recipe.\n"
    payload: dict[str, object] = {}
    if system_services:
        payload["system"] = {"enabled": system_services}
    if user_services:
        payload["user"] = {"enabled": user_services}
    return format_yaml_block("Enabled systemd services", {"systemd": payload})


def build_flatpak_section(recipe: dict) -> str:
    flatpaks: list[str] = []
    for mod in get_modules(recipe):
        if isinstance(mod, dict) and mod.get("type") == "default-flatpaks":
            for cfg in mod.get("configurations", []):
                if isinstance(cfg, dict):
                    flatpaks.extend(cfg.get("install", []))
    if not flatpaks:
        return "### Installed Flatpaks\n\nNo Flatpaks declared in recipe.\n"
    return format_yaml_block("Installed Flatpaks", {"containers": {"flatpaks": flatpaks}})


def build_modules_section(modules: list[dict]) -> str:
    if not modules:
        return "### Custom modules\n\nNo custom modules found in `modules/` yet.\n"

    lines = ["### Custom modules\n"]
    for mod in modules:
        lines.append(f"- **`{mod['name']}`** — {mod['description']} (`{mod['path']}`)")
    lines.append("")
    return "\n".join(lines)


def replace_section(content: str, marker_name: str, new_body: str) -> str:
    begin = f"<!-- BEGIN {marker_name} -->"
    end = f"<!-- END {marker_name} -->"
    pattern = re.compile(
        re.escape(begin) + r".*?" + re.escape(end),
        re.DOTALL,
    )
    replacement = f"{begin}\n{new_body}{end}"
    if pattern.search(content):
        return pattern.sub(replacement, content)
    # Append at the end if markers are missing.
    return f"{content.rstrip()}\n\n{replacement}\n"


def main() -> int:
    if not RECIPE_PATH.exists():
        print(f"error: recipe not found: {RECIPE_PATH}", file=sys.stderr)
        return 1

    recipe = load_recipe(RECIPE_PATH)
    modules = discover_modules(MODULES_DIR)

    if not DEPLOYMENT_PATH.exists():
        DEPLOYMENT_PATH.parent.mkdir(parents=True, exist_ok=True)
        DEPLOYMENT_PATH.write_text("# Deployment Guide\n", encoding="utf-8")

    content = DEPLOYMENT_PATH.read_text(encoding="utf-8")

    content = replace_section(content, "KARGS_SECTION", build_kargs_section(recipe))
    content = replace_section(content, "SERVICES_SECTION", build_services_section(recipe))
    content = replace_section(content, "FLATPAK_SECTION", build_flatpak_section(recipe))
    content = replace_section(content, "MODULES_SECTION", build_modules_section(modules))

    DEPLOYMENT_PATH.write_text(content, encoding="utf-8")
    print(f"updated {DEPLOYMENT_PATH.relative_to(PROJECT_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
