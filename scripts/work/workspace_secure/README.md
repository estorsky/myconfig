# workspace_secure

`workspace_secure` нужен для обновления окружения на виртуальной машине в
закрытом контуре, когда правки удобнее делать на хосте, а на VM только
разворачивать готовый bundle.

## Что делает схема

На хосте:
- собирает переносимый bundle из `scripts/work/workspace_secure/`;
- кладет в него полный `myconfig` вместе с `.git`-историей, переносимые бинарники и дополнительные
  файлы overlay, если они есть;
- берет текущее рабочее состояние репозитория, включая незакоммиченные tracked
  изменения на хосте;
- для `nodejs` по умолчанию подбирает версию по текущему хосту;
- для `nvim` по умолчанию использует совместимую с Ubuntu 20.04 стратегию;
- создает архив `scripts/work/workspace_secure.tar.gz`.

На VM:
- сохраняет backup текущего `~/myconfig`;
- сохраняет локальный `git diff` старого `~/myconfig`;
- полностью заменяет `~/myconfig` свежей копией из bundle;
- после разворачивания `~/myconfig` на VM остается полноценным git-репозиторием;
- пытается повторно накатить локальный diff со старой VM;
- раскладывает дополнительные пакеты (`nodejs`, `nvim`, `vim_config`, `zsh`);
- генерирует `workspace_env.sh`.

Если какой-то diff не применился, новый `~/myconfig` все равно остается
установленным, а подробности сохраняются в backup.

Незакоммиченные изменения на хосте сами по себе не мешают этой схеме: они просто
попадают в bundle как часть текущего рабочего дерева. Ошибка возникает только
если локальный diff старой VM уже не накладывается на новую базу по контексту.

## Какой сценарий считается основным

Основной сценарий такой:

- правка делается в этом проекте на хосте;
- затем на хосте собирается bundle;
- на VM bundle только распаковывается и применяется.

Это удобно, потому что переносить большие куски текста или diff обратно из VM
через общий буфер обмена неудобно. Поэтому VM здесь считается местом
разворачивания, а не основной точкой редактирования.

## Как использовать

### 1. Подготовка на хосте

Из репозитория `~/myconfig`:

```bash
cd ~/myconfig/scripts/work/workspace_secure
./prepare_workspace.sh
```

После этого рядом появится архив:

```text
~/myconfig/scripts/work/workspace_secure.tar.gz
```

Его нужно перенести на VM в `~/Downloads/`.

### 2. Разворачивание на VM

На VM:

```bash
cd ~/Downloads
tar -xzf workspace_secure.tar.gz
cd workspace_secure
./init_workspace.sh
```

### 3. Где смотреть backup

Если нужно разобраться, что было на VM до обновления:

- старое дерево `myconfig`:
  `~/workspace_backup/myconfig_base/<timestamp>/previous_myconfig`
- сохраненный локальный diff VM:
  `~/workspace_backup/myconfig_base/<timestamp>/local_changes.patch`
- лог попытки повторного применения diff:
  `~/workspace_backup/myconfig_base/<timestamp>/reapply.log`
- сохраненный `git status` старой VM:
  `~/workspace_backup/myconfig_base/<timestamp>/git_status.txt`
- список untracked-файлов старой VM:
  `~/workspace_backup/myconfig_base/<timestamp>/untracked_files.txt`
- дополнительные backup'ы overlay-файлов:
  `~/workspace_backup/vm_overlay/<timestamp>/`

Если нужно посмотреть, с каким состоянием хоста был собран bundle, это лежит в:

- `scripts/work/workspace_secure/myconfig_base/output/host_git_status.txt`
- `scripts/work/workspace_secure/myconfig_base/output/host_changes.patch`
- `scripts/work/workspace_secure/myconfig_base/output/host_untracked_files.txt`

## Что править чаще всего

- общий `myconfig` на хосте, если изменение должно стать новой базой;
- `scripts/work/workspace_secure_overlay/files/`, если нужно просто подложить
  отдельные файлы поверх базы.

## Как выбираются версии `nodejs` и `nvim`

- `nodejs`: по умолчанию скачивается версия, совпадающая с текущим хостом.
- `nvim`: по умолчанию используется совместимый fallback для Ubuntu 20.04,
  потому что свежие upstream-бинарники могут требовать более новую `glibc`.
  Сейчас fallback зафиксирован на `0.10.4`: в релиз-нотах Neovim для Linux
  x86_64 у него явно указан минимум `glibc 2.31`.

Для `nvim` можно управлять поведением через переменные окружения перед запуском
`prepare_workspace.sh`:

```bash
# по умолчанию
export WORKSPACE_SECURE_NVIM_STRATEGY=compat

# если хочешь попробовать exact host version
export WORKSPACE_SECURE_NVIM_STRATEGY=host

# если хочешь явно задать архив
export WORKSPACE_SECURE_NVIM_ARCHIVE=/path/to/nvim.tar.gz

# если хочешь явно задать URL
export WORKSPACE_SECURE_NVIM_URL=https://example.com/nvim.tar.gz
```
