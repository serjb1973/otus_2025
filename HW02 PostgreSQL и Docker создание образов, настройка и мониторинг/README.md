# PostgreSQL и Docker: создание образов, настройка и мониторинг

### 1. Создание виртуального хоста с Ubuntu 20.04 в Яндекс cloud или аналогах.
### 2. Установка Docker Engine.
### 3. Создание каталог /var/lib/postgres для хранения данных.
### 4. Создание docker контейнера с PostgreSQL 14, смонтированного в него /var/lib/postgres.
### 5. Создание docker контейнера с клиентом PostgreSQL.
### 6. Подключение из контейнера с клиентом к контейнеру с сервером и создание таблицу с данными о перевозках.
### 7. Подключение к контейнеру с сервером с ноутбука или компьютера.
### 8. Удаление контейнера с сервером и создание его заново.
### 9. Проверка, что данные остались на месте.


### 1. Создание виртуального хоста с Ubuntu 20.04 в Яндекс cloud или аналогах.
##### Выбираем образ ОС
```sh
yc compute image list --folder-id standard-images --limit 0 --jq '.[].family' | grep ubuntu |sort |uniq
...
ubuntu-2004-lts
...
```

##### Создаём виртуальный хост, характеристики:
- vCPU=2
- Гарантированная доля vCPU 20%
- RAM 2GB
- Тип прерываемая
```sh
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2004-lts,auto-delete,type=network-hdd,size=20GB \
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
### 2. Установка Docker Engine.
##### поставим докер  https://docs.docker.com/engine/install/ubuntu/
```sh
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh --version 20.10 && rm get-docker.sh
проверка службы
sudo systemctl status docker
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2025-10-05 10:09:48 UTC; 41s ago

```
### 3. Создание каталог /var/lib/postgres для хранения данных.
```sh
sudo mkdir /var/lib/postgres
```
### 4. Создание docker контейнера с PostgreSQL 14, смонтированного в него /var/lib/postgres.
##### Создаем docker-сеть: 
```sh
sudo docker network create db-net
```
##### Качаем заранее образ postgres
```sh
sudo docker pull postgres:14
sudo docker image inspect postgres:14
```
##### Создание контейнера с БД
```sh
sudo docker run -d --network db-net --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:14
```
##### Проверка чт о каталог нормально примонтирован и файлы
```sh
sudo grep -Ev '^$|^#' /var/lib/postgres/pg_hba.conf
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
host all all all scram-sha-256
```

### 5. Создание docker контейнера с клиентом PostgreSQL.
### 6. Подключение из контейнера с клиентом к контейнеру с сервером и создание таблицу с данными о перевозках.
### 7. Подключение к контейнеру с сервером с ноутбука или компьютера.
### 8. Удаление контейнера с сервером и создание его заново.
### 9. Проверка, что данные остались на месте.











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
### 2. Создание БД для урока 1 и устанавка расширения https://postgrespro.ru/docs/postgresql/17/pageinspect
```sh
sudo -u postgres psql -c "create database otus01"
sudo -u postgres psql -d otus01 -c "create extension pageinspect"
```

# Подключение к PostgreSQL
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
```

# Работа с транзакциями
##### session1 Создаём таблицу с двумя строками
```
create table shipments(id serial, product_name text, quantity int, destination text);
insert into shipments(product_name, quantity, destination) values('bananas', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('coffee', 500, 'USA');
commit;
CREATE TABLE
INSERT 0 1
INSERT 0 1
COMMIT
```
##### Делаем вставку доп строки в таблицу:
```
session1#insert into shipments(product_name, quantity, destination) values('sugar', 300, 'Asia');
INSERT 0 1
```
##### Проверяем t_xmin, t_xmax новой строки - у неё транзакция 851 и эта транзакция активна:
```
session1#SELECT t_ctid,t_xmin,t_xmax FROM heap_page_items(get_raw_page('shipments', 0));
 t_ctid | t_xmin | t_xmax
--------+--------+--------
 (0,1)  |    850 |      0
 (0,2)  |    850 |      0
 (0,3)  |    851 |      0
(3 rows)

session1#select pg_current_xact_id();
 pg_current_xact_id
--------------------
                851
(1 row)
session1#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
--
```
##### session2 Проверим текущий уровень изоляции с помощью команды:
```
session2#begin;
BEGIN
session2#show transaction isolation level;
 transaction_isolation
-----------------------
 read committed
(1 row)
```
##### Проверяем видимость в данной сессии, транзакция 851 является активной и изменения сделанные в ней не должны быть видны в этой сессии
```
session2#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
(2 rows)
```
##### session1 Завершаем транзакцию 
```
session1#commit;
COMMIT
```
##### session2 Теперь в этой сессии строка с xmin=851 тоже видна
```
session2#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
session2#commit;
COMMIT
```


### Эксперименты с уровнем изоляции Repeatable Read
##### session2 Меняем уровень изоляции транзакций
```
session2#begin;
BEGIN
session2#set transaction isolation level repeatable read;
SET
session2#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
```
##### session1 Вставляем строку и коммитим транзакцию
```
session1#insert into shipments(product_name, quantity, destination) values('bananas', 2000, 'Africa');
INSERT 0 1
session1#commit;
COMMIT
session1#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
  4 | bananas      |     2000 | Africa
(4 rows)
```
##### session2# Запрос в сессии 2 в рамках начатой транзакции показывает только строки актуальные на момент старта этой транзакции.
```
session2#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
(3 rows)
```
##### После заверщения транзакции в режиме transaction isolation level repeatable read данные в таблице видны
```
session2#commit;
COMMIT
session2#select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | coffee       |      500 | USA
  3 | sugar        |      300 | Asia
  4 | bananas      |     2000 | Africa
(4 rows)
```
# Работа с транзакциями вывод:
##### Выше показана что аномалия "неповторяемое чтение" возникает с уровнем изоляции транзакции Read committed и не позникает с уровнем изоляции Repeatable read.
