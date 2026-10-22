# Журнал выполненной работы

Я настроил копирование с srv-main на srv-backup и проверил восстановление сайта и Nginx. Сводка — в [README](../README.md).

## 1. Стенд и инструменты

**Задача:** подготовить вторую ВМ и проверить зависимости.

**Что сделал:** сохранил сведения о ВМ, снимках и сетевых адаптерах. На серверах проверил ОС и инструменты; после отсутствия rsync и tar на srv-main повторно проверил установленные версии.

**Результат и проблемы:** на srv-main подтверждены rsync `3.4.4-1.el10` и tar `1.35-13.el10`, на srv-backup — rsync `3.4.4-1.el10`, SELinux `Enforcing` и работающий firewalld. Имена ВМ в VirtualBox отличаются от имён внутри гостевых ОС.

**Подтверждение:** [хост](../evidence/host/), [инструменты до](../evidence/main/02-tools.txt), [после](../evidence/main/02b-tools-after.txt), [сервер копий](../evidence/backup-server/02-identity.txt).

## 2. SSH и пользователь backup

**Задача:** обеспечить передачу копий отдельным ключом.

**Что сделал:** использовал пользователя backup с заблокированным паролем и каталог `/srv/backups/main` с режимом 700. В `authorized_keys` указал `restrict` и `from`, проверил SSH и отказ выделения PTY.

**Результат и проблемы:** соединение по ключу прошло, запрос PTY отклонён с кодом 255. Ключ без passphrase используется для автоматического запуска. `restrict` ограничивает возможности SSH-сеанса, но не задаёт единственную разрешённую команду; GSSAPI в настройках сервера оставлен.

**Подтверждение:** [права ключа](../evidence/main/04-key-perms.txt), [SSH](../evidence/main/05-ssh-to-backup-ok.txt), [PTY](../evidence/main/06-pty-refused.txt), [пользователь](../evidence/backup-server/04-backup-user.txt), [пароль](../evidence/backup-server/05-password-locked.txt), [authorized_keys](../evidence/backup-server/06-authorized-keys.txt), [синтаксис sshd](../evidence/backup-server/07-sshd-syntax.txt).

## 3. Скрипты и systemd

**Задача:** подготовить копирование, восстановление и запуск по расписанию.

**Что сделал:** написал скрипты создания tar.gz с метаданными, передачи через rsync, проверки SHA-256 и восстановления сайта с конфигом Nginx. Проверил синтаксис Bash и unit-файлов, сохранил хеши файлов на хосте и установленных файлов на ВМ.

**Результат и проблемы:** четыре хеша установленных файлов совпадают с файлами репозитория. `/etc/default/backup-site` с реальным адресом я оставил вне репозитория. Восстановление ограничил сайтом и Nginx; остальные выбранные конфиги входят в архив, но не в этот тест восстановления.

