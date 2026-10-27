#!/usr/bin/env python3
import json
import sys
from collections import Counter
from pathlib import Path


def fixed_versions(vuln):
    values = vuln.get("fix_versions") or []
    return ", ".join(values) if values else "нет данных"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: triage_report.py AUDIT.json REPORT.md")

    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    data = json.loads(source.read_text(encoding="utf-8"))
    dependencies = data.get("dependencies", [])
    findings_by_key = {}
    for dep in dependencies:
        for vuln in dep.get("vulns", []):
            finding = {
                    "package": dep.get("name", "unknown"),
                    "version": dep.get("version", "unknown"),
                    "id": vuln.get("id", "unknown"),
                    "fix": fixed_versions(vuln),
                }
            findings_by_key[(finding["package"], finding["version"], finding["id"])] = finding
    findings = list(findings_by_key.values())

    counts = Counter(item["package"] for item in findings)
    lines = [
        "# Triage summary",
        "",
        f"Source: `{source.as_posix()}`",
        "",
        f"- Components checked: **{len(dependencies)}**",
        f"- Unique vulnerability IDs: **{len(findings)}**",
        f"- Affected components: **{len(counts)}**",
        "",
        "## Findings by component",
        "",
        "| Component | Records |",
        "|---|---:|",
    ]
    for package, count in sorted(counts.items()):
        lines.append(f"| {package} | {count} |")
    if not counts:
        lines.append("| — | 0 |")

    lines += [
        "",
        "## Findings",
        "",
        "| Component | Version | Vulnerability | Fix versions | Initial decision |",
        "|---|---:|---|---|---|",
    ]
    visible_findings = sorted(findings, key=lambda item: (item["package"], item["id"]))[:15]
    for item in visible_findings:
        lines.append(
            f"| {item['package']} | {item['version']} | {item['id']} | {item['fix']} | Проверить применимость |"
        )
    if not findings:
        lines.append("| — | — | Findings not reported | — | Повторная проверка завершена |")
    elif len(findings) > len(visible_findings):
        lines.append("")
        lines.append(f"Показаны первые {len(visible_findings)} записей из {len(findings)}; полный результат сохранён в JSON.")

    lines += [
        "",
        "## Triage checklist",
        "",
        "1. Проверить, используется ли уязвимая функция в приложении.",
        "2. Уточнить наличие публичного exploit и условия эксплуатации.",
        "3. Сопоставить техническую критичность с доступностью компонента и данными, которые он обрабатывает.",
        "4. Выбрать совместимую исправленную версию и оценить риск обновления.",
        "5. После изменения зависимости повторить формирование SBOM и аудит.",
        "",
        "Автоматический сканер показывает потенциальные проблемы; итоговое решение требует контекста приложения.",
        "",
    ]
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines), encoding="utf-8")
    print(f"Report written to {target}")


if __name__ == "__main__":
    main()

