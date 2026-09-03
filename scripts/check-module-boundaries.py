#!/usr/bin/env python3
"""Audit the modular-monolith package and Maven dependency boundaries."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from collections import OrderedDict
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BACKEND = ROOT / "spectra-admin"
NS = {"m": "http://maven.apache.org/POM/4.0.0"}

MODULES = OrderedDict(
    (
        ("spectra-common", ("spectra-common", "com.devops00.spectra.common")),
        ("spectra-config", ("spectra-config", "com.devops00.spectra.config")),
        ("spectra-framework", ("spectra-framework", "com.devops00.spectra.framework")),
        ("spectra-launch", ("spectra-launch", "com.devops00.spectra.launch")),
        ("spectra-security-base", ("spectra-starter/spectra-security-base", "com.devops00.spectra.security.base")),
        ("spectra-security-spring-boot-starter", ("spectra-starter/spectra-security-spring-boot-starter", "com.devops00.spectra.security")),
        ("spectra-core", ("spectra-modules/spectra-core", "com.devops00.spectra.core")),
        ("spectra-workflow", ("spectra-modules/spectra-workflow", "com.devops00.spectra.workflow")),
        ("spectra-oa", ("spectra-modules/spectra-oa", "com.devops00.spectra.oa")),
    )
)

BUSINESS_PREFIXES = (
    "com.devops00.spectra.core.",
    "com.devops00.spectra.oa.",
    "com.devops00.spectra.workflow.",
    "com.devops00.spectra.erp.",
)
OPTIONAL_BUSINESS_PREFIXES = BUSINESS_PREFIXES[1:]
FORBIDDEN = (
    ("应用级租户上下文", re.compile(r"\bTenantContext\b", re.I)),
    ("租户解析器", re.compile(r"\bTenantResolver\b", re.I)),
    ("租户服务", re.compile(r"\bTenantService\b", re.I)),
    ("租户 ID", re.compile(r"\btenantId\b", re.I)),
    ("应用租户字段", re.compile(r"\btenant_id\b", re.I)),
    ("多租户关键词", re.compile(r"multi[-_ ]?tenant", re.I)),
    ("多租户中文关键词", re.compile(r"多租户")),
    ("SaaS 关键词", re.compile(r"\bSaaS\b", re.I)),
    ("Nacos/服务发现关键词", re.compile(r"nacos|spring[-.]cloud|service[-.]?discovery|discoveryClient|eureka|consul", re.I)),
)


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def main_java_files(relative_root: str) -> list[Path]:
    root = BACKEND / relative_root / "src/main/java"
    return sorted(root.rglob("*.java")) if root.is_dir() else []


def imports(path: Path) -> list[str]:
    return re.findall(r"^\s*import\s+.*$", text(path), re.MULTILINE)


def package_line(path: Path) -> str:
    return next(iter(re.findall(r"^\s*package\s+.*$", text(path), re.MULTILINE)), "")


def pom_data(path: Path) -> tuple[str, list[str]]:
    root = ET.fromstring(text(path))
    artifact = root.findtext("m:artifactId", namespaces=NS) or ""
    deps = [node.text or "" for node in root.findall("m:dependencies/m:dependency/m:artifactId", NS)]
    return artifact, deps


def add(violations: list[str], rule: str, path: Path | None, message: str) -> None:
    location = f"{path}: " if path else ""
    violations.append(f"{rule}: {location}{message}")


def main() -> int:
    violations: list[str] = []
    source_files = sorted(
        path
        for path in BACKEND.rglob("*")
        if path.is_file()
        and path.suffix.lower() in {".java", ".yml", ".yaml", ".xml", ".properties"}
        and "target" not in path.parts
        and "src" in path.parts
        and "test" not in path.parts
        and path.name != "pom.xml"
        and not path.name.endswith(".flattened-pom.xml")
        and path.name != ".mise.local.toml"
    )
    pom_files = sorted(path for path in BACKEND.rglob("pom.xml") if "target" not in path.parts)
    root_pom = BACKEND / "pom.xml"

    for path in source_files:
        content = text(path)
        for name, pattern in FORBIDDEN:
            match = pattern.search(content)
            if match:
                line = content[: match.start()].count("\n") + 1
                add(violations, name, path, f"第 {line} 行命中: {content.splitlines()[line - 1].strip()}")

    for path in main_java_files("spectra-modules/spectra-core"):
        for prefix in OPTIONAL_BUSINESS_PREFIXES:
            if any(prefix in line for line in imports(path)):
                add(violations, "Core 不得依赖可选业务实现", path, f"发现 import: {prefix}")

    for path in main_java_files("spectra-launch"):
        if not re.search(r"^\s*package\s+com\.devops00\.spectra\.launch(?:\.|;)", package_line(path)):
            add(violations, "Launch 只允许装配代码", path, f"包声明不属于 launch: {package_line(path)}")
        if re.search(r"(Controller|Entity|Mapper|Repository|Service)\.java$", path.name):
            add(violations, "Launch 只允许装配代码", path, "启动模块不得包含业务实现类文件")
        if re.search(r"^\s*@(RestController|Controller|Service|Repository|Mapper|Entity)\b", text(path), re.MULTILINE):
            add(violations, "Launch 只允许装配代码", path, "启动模块不得声明业务 Spring/MyBatis 组件")

    for layer, relative_root in (("common", "spectra-common"), ("framework", "spectra-framework")):
        for path in main_java_files(relative_root):
            for prefix in BUSINESS_PREFIXES:
                if any(prefix in line for line in imports(path)):
                    add(violations, f"{layer} 不得反向依赖业务模块", path, f"发现 import: {prefix}")

    for relative_root in (
        "spectra-modules/spectra-core",
        "spectra-modules/spectra-oa",
        "spectra-modules/spectra-workflow",
    ):
        for path in main_java_files(relative_root):
            if any("com.devops00.spectra.launch." in line for line in imports(path)):
                add(violations, "业务模块不得依赖 launch", path, "发现 launch import")

    for path in source_files:
        if path.suffix == ".java" and "src/main/java" in path.as_posix() and re.search(r"^\s*@Audit\b", text(path), re.MULTILINE):
            if "import com.devops00.spectra.common.audit.Audit;" not in text(path):
                add(violations, "统一审计入口", path, "@Audit 必须来自 common.audit.Audit")

    for relative in (
        "spectra-starter/spectra-log-base/src/main/java/com/devops00/spectra/log/base/annotation/ULog.java",
        "spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/common/listener/ulog/ULogListener.java",
        "spectra-starter/spectra-log-base/src/main/java/com/devops00/spectra/log/base/entity/ULogEntity.java",
        "spectra-starter/spectra-log-base/src/main/java/com/devops00/spectra/log/base/publisher/ULogEventPublisher.java",
    ):
        if (BACKEND / relative).exists():
            add(violations, "统一审计入口", None, f"旧 ULog 类型不得恢复: {relative}")
    for relative in ("spectra-starter/spectra-log-base", "spectra-starter/spectra-log-spring-boot-starter"):
        if (BACKEND / relative).exists():
            add(violations, "统一审计入口", None, f"旧日志模块不得恢复: {relative}")

    health_contributors = (
        "spectra-framework/src/main/java/com/devops00/spectra/framework/health/DataSourceHealthContributor.java",
        "spectra-framework/src/main/java/com/devops00/spectra/framework/health/RedisHealthContributor.java",
        "spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/scheduler/health/SchedulerHealthIndicator.java",
        "spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/health/NotificationHealthIndicator.java",
        "spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/health/FileStorageHealthIndicator.java",
        "spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/health/FlowableHealthContributor.java",
    )
    for relative in health_contributors:
        path = BACKEND / relative
        if not path.exists():
            add(violations, "统一健康 contributor", None, f"缺少健康实现: {relative}")
        elif "com.devops00.spectra.common.health.DependencyHealthContributor" not in text(path):
            add(violations, "统一健康 contributor", None, f"健康实现未使用统一协议: {relative}")
    for relative in (
        "spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/health/CoreHealthRegistry.java",
        "spectra-framework/src/main/java/com/devops00/spectra/framework/health/ActuatorHealthContributorAdapter.java",
    ):
        if not (BACKEND / relative).exists():
            add(violations, "统一健康 contributor", None, f"缺少统一健康入口: {relative}")

    policies = {
        "spectra-common": ("spectra-core", "spectra-oa", "spectra-workflow", "spectra-erp", "spectra-framework", "spectra-starter"),
        "spectra-framework": ("spectra-core", "spectra-oa", "spectra-workflow", "spectra-erp"),
        "spectra-core": ("spectra-modules", "spectra-starter", "spectra-oa", "spectra-workflow", "spectra-erp"),
        "spectra-launch": ("spectra-modules", "spectra-starter"),
    }
    for path in pom_files:
        try:
            artifact, deps = pom_data(path)
        except ET.ParseError as exc:
            add(violations, "Maven POM 解析", path, str(exc))
            continue
        for dependency in deps:
            if dependency in policies.get(artifact, ()):
                add(violations, "Maven 直接依赖方向", path, f"[{artifact}] 不得直接依赖 {dependency}")

    if violations:
        print("发现架构边界违规：")
        for violation in sorted(set(violations)):
            print(f"- {violation}")
        return 1

    print("模块源码角色盘点（文件名后缀统计，作为迁移清单索引，不替代语义审查）：")
    for name, (relative_root, _) in MODULES.items():
        main_files = main_java_files(relative_root)
        test_root = BACKEND / relative_root / "src/test/java"
        test_files = sorted(test_root.rglob("*.java")) if test_root.is_dir() else []
        values = {
            "MainJava": len(main_files),
            "TestJava": len(test_files),
            "Controllers": sum(path.name.endswith("Controller.java") for path in main_files),
            "Entities": sum(path.name.endswith("Entity.java") for path in main_files),
            "Mappers": sum(path.name.endswith("Mapper.java") for path in main_files),
            "Services": sum(bool(re.search(r"Service(?:Impl)?\.java$", path.name)) for path in main_files),
            "Configurations": sum(bool(re.search(r"(?:Configuration|Config)\.java$", path.name)) for path in main_files),
            "HealthIndicators": sum(path.name.endswith("HealthIndicator.java") for path in main_files),
            "Listeners": sum(path.name.endswith("Listener.java") for path in main_files),
            "Handlers": sum(path.name.endswith("Handler.java") for path in main_files),
        }
        print(f"- {name}: " + ", ".join(f"{key}={value}" for key, value in values.items()))

    dependency_inventory: list[tuple[str, list[str]]] = []
    for path in pom_files:
        try:
            artifact, dependencies = pom_data(path)
        except ET.ParseError:
            continue
        if artifact and dependencies:
            dependency_inventory.append((artifact, dependencies))
    print("当前 Maven 直接依赖盘点（仅记录现状，后续任务再按归属矩阵收敛）：")
    for artifact, dependencies in sorted(dependency_inventory):
        print(f"- {artifact}: {', '.join(dependencies)}")
    declared_modules: list[str] = []
    if root_pom.is_file():
        try:
            root = ET.fromstring(text(root_pom))
            declared_modules = [node.text or "" for node in root.findall("m:modules/m:module", NS)]
        except ET.ParseError:
            pass
    print(
        "Status: PASS; "
        f"scanned_source_files={len(source_files)}; "
        f"scanned_pom_files={len(pom_files)}; "
        f"maven_root_modules={', '.join(declared_modules)}; "
        f"modules={len(MODULES)}; "
        f"forbidden_rules_checked={len(FORBIDDEN)}; "
        "forbidden_matches=0; architecture_violations=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
