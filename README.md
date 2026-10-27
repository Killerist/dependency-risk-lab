
# Dependency Risk Lab

Воспроизводимый лабораторный кейс по контролю уязвимых зависимостей: от состава ПО до повторной проверки после исправлений.

## Задача

Показать не запуск одного сканера, а полный процесс управления риском сторонних компонентов:

```text
Python dependencies
        ↓
Trivy → CycloneDX SBOM
        ↓
Dependency-Track portfolio
        ↓
Trivy Server analyzer + vulnerability intelligence
        ↓
triage → dependency update → repeat scan
```

`pip-audit` используется как независимая локальная перепроверка. Намеренно устаревшие зависимости нужны только для анализа: проект не устанавливает и не запускает их.

## Что реализовано

- локальный стенд OWASP Dependency-Track 5.2.1 и PostgreSQL в Docker Compose;
- отдельный Trivy Server 0.76.1 в той же внутренней сети Compose;
- генерация CycloneDX SBOM с помощью Trivy для состояний `before` и `after`;
- загрузка SBOM в Dependency-Track через REST API без хранения ключа в репозитории;
- независимый аудит зафиксированных Python-зависимостей с помощью `pip-audit`;
- автоматическое формирование triage-отчёта и сравнение результатов;
- CI workflow, который сохраняет SBOM и отчёты и блокирует повторную проверку при регрессии.

Проверенный локальный результат сохранён в [`evidence/validation.md`](evidence/validation.md) и [`reports/before-after.md`](reports/before-after.md): пять устаревших прямых зависимостей дали 64 уникальных идентификатора уязвимостей, а после обновления повторная проверка не обнаружила известных уязвимостей. Это идентификаторы CVE, GHSA и PYSEC, а не 64 отдельных CVE.

## Структура

```text
.
├── docker-compose.yml
├── demo-app/
│   ├── requirements-before.txt
│   └── requirements-after.txt
├── scripts/
│   ├── generate-trivy-sbom.sh
│   ├── upload-dtrack.sh
│   ├── audit.sh
│   ├── generate-sbom.sh
│   ├── triage_report.py
│   └── compare_results.py
├── sbom/
├── evidence/
├── reports/
└── .github/workflows/security-checks.yml
```

## 1. Запуск Dependency-Track и Trivy Server

Создайте локальный файл окружения и замените пример пароля:

```bash
cp .env.example .env
docker compose config
docker compose up -d
```

- Dependency-Track API: `http://localhost:8080`
- Dependency-Track UI: `http://localhost:8081`
- Trivy Server доступен только другим контейнерам в сети Compose и не публикуется на хост.

Первый запуск и синхронизация источников уязвимостей могут занять несколько минут.

### Подключение Trivy к Dependency-Track

В административной панели Dependency-Track откройте `Analyzers → Trivy` и задайте:

- Enable: `true`;
- Base URL: `http://trivy:8080`;
- API Token: оставить пустым для изолированной локальной лаборатории;
- Ignore Unfixed: `false`;
- Scan library: `true`;
- Scan OS: `false` для этого Python-кейса.

В Dependency-Track 5.2 токен Trivy необязателен. В реальной инфраструктуре сервис следует защищать токеном, сетевыми политиками и TLS.

## 2. Генерация CycloneDX SBOM с помощью Trivy

Скрипт запускает закреплённый образ Trivy и временно переименовывает выбранный набор зависимостей в стандартный `requirements.txt`, чтобы состояния не смешивались:

```bash
bash ./scripts/generate-trivy-sbom.sh before
bash ./scripts/generate-trivy-sbom.sh after
```

Результаты:

- `sbom/trivy-bom-before.cdx.json`;
- `sbom/trivy-bom-after.cdx.json`.

## 3. Загрузка SBOM в Dependency-Track

Создайте команду и API-ключ с разрешениями `BOM_UPLOAD` и `PROJECT_CREATION_UPLOAD`. Передавайте ключ только через переменную окружения:

```bash
export DTRACK_API_KEY='replace-with-local-api-key'
bash ./scripts/upload-dtrack.sh before
bash ./scripts/upload-dtrack.sh after
```

По умолчанию скрипт обращается к `http://localhost:8080`, создаёт проект `dependency-risk-lab` и использует `before` или `after` как версию. Параметры можно переопределить:

```bash
DTRACK_URL='https://dtrack.example.com' \
DTRACK_PROJECT_NAME='demo-service' \
DTRACK_PROJECT_VERSION='1.0.0' \
bash ./scripts/upload-dtrack.sh after
```

Обработка загруженного SBOM выполняется асинхронно. После импорта проверьте компоненты, findings, источник результата и статус анализа в интерфейсе Dependency-Track.

## 4. Независимая проверка и сравнение

Инструменты устанавливаются в отдельное окружение; тестовые зависимости приложения не устанавливаются:

```bash
python3 -m venv .venv-tools
source .venv-tools/bin/activate
python -m pip install cyclonedx-bom pip-audit

bash ./scripts/generate-sbom.sh before
bash ./scripts/audit.sh before
python scripts/triage_report.py evidence/audit-before.json reports/triage-before.md

bash ./scripts/generate-sbom.sh after
FAIL_ON_FINDINGS=1 bash ./scripts/audit.sh after
python scripts/triage_report.py evidence/audit-after.json reports/triage-after.md
python scripts/compare_results.py \
  evidence/audit-before.json \
  evidence/audit-after.json \
  reports/before-after.md
```

`FAIL_ON_FINDINGS=1` превращает повторную проверку в контроль качества: CI завершится ошибкой, если в обновлённом наборе снова появятся известные уязвимости.

## CI

GitHub Actions выполняет обе генерации SBOM, аудит и сравнение, после чего публикует результаты как артефакт workflow. Автоматическая отправка в локальный Dependency-Track намеренно не включена: GitHub-hosted runner не видит `localhost` пользователя, а API-ключ нельзя хранить в коде.

Для внешнего или self-hosted Dependency-Track можно использовать `scripts/upload-dtrack.sh` с GitHub Secret `DTRACK_API_KEY` и доступным из runner адресом.

## Что демонстрирует проект

- понимание роли SBOM в управлении рисками цепочки поставок ПО;
- различие ролей Trivy и Dependency-Track;
- настройку внешнего анализатора в client/server-режиме;
- безопасную передачу API-ключа через окружение;
- воспроизводимый анализ, triage и повторную проверку;
- понимание того, что CVSS и результат сканера не заменяют оценку применимости.

## Ограничения

- это лаборатория, а не production-конфигурация;
- проверенный результат относится к прямым зафиксированным зависимостям и данным на дату сканирования;
- результаты Trivy могут отличаться для SBOM, созданных другими инструментами;
- отдельные записи Trivy могут иметь источник `UNKNOWN`, для которого Dependency-Track не всегда разрешает алиасы;
- применимость требует знания кода, путей выполнения и реального окружения.

Чтобы полностью удалить локальные данные стенда:

```bash
docker compose down -v
```

## Официальные источники

- Dependency-Track: https://github.com/DependencyTrack/dependency-track
- Dependency-Track + Trivy: https://docs.dependencytrack.org/datasources/trivy/
- Dependency-Track CI/CD API: https://docs.dependencytrack.org/usage/cicd/
- Trivy SBOM: https://trivy.dev/docs/latest/guide/supply-chain/sbom/
- CycloneDX specification: https://cyclonedx.org/specification/overview/
- pip-audit: https://github.com/pypa/pip-audit
