# PostgreSQL и Docker: создание образов, настройка и мониторинг

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
##### Проверка что каталог нормально примонтирован и файлы кластера созданы
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
##### Подключение к контейнеру postgres с хоста в облаке и создание БД 
```sh
sudo docker exec -it postgres su - postgres "-c psql -h postgres -U postgres -W"
postgres=# create database otus_1;
CREATE DATABASE
postgres=# \l
                                 List of databases
   Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
 otus_1    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
(4 rows)
```

### 5. Создание docker контейнера с клиентом PostgreSQL.
##### Создание контейнера с клиентом
```sh
sudo docker run -d --network db-net --name pg-client -e POSTGRES_PASSWORD=postgres postgres:14
sudo docker ps
CONTAINER ID   IMAGE         COMMAND                  CREATED              STATUS              PORTS                                       NAMES
f4478f33e670   postgres:14   "docker-entrypoint.s…"   8 seconds ago        Up 6 seconds        5432/tcp                                    pg-client
da1db45bc32b   postgres:14   "docker-entrypoint.s…"   About a minute ago   Up About a minute   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   postgres
```

### 6. Подключение из контейнера с клиентом к контейнеру с сервером и создание таблицу с данными о перевозках.
```sh
sudo docker exec -it pg-client su - postgres "-c psql -h postgres -U postgres -W"
postgres=# create database otus_2;
CREATE DATABASE
postgres=# \l
                                 List of databases
   Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
 otus_1    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 otus_2    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
(5 rows)
\c otus_1
create table shipments(id serial, product_name text, quantity int, destination text);
insert into shipments(product_name, quantity, destination) values('bananas', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('bananas', 1500, 'Asia');
insert into shipments(product_name, quantity, destination) values('bananas', 2000, 'Africa');
insert into shipments(product_name, quantity, destination) values('coffee', 500, 'USA');
insert into shipments(product_name, quantity, destination) values('coffee', 700, 'Canada');
insert into shipments(product_name, quantity, destination) values('coffee', 300, 'Japan');
insert into shipments(product_name, quantity, destination) values('sugar', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('sugar', 800, 'Asia');
insert into shipments(product_name, quantity, destination) values('sugar', 600, 'Africa');
insert into shipments(product_name, quantity, destination) values('sugar', 400, 'USA');
```

### 7. Подключение к контейнеру с сервером с ноутбука или компьютера.
```sh
BiryukovSB@ASUS-2021 MINGW64 /d/otus2025/git/otus_2025 (main)
$ psql -h 51.250.31.197 -p 5432 -U postgres -W otus_1
Пароль:

psql (14.2, сервер 14.19 (Debian 14.19-1.pgdg13+1))
ПРЕДУПРЕЖДЕНИЕ: Кодовая страница консоли (866) отличается от основной
                страницы Windows (1251).
                8-битовые (русские) символы могут отображаться некорректно.
                Подробнее об этом смотрите документацию psql, раздел
                "Notes for Windows users".
Введите "help", чтобы получить справку.

otus_1=# select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | bananas      |     1500 | Asia
  3 | bananas      |     2000 | Africa
  4 | coffee       |      500 | USA
  5 | coffee       |      700 | Canada
  6 | coffee       |      300 | Japan
  7 | sugar        |     1000 | Europe
  8 | sugar        |      800 | Asia
  9 | sugar        |      600 | Africa
 10 | sugar        |      400 | USA
(10 ёЄЁюъ)


otus_1=# \l
                                 ╤яшёюъ срч фрээ√ї
    ╚ь     | ┬ырфхыхЎ | ╩юфшЁютър | LC_COLLATE |  LC_CTYPE  |     ╧Ёртр фюёЄєяр
-----------+----------+-----------+------------+------------+-----------------------
 otus_1    | postgres | UTF8      | en_US.utf8 | en_US.utf8 |
 otus_2    | postgres | UTF8      | en_US.utf8 | en_US.utf8 |
 postgres  | postgres | UTF8      | en_US.utf8 | en_US.utf8 |
 template0 | postgres | UTF8      | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |           |            |            | postgres=CTc/postgres
 template1 | postgres | UTF8      | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |           |            |            | postgres=CTc/postgres
(5 ёЄЁюъ)


otus_1=# \q
```

### 8. Удаление контейнера с сервером и создание его заново.
```sh
yc-user@epddjt90u9510bdb8gfg:~$ sudo docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS                                       NAMES
f4478f33e670   postgres:14   "docker-entrypoint.s…"   5 minutes ago   Up 5 minutes   5432/tcp                                    pg-client
da1db45bc32b   postgres:14   "docker-entrypoint.s…"   7 minutes ago   Up 7 minutes   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   postgres
yc-user@epddjt90u9510bdb8gfg:~$ sudo docker rm -f postgres
postgres
yc-user@epddjt90u9510bdb8gfg:~$ sudo docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS      NAMES
f4478f33e670   postgres:14   "docker-entrypoint.s…"   6 minutes ago   Up 6 minutes   5432/tcp   pg-client
yc-user@epddjt90u9510bdb8gfg:~$ sudo du -hs /var/lib/postgres/
59M     /var/lib/postgres/
yc-user@epddjt90u9510bdb8gfg:~$ sudo docker run -d --network db-net --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:14
306a8756440737fba64313dcb416311a846ad9a27c65a8e227aa04dc0484ab29
```
### 9. Проверка, что данные остались на месте.
```sh
sudo docker exec -it postgres su - postgres "-c psql -h postgres -U postgres -W -d otus_1"

psql (14.19 (Debian 14.19-1.pgdg13+1))
Type "help" for help.

otus_1=# \l
                                 List of databases
   Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
 otus_1    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 otus_2    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
(5 rows)

otus_1=# select * from shipments;
 id | product_name | quantity | destination
----+--------------+----------+-------------
  1 | bananas      |     1000 | Europe
  2 | bananas      |     1500 | Asia
  3 | bananas      |     2000 | Africa
  4 | coffee       |      500 | USA
  5 | coffee       |      700 | Canada
  6 | coffee       |      300 | Japan
  7 | sugar        |     1000 | Europe
  8 | sugar        |      800 | Asia
  9 | sugar        |      600 | Africa
 10 | sugar        |      400 | USA
(10 rows)

```
