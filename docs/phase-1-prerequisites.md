# Фаза 1 — Prerequisites

Эта фаза целиком на тебе. Цель: установить локальные CLI-тулы, завести аккаунт
в Yandex Cloud, создать кластер `casego-cluster`, создать пустой GitHub-репозиторий
для GitOps.

После выполнения этой фазы — переходим к Фазе 2 (подключение kubectl).

---

## 1. Установка CLI-инструментов (Arch Linux)

### Из официальных репозиториев

```bash
sudo pacman -S kubectl helm sops age github-cli jq
```

### Yandex Cloud CLI (`yc`)

Не в pacman. Ставим официальным инсталлером:

```bash
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
exec -l $SHELL   # перезагрузить shell, чтобы $PATH подхватил ~/yandex-cloud/bin
yc version
```

### Flux CLI

Не в pacman. Официальный инсталлер:

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
flux --version
```

Альтернатива из AUR:

```bash
yay -S flux-bin
```

### Проверка

```bash
for t in kubectl helm sops age gh yc flux jq; do
  printf "%-12s " "$t"; which "$t" || echo MISSING
done
```

Все должны быть найдены.

---

## 2. Регистрация в Yandex Cloud и создание кластера

1. Зайти на <https://console.yandex.cloud/> и зарегистрироваться (через Яндекс ID).
2. Активировать **пробный грант** (4000 ₽ на 60 дней).
3. Привязать карту (нужна даже на гранте — без неё не дают создать K8s).

### `yc init`

```bash
yc init
```

- авторизация через браузер
- выбор cloud (`case5` или как назван у тебя)
- выбор folder (`default`)
- зона по умолчанию — `ru-central1-a`

После этого:
```bash
yc config list
```
покажет `cloud-id`, `folder-id`, `compute-default-zone` — это твои основные
параметры. Записывать никуда не надо, всё хранится в `~/.config/yandex-cloud/`.

### Создать кластер `casego-cluster`

Через консоль: **Managed Service for Kubernetes → Кластеры → Создать кластер**.

Параметры:
- **Имя:** `casego-cluster`
- **Сеть и подсеть:** default (или создать новые)
- **Версия K8s:** последняя стабильная
- **Тип мастера:** Зональный (дешевле)
- **Зона мастера:** `ru-central1-a`
- **Группа узлов:** 2 ноды по 2 vCPU / 4 GB / 30 GB SSD
- **Публичный адрес мастера:** включить (чтобы kubectl ходил снаружи)

Создание занимает 5-10 минут. Когда статус кластера станет `RUNNING` — переход к
Фазе 2.

---

## 3. Создать GitHub-репозиторий `casego-gitops`

### Вариант A — через `gh`

```bash
gh auth login                          # один раз авторизоваться
cd /home/maks/casego-gitops
git init
git add .
git commit -m "initial: gitops skeleton"
gh repo create casego-gitops --private --source=. --push
```

### Вариант B — вручную

Создать пустой репозиторий <https://github.com/new>, имя `casego-gitops`,
приватный. Потом:

```bash
cd /home/maks/casego-gitops
git init
git remote add origin git@github.com:<твой-юзер>/casego-gitops.git
git add .
git commit -m "initial: gitops skeleton"
git branch -M main
git push -u origin main
```

### GitHub PAT для Flux

Flux Bootstrap зайдёт в твой GitHub и положит в репо свои манифесты + создаст
Deploy Key. Для этого нужен Personal Access Token:

1. Зайти <https://github.com/settings/tokens?type=beta> (Fine-grained PAT).
2. Token name: `flux-casego-gitops`.
3. Expiration: 90 дней.
4. Repository access: Only select repositories → `casego-gitops`.
5. Permissions → Repository: **Contents: Read & Write**, **Administration: Read & Write**.
6. Сохранить токен (`github_pat_...`) — будет нужен в Фазе 3.

---

## 4. Чек-лист готовности к Фазе 2

- [ ] `kubectl`, `helm`, `sops`, `age`, `yc`, `flux`, `gh`, `jq` установлены
- [ ] `yc init` пройден, `yc config list` показывает cloud-id и folder-id
- [ ] Кластер `casego-cluster` создан в консоли YC, статус `RUNNING`
- [ ] Создан и запушен пустой репозиторий `casego-gitops` на GitHub
- [ ] Сгенерирован GitHub PAT (сохрани отдельно, понадобится в Фазе 3)

Когда всё это есть — пиши сюда, переходим к Фазе 2.
