# Фаза 1 — Prerequisites

Эта фаза целиком на тебе. Цель: установить локальные CLI-тулы, завести аккаунт
в Yandex Cloud, получить нужные ID и токены, создать пустой GitHub-репозиторий
для GitOps.

После выполнения этой фазы — переходим к Фазе 2 (я пишу Terraform).

---

## 1. Установка CLI-инструментов (Arch Linux)

### Из официальных репозиториев

```bash
sudo pacman -S terraform kubectl helm sops age github-cli
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
for t in terraform kubectl helm sops age gh yc flux; do
  printf "%-12s " "$t"; which "$t" || echo MISSING
done
```

Все должны быть найдены.

---

## 2. Регистрация в Yandex Cloud

1. Зайти на <https://console.yandex.cloud/> и зарегистрироваться (через Яндекс ID).
2. Активировать **пробный грант** (4000 ₽ на 60 дней — этого хватит на всю работу
   с дипломом, при условии что кластер не работает 24/7).
3. Привязать карту (она нужна даже на гранте — без неё не дают создать K8s).

### Получить идентификаторы

В консоли вверху увидишь свой Cloud (например, `cloud-casego`). Внутри него
по умолчанию один Folder (`default`). Запиши:

```
cloud_id  = b1g...
folder_id = b1g...
```

Найти их можно так:

```bash
yc init                                  # пройти авторизацию (откроется браузер)
yc config list                           # показать cloud-id, folder-id
yc resource-manager cloud list
yc resource-manager folder list
```

После `yc init` появится профиль с OAuth-токеном — он будет использоваться
Terraform-провайдером автоматически.

### Создать сервис-аккаунт (для CI и Terraform)

```bash
# Создать SA
yc iam service-account create --name terraform-casego

# Получить его ID
SA_ID=$(yc iam service-account get --name terraform-casego --format json | jq -r .id)

# Выдать роли на фолдер
FOLDER_ID=$(yc config get folder-id)
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role editor --subject serviceAccount:$SA_ID
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role k8s.clusters.agent --subject serviceAccount:$SA_ID
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role vpc.publicAdmin --subject serviceAccount:$SA_ID
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role load-balancer.admin --subject serviceAccount:$SA_ID

# Создать авторизованный ключ (понадобится в terraform.tfvars)
yc iam key create --service-account-id $SA_ID \
  --output ~/yc-sa-key.json
```

Файл `~/yc-sa-key.json` — это секретный ключ. Запомни путь, в Фазе 2 он
прописывается в `terraform.tfvars`. В Git его коммитить нельзя.

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

- [ ] `terraform`, `kubectl`, `helm`, `sops`, `age`, `yc`, `flux`, `gh` установлены
- [ ] `yc init` пройден, `yc config list` показывает cloud-id и folder-id
- [ ] Создан сервис-аккаунт, есть `~/yc-sa-key.json`
- [ ] Создан и запушен пустой репозиторий `casego-gitops` на GitHub
- [ ] Сгенерирован GitHub PAT (сохрани отдельно, ещё понадобится)
- [ ] Записаны: `cloud_id`, `folder_id`, GitHub username/repo

Когда всё это есть — скажи мне, и переходим к Фазе 2.
