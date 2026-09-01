#!/usr/bin/env python3
"""Validate documentation links, project facts and configuration templates."""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"


def fail(errors: list[str]) -> int:
    for error in errors:
        print(error, file=sys.stderr)
    return 1


def resolve_wikilink(source: Path, target: str, markdown_files: list[Path]) -> bool:
    target = target.split("|", 1)[0].split("#", 1)[0].strip()
    if not target or target == "wikilink":
        return True
    normalized = target.replace("/", "/")
    candidates: list[Path] = []
    if Path(normalized).suffix:
        candidates.extend((DOCS / normalized, source.parent / normalized))
        candidates.extend(path for path in markdown_files if path.name == Path(normalized).name)
    else:
        candidates.extend((DOCS / f"{normalized}.md", source.parent / f"{normalized}.md"))
        leaf = f"{Path(normalized).name}.md"
        candidates.extend(path for path in markdown_files if path.name == leaf)
    return any(path.exists() for path in candidates)


def main() -> int:
    if shutil.which("rg") is None:
        return fail(["未找到 rg（ripgrep），无法执行文档事实校验。"])
    errors: list[str] = []
    markdown_files = sorted(DOCS.rglob("*.md"))
    wiki_pattern = re.compile(r"\[\[([^\]]+)\]\]")
    for path in markdown_files:
        content = path.read_text(encoding="utf-8")
        for match in wiki_pattern.finditer(content):
            if not resolve_wikilink(path, match.group(1), markdown_files):
                line = content[: match.start()].count("\n") + 1
                relative = path.relative_to(ROOT).as_posix()
                errors.append(f"失效 wikilink: {relative}:{line} [[{match.group(1)}]]")

    java_files = sorted((ROOT / "spectra-admin").rglob("*.java"))
    controller_files = [
        path
        for path in java_files
        if re.search(r"^\s*@RestController\s*$", path.read_text(encoding="utf-8"), re.MULTILINE)
    ]
    controller_names = sorted({path.stem for path in controller_files})
    entity_count = sum("@TableName" in path.read_text(encoding="utf-8") for path in java_files)
    overview = (DOCS / "00-项目总览.md").read_text(encoding="utf-8")
    if f"{entity_count} 个 Entity" not in overview:
        errors.append(f"项目总览中的 Entity 数量不是源码实际值 {entity_count}。")
    if f"{len(controller_names)} 个 Controller" not in overview:
        errors.append(f"项目总览中的 Controller 数量不是源码实际值 {len(controller_names)}。")

    expectations = (
        ("spectra-admin/.mise.local.toml.example", r'SERVER_PORT\s*=\s*"4004"', "后端模板端口 4004"),
        ("spectra-admin/.mise.local.toml.example", r'SERVER_SSL_ENABLED\s*=\s*"true"', "后端模板首次启动启用 HTTPS"),
        ("spectra-ui/.env.example", r"VITE_API_URL=https://127\.0\.0\.1:4004/", "Web 模板直连 HTTPS 4004"),
    )
    for relative, pattern, description in expectations:
        if not re.search(pattern, (ROOT / relative).read_text(encoding="utf-8")):
            errors.append(f"配置模板与首次启动文档不一致：{description}（{relative}）。")

    dev_config = (ROOT / "spectra-admin/spectra-config/src/main/resources/application-dev.yml").read_text(
        encoding="utf-8"
    )
    required = sorted(set(re.findall(r"\$\{([A-Z][A-Z0-9_]*)(?::[^}]*)?\}", dev_config)))
    template = (ROOT / "spectra-admin/.mise.local.toml.example").read_text(encoding="utf-8")
    provided = sorted(set(re.findall(r"^([A-Z][A-Z0-9_]*)\s*=", template, re.MULTILINE)))
    missing = [name for name in required if name not in provided]
    unexpected = [name for name in provided if name not in required and name not in {"SERVER_SSL_ENABLED"}]
    if missing:
        errors.append(f"后端本机模板缺少 application-dev.yml 变量：{', '.join(missing)}。")
    if unexpected:
        errors.append(f"后端本机模板包含源码未使用的旧变量：{', '.join(unexpected)}。")

    for relative in ("10-后端/90-API总览.md", "70-AI速查/04-API端点.md"):
        content = (DOCS / relative).read_text(encoding="utf-8")
        documented = sorted(set(re.findall(r"`?([A-Z][A-Za-z0-9]+Controller)`?", content)))
        missing_names = sorted(set(controller_names) - set(documented))
        if missing_names:
            errors.append(f"{relative} 缺少 Controller: {', '.join(missing_names)}")

    stale_patterns = ("logicflow-flowable\\", "document/Plans/", "31-OA建表SQL.sql", "20-知识库/", "D:\\Develop\\", "C:\\Users\\")
    stale_targets = [DOCS, ROOT / "README.md", ROOT / "AGENTS.md"]
    stale_targets.extend(ROOT / relative for relative in (
        "spectra-admin/README.md",
        "spectra-admin/AGENTS.md",
        "spectra-ui/README.md",
        "spectra-ui/AGENTS.md",
        "logicflow-plugin-flowable/README.md",
        "logicflow-plugin-flowable/AGENTS.md",
    ))
    for pattern in stale_patterns:
        for target in stale_targets:
            paths = [target] if target.is_file() else target.rglob("*")
            for path in paths:
                if path.is_file() and ".git" not in path.parts:
                    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                        if pattern in line:
                            errors.append(f"过期内容: {path.relative_to(ROOT).as_posix()}:{number}: {line}")

    plans = DOCS / "90-计划"
    if plans.exists():
        for path in plans.rglob("P-*.md"):
            head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:45])
            if re.search(r"\*\*已完成(?:（[^）]+）)?\*\*|\*\*全部阶段已完成\*\*|status:\s*(?:completed|done)", head):
                errors.append(f"已完成计划仍在执行计划目录: {path.relative_to(ROOT).as_posix()}")

    if errors:
        return fail(errors)
    print(f"文档检查通过：{len(markdown_files)} 个 Markdown 文件，{entity_count} 个 Entity，{len(controller_names)} 个 Controller。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