**Подтверждение:** [скрипты](../scripts/), [units](../configs/systemd/), [Bash backup](../evidence/main/07a-syntax-backup.txt), [Bash restore](../evidence/main/07b-syntax-restore.txt), [unit verify](../evidence/main/09-unit-verify.txt), [хеши хоста](../evidence/host/01-files-hash.txt), [хеши ВМ](https://github.com/UdzakiZaki/server-diagnostics-python/blob/d06b34b/evidence/main/43-installed-hashes.txt).

## 4. Первая копия и отказ передачи

**Задача:** проверить доставку архива и обработку ошибки SSH.

**Что сделал:** запустил службу, проверил журнал, локальную и удалённую копии и SHA-256. Отдельно запустил скрипт с путём к несуществующему ключу.

**Результат и проблемы:** первая копия прошла удалённую проверку SHA-256. При неверном ключе SSH отказал во входе, rsync и скрипт завершились с кодом 255. Завершившаяся oneshot-служба стала `inactive (dead)`, хотя копирование прошло успешно.

**Подтверждение:** [первый запуск](../evidence/main/11-first-run.txt), [status](../evidence/main/12-first-run-status.txt), [журнал](../evidence/main/13-first-run-journal.txt), [локально](../evidence/main/14-local-copy.txt), [удалённо](../evidence/backup-server/08-backups.txt), [SHA-256](../evidence/backup-server/09-checksum-verify.txt), [отказ](../evidence/main/15-failure-test.txt).

## 5. Таймер

**Задача:** проверить автоматический запуск и вернуть рабочее расписание.

**Что сделал:** проверил календарь и включение таймера, временно использовал `demo.conf` для ускоренной демонстрации, сопоставил срабатывания с журналом и удалёнными копиями. Затем вернул ежедневное расписание и прочитал эффективные параметры.

**Результат и проблемы:** ускоренные запуски создали проверенные копии. В итоговой конфигурации — 03:00, задержка 5 минут, `Persistent=yes`, список drop-in пуст. Отдельного состоявшегося ежедневного запуска в сохранённых результатах нет.

**Подтверждение:** [календарь](../evidence/main/10-calendar.txt), [первое расписание](../evidence/main/16-timer-daily.txt), [enabled](../evidence/main/17-timer-enabled.txt), [демонстрация](../evidence/main/18-timer-demo.txt), [журнал](../evidence/main/19-timer-runs.txt), [drop-in во время теста](../evidence/main/20-timer-status.txt), [возврат расписания](../evidence/main/21-timer-daily-restored.txt), [копии](../evidence/backup-server/11-backups-after-timer.txt), [итоговые параметры](https://github.com/UdzakiZaki/server-diagnostics-python/blob/d06b34b/evidence/main/44-effective-timer.txt), [содержимое units](https://github.com/UdzakiZaki/server-diagnostics-python/blob/d06b34b/evidence/main/45-units-cat.txt).

## 6. Восстановление и замер времени

**Задача:** проверить возврат сайта и конфига из удалённой копии.

**Что сделал:** сохранил дерево, manifest SHA-256 и хеш Nginx, создал копию с тестовыми файлами. Проверил HTTP 404 после удаления, выполнил восстановление и сравнил результат с исходным состоянием.

**Результат и проблемы:** восстановлен архив `main-20261021-181955.tar.gz`. Сравнения дали `TREE_IDENTICAL` и `MANIFEST_IDENTICAL`, хеш Nginx совпал с исходным и архивным, проверка синтаксиса прошла. Внешний замер — `real 0m2.127s`, внутренняя оценка скрипта — `2.1 s`; диагностика после восстановления вернула код 0.

**Подтверждение:** [дерево до](../evidence/main/22-tree-before.txt), [manifest](../evidence/main/23-manifest-before.txt), [хеш до](../evidence/main/24-nginx-conf-hash-before.txt), [копия](../evidence/main/26-backup-journal.txt), [HTTP 404](../evidence/main/27-site-after-delete.txt), [диагностика](../evidence/main/28-diag-after-delete.txt), [восстановление и время](../evidence/main/29-restore.txt), [страница](../evidence/main/30-site-after-restore.txt), [дерево после](../evidence/main/31-tree-after.txt), [сравнение дерева](../evidence/main/31b-tree-compare.txt), [сравнение manifest](../evidence/main/32-manifest-compare.txt), [хеш после](../evidence/main/33-nginx-conf-hash-after.txt), [nginx -t](../evidence/main/34-nginx-test.txt), [диагностика после](../evidence/main/35-diag-after-restore.txt).

## 7. Состав архива, audit и повреждённая копия

**Задача:** проверить содержимое копии, следы изменений и отказ до распаковки повреждённого архива.

**Что сделал:** после неудачной попытки вызвать tar на srv-backup прочитал список удалённого архива с srv-main. Проверил загруженное правило audit. Затем запустил восстановление повреждённого архива и проверил HTTP.

**Результат и проблемы:** список удалённого архива содержит сайт и выбранные конфиги. Журнал аудита уже ротирован, события не сохранились. Аудит восстановления не подтверждён. Повреждённый архив отклонён по SHA-256 с кодом 1, следующий HTTP-запрос получил 200. Этот HTTP-запрос не является сравнением всех файлов после отказа. В ранних записях `rec` не сохраняла кавычки, позже я исправил вывод через `%q`.

**Подтверждение:** [неудачная попытка tar](../evidence/backup-server/10-archive-listing.txt), [успешный список](https://github.com/UdzakiZaki/server-diagnostics-python/blob/d06b34b/evidence/main/46-remote-archive-listing.txt), [правило](https://github.com/UdzakiZaki/server-diagnostics-python/blob/d06b34b/evidence/main/47-audit-rules.txt), [повреждённая копия](../evidence/backup-server/12-corrupt-created.txt), [отказ](../evidence/main/37-restore-corrupt-refused.txt), [HTTP после](../evidence/main/38-site-still-intact.txt).
