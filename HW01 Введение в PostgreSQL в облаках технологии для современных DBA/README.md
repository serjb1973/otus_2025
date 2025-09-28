# Создание Виртуальной машины в облаке

### 1. Настройка акканута в Yandex Cloud.
### 2. Создание сети.
### 3. Установка на клиентском компьютере интерфейса командной строки Yandex Cloud (CLI).
### 4. Инициализация и настройка Yandex CLI.
### 5. Создание пары SSH ключей доступа на клиенте.

Аккаунт в Yandex Cloud у меня создан несколько лет назад, поэтому пункты 1-5 пропускаю, ключ также был создан несколько лет назад:
```sh
$ ssh-keygen.exe -lf ~/.ssh/id_rsa.pub
3072 SHA256:wG/dYH...ZgA BiryukovSB@MCD000209 (RSA)
```

### 6. Создание виртуальной машины в интерфейсе Yandex CLI
##### Выбираем образ ОС
```sh
yc compute image list --folder-id standard-images --limit 0 --jq '.[].family' | sort | uniq
...sh
ubuntu-2404-lts-oslogin
...
```
##### Выбираем свободный IP адрес
```sh
yc vpc subnet list
yc vpc address list
yc vpc address get e2lpia39hmo6aeq1hm83
```
##### Выбираем тип диска 
```sh
yc compute disk-type list
network-hdd
```
##### Создаём виртуальный хост, характеристики:
- vCPU=2
- Гарантированная доля vCPU 20%
- RAM 2GB
- Тип прерываемая
```sh
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts-oslogin,auto-delete,type=network-hdd,size=20GB \
  --name bananaflow-19730802 \
  --public-address 51.250.31.197 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --memory 2GB --cores 2 --core-fraction 20 --preemptible
```
##### Просмотр списка виртаульных машин
```sh
yc compute instance list
Управление виртуальной машиной
yc compute instance stop --name bananaflow-19730802
yc compute instance start --name bananaflow-19730802
yc compute instance delete --name bananaflow-19730802
```
##### Подключение с локального хоста к хосту в облаке по ssh
```sh
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
sudo apt update ; sudo apt upgrade -y
```

# Установка Postgresql
### 1. Установка Программного обеспечения Postgresql
[Сайт источник ванильного postgresql](https://www.postgresql.org/download/linux/ubuntu/)
```sh
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
sudo apt install -y postgresql-common ; sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh ; sudo apt-get update ; sudo apt -y install postgresql
```
##### Проверка
```sh
yc-user@epdpo26kjq970dur09m6:~$ apt list --installed postgres*
Listing... Done
postgresql-18-jit/noble-pgdg,now 18.0-1.pgdg24.04+3 amd64 [installed,automatic]
postgresql-18/noble-pgdg,now 18.0-1.pgdg24.04+3 amd64 [installed,automatic]
postgresql-client-18/noble-pgdg,now 18.0-1.pgdg24.04+3 amd64 [installed,automatic]
postgresql-client-common/noble-pgdg,now 283.pgdg24.04+1 all [installed,automatic]
postgresql-common/noble-pgdg,now 283.pgdg24.04+1 all [installed]
postgresql/noble-pgdg,now 18+283.pgdg24.04+1 all [installed]
```
##### Проверка кластера Postgresql
```sh
yc-user@epdpo26kjq970dur09m6:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
18  main    5432 online postgres /var/lib/postgresql/18/main /var/log/postgresql/postgresql-18-main.log
```
##### Проверка сервиса Postgresql
```sh
yc-user@epdpo26kjq970dur09m6:~$ service --status-all |grep postgres
 [ + ]  postgresql
yc-user@epdpo26kjq970dur09m6:~$ sudo systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; preset: enabled)
     Active: active (exited) since Sat 2025-09-27 15:46:09 UTC; 6min ago
   Main PID: 8191 (code=exited, status=0/SUCCESS)
        CPU: 2ms

Sep 27 15:46:09 epdpo26kjq970dur09m6 systemd[1]: Starting postgresql.service - PostgreSQL RDBMS...
Sep 27 15:46:09 epdpo26kjq970dur09m6 systemd[1]: Finished postgresql.service - PostgreSQL RDBMS.
```
### 2. Создание БД для урока 1
```sh
sudo -u postgres psql -c "create database otus01"
```
##### Подключение к БД PostgreSQL
Сессия 1
```sh
sudo -u postgres psql -d otus01
\set PROMPT1 session1#
session1#\echo :AUTOCOMMIT
on
session1#\set AUTOCOMMIT off
session1#\echo :AUTOCOMMIT
off
```
Сессия 2
```sh
sudo -u postgres psql -d otus01
\set PROMPT1 session2#
otus01=# \set PROMPT1 session2#
session2#\echo :AUTOCOMMIT
on
session2#\set AUTOCOMMIT off
session2#\echo :AUTOCOMMIT
off
```
