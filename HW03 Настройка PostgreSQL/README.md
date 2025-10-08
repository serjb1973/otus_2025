# Настройка PostgreSQL

Цель:
- научиться подключать и настраивать дополнительный диск для хранения данных;
- освоить перенос базы данных postgresql на новое хранилище;
- обеспечить отказоустойчивость данных при помощи внешнего диска;


### 1. Создание виртуальной машины с Ubuntu 22.04 и установка PostgreSQL 16.
##### Выбираем образ ОС
```sh
yc compute image list --folder-id standard-images --limit 0 --jq '.[].family' | grep ubuntu |sort |uniq
...
ubuntu-2204-lts
...
```
##### Создаём виртуальный хост, характеристики:
- vCPU=2
- Гарантированная доля vCPU 20%
- RAM 2GB
- Тип прерываемая
```sh
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,auto-delete,type=network-hdd,size=20GB \
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
sudo apt update && sudo apt upgrade -y && sudo apt install -y vim
```

# Установка Postgresql
### 1. Установка Программного обеспечения Postgresql
[Сайт источник ванильного postgresql](https://www.postgresql.org/download/linux/ubuntu/)
```sh
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
sudo apt install -y postgresql-common && sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && sudo apt-get update && sudo apt -y install postgresql-16
```
##### Проверка кластера Postgresql
```sh
yc-user@epd994h503crm15q5jpg:~$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
16  main    5432 online postgres /var/lib/postgresql/16/main /var/log/postgresql/postgresql-16-main.log
```
##### Проверка сервиса Postgresql
```sh
yc-user@epd994h503crm15q5jpg:~$ sudo systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/lib/systemd/system/postgresql.service; enabled; vendor preset: enabled)
     Active: active (exited) since Wed 2025-10-08 10:45:25 UTC; 5min ago
   Main PID: 3031 (code=exited, status=0/SUCCESS)
        CPU: 1ms

Oct 08 10:45:25 epd994h503crm15q5jpg systemd[1]: Starting PostgreSQL RDBMS...
Oct 08 10:45:25 epd994h503crm15q5jpg systemd[1]: Finished PostgreSQL RDBMS.
```
##### Создание БД для урока
```sh
sudo -u postgres psql -c "create database otus"
CREATE DATABASE
```
### Создание таблицы с данными о перевозках
```sh
sudo -u postgres psql -d otus
otus=# create table shipments(id serial, product_name text, quantity int, destination text);
CREATE TABLE
otus=# insert into shipments(product_name, quantity, destination) values('bananas', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('bananas', 1500, 'Asia');
insert into shipments(product_name, quantity, destination) values('bananas', 2000, 'Africa');
insert into shipments(product_name, quantity, destination) values('coffee', 500, 'USA');
insert into shipments(product_name, quantity, destination) values('coffee', 700, 'Canada');
insert into shipments(product_name, quantity, destination) values('coffee', 300, 'Japan');
insert into shipments(product_name, quantity, destination) values('sugar', 1000, 'Europe');
insert into shipments(product_name, quantity, destination) values('sugar', 800, 'Asia');
insert into shipments(product_name, quantity, destination) values('sugar', 600, 'Africa');
insert into shipments(product_name, quantity, destination) values('sugar', 400, 'USA');
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
```
### 2. Добавление внешнего диска к виртуальной машине.
##### Добавляем дополнительно внешний диск в виртуальный хост.
##### Создание диска https://yandex.cloud/ru/docs/compute/operations/disk-create/empty
```sh
yc compute disk create --name second-disk --size 50 --description "second disk for database"
```
##### Проверка:
```sh
yc compute disk list
```
##### Подключение диска в виртуалке https://yandex.cloud/ru/docs/compute/operations/vm-control/vm-attach-disk
```sh
yc compute instance attach-disk bananaflow-19730802 --disk-name second-disk --mode rw
```
##### Проверка:
```sh
yc compute instance get --full bananaflow-19730802
```
##### Настройка диска в операционке виртуального хоста
```sh
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
```
##### Ищем файл устройства /dev/vdb
```sh
ls -la /dev/disk/by-id
```
##### Создаём раздел /dev/vdb1 на диске
```sh
sudo fdisk /dev/vdb
```
##### Создаём файловую систему на новом разделе /dev/vdb1
```sh
sudo mkfs.ext4 /dev/vdb1
...
Filesystem UUID: 2723f12d-a746-49d1-a389-fe3e7435d22a
...
sudo mkdir /var/lib/postgresql/tmp
sudo mount /dev/vdb1 /var/lib/postgresql/tmp
sudo chown postgres:postgres /var/lib/postgresql/tmp
```
##### Добавляем строку в fstab
```sh
sudo vim /etc/fstab
UUID=2723f12d-a746-49d1-a389-fe3e7435d22a /var/lib/postgresql/16 ext4 defaults 0 2
```

### 3. Перенос БД на новый диск через создание физической реплики и переключения на неё.
##### Делаем slave database
```sh
sudo su - postgres
mkdir /var/lib/postgresql/tmp/main
cd /var/lib/postgresql/tmp/main
pg_basebackup -P -v -D /var/lib/postgresql/tmp/main -Fp -R
ls -l /var/lib/postgresql/tmp/main
echo "port=5433" >> /var/lib/postgresql/tmp/main/postgresql.conf
cp /etc/postgresql/16/main/pg_hba.conf /var/lib/postgresql/tmp/main/
/usr/lib/postgresql/16/bin/pg_ctl start -D /var/lib/postgresql/tmp/main
```
##### Проверяем работу репликации
##### master
```sh
psql -p 5432 -d otus
select * from pg_stat_replication;
insert into shipments(product_name, quantity, destination) values('lemon', 333, 'Russia');
```
##### slave
```sh
psql -p 5433 -d otus
select * from pg_stat_wal_receiver;
select * from shipments where product_name='lemon';
```
##### Делаем переключение на новую БД 
```sh
/usr/lib/postgresql/16/bin/pg_ctl stop -D /var/lib/postgresql/16/main
/usr/lib/postgresql/16/bin/pg_ctl promote -D /var/lib/postgresql/tmp/main
psql -p 5433 -d otus
alter system reset primary_conninfo ;
/usr/lib/postgresql/16/bin/pg_ctl stop -D /var/lib/postgresql/tmp/main
```
##### Готовим каталоги файловой системы к смене местами:
```sh
mv /var/lib/postgresql/16 /var/lib/postgresql/16_old
mkdir /var/lib/postgresql/16
rm /var/lib/postgresql/tmp/main/postgresql.conf
rm /var/lib/postgresql/tmp/main/pg_hba.conf
du -ms /var/lib/postgresql/
```
##### Перегружаем виртуалку

### 4. Проверка что данные сохранились и находятся на новом диске.
##### проверка что раздел замонтирован
```sh
yc-user@epd994h503crm15q5jpg:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           197M  764K  196M   1% /run
/dev/vda1        19G  2.0G   17G  11% /
tmpfs           982M  1.1M  981M   1% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/vdb1        49G   79M   47G   1% /var/lib/postgresql/16
/dev/vda15      599M  6.1M  593M   2% /boot/efi
tmpfs           197M     0  197M   0% /run/user/1000
```
##### Проверка в БД
```sh
sudo -u postgres psql -d otus
otus=# select * from shipments;
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
 11 | lemon        |      333 | Russia
(11 rows)
otus=# select * from pg_file_settings ;
               sourcefile                | sourceline | seqno |            name            |                setting                 | applied | error
-----------------------------------------+------------+-------+----------------------------+----------------------------------------+---------+-------
 /etc/postgresql/16/main/postgresql.conf |         42 |     1 | data_directory             | /var/lib/postgresql/16/main            | t       |
 /etc/postgresql/16/main/postgresql.conf |         44 |     2 | hba_file                   | /etc/postgresql/16/main/pg_hba.conf    | t       |
 /etc/postgresql/16/main/postgresql.conf |         46 |     3 | ident_file                 | /etc/postgresql/16/main/pg_ident.conf  | t       |
 /etc/postgresql/16/main/postgresql.conf |         50 |     4 | external_pid_file          | /var/run/postgresql/16-main.pid        | t       |
 /etc/postgresql/16/main/postgresql.conf |         64 |     5 | port                       | 5432                                   | t       |
 /etc/postgresql/16/main/postgresql.conf |         65 |     6 | max_connections            | 100                                    | t       |
 /etc/postgresql/16/main/postgresql.conf |         68 |     7 | unix_socket_directories    | /var/run/postgresql                    | t       |
 /etc/postgresql/16/main/postgresql.conf |        108 |     8 | ssl                        | on                                     | t       |
 /etc/postgresql/16/main/postgresql.conf |        110 |     9 | ssl_cert_file              | /etc/ssl/certs/ssl-cert-snakeoil.pem   | t       |
 /etc/postgresql/16/main/postgresql.conf |        113 |    10 | ssl_key_file               | /etc/ssl/private/ssl-cert-snakeoil.key | t       |
 /etc/postgresql/16/main/postgresql.conf |        130 |    11 | shared_buffers             | 128MB                                  | t       |
 /etc/postgresql/16/main/postgresql.conf |        153 |    12 | dynamic_shared_memory_type | posix                                  | t       |
 /etc/postgresql/16/main/postgresql.conf |        247 |    13 | max_wal_size               | 1GB                                    | t       |
 /etc/postgresql/16/main/postgresql.conf |        248 |    14 | min_wal_size               | 80MB                                   | t       |
 /etc/postgresql/16/main/postgresql.conf |        565 |    15 | log_line_prefix            | %m [%p] %q%u@%d                        | t       |
 /etc/postgresql/16/main/postgresql.conf |        603 |    16 | log_timezone               | Etc/UTC                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        607 |    17 | cluster_name               | 16/main                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        715 |    18 | datestyle                  | iso, mdy                               | t       |
 /etc/postgresql/16/main/postgresql.conf |        717 |    19 | timezone                   | Etc/UTC                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        731 |    20 | lc_messages                | C.UTF-8                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        733 |    21 | lc_monetary                | C.UTF-8                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        734 |    22 | lc_numeric                 | C.UTF-8                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        735 |    23 | lc_time                    | C.UTF-8                                | t       |
 /etc/postgresql/16/main/postgresql.conf |        741 |    24 | default_text_search_config | pg_catalog.english                     | t       |
(24 rows)
```

otus=#
