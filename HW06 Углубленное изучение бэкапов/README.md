# Бэкапы на примере WAL_G

Цель:
- проверить резервное копирование и восстановление базы данных утилитой WAL-G

Скрипты:
- hosts_create.sh - создание группы виртуалок в облаке yandex
- hosts.sh - управление группой виртуалок созданной для задания

### 1. Cоздание стенда из 3 хостов
##### 1.1 Создание хостов одним скриптом
```sh
./hosts_create.sh 3
+----------------------+--------------------------+---------------+---------+----------------+-------------+
|          ID          |           NAME           |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+--------------------------+---------------+---------+----------------+-------------+
| epd3heces5lq3jm6848s | bananaflow-19730802-pg03 | ru-central1-b | RUNNING | 89.169.183.192 | 10.129.0.13 |
| epdmget6nph8f51trp8h | bananaflow-19730802-pg01 | ru-central1-b | RUNNING | 89.169.181.249 | 10.129.0.11 |
| epdtlrgqn9g1p324u6i6 | bananaflow-19730802-pg02 | ru-central1-b | RUNNING | 89.169.161.91  | 10.129.0.12 |
+----------------------+--------------------------+---------------+---------+----------------+-------------+

```
Просмотр списка виртаульных машин
```sh
yc compute instance list
```
Управление виртуальными машинами
```sh
./hosts.sh stop
./hosts.sh start
./hosts.sh delete
```
Управление отдельной машиной
```sh
yc compute instance stop --name bananaflow-19730802-pg01
yc compute instance start --name bananaflow-19730802-pg01
yc compute instance delete --name bananaflow-19730802-pg01
```
##### 1.2 Подключение на хост main и установка необходимых пакетов на хосты
```sh
sudo apt update && sudo apt upgrade -y && sudo apt install -y vim && sudo apt install -y postgresql-common && sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && sudo apt-get update && sudo apt -y install postgresql-16 && sudo apt -y install tree && sudo apt install -y jq
```

### 2. Настройка SSH
##### 2.1 Генерация ключей хосты pg01 pg03 и копирование открытого ключа
```sh
sudo -u postgres ssh-keygen
sudo cat /var/lib/postgresql/.ssh/id_rsa.pub
```
##### 2.2 Хост pg02 добавление в доверенные хостов pg01 pg03
```sh
sudo -u postgres vim /var/lib/postgresql/.ssh/authorized_keys 
```
вставка строк из пункта 2.1(пример):
```sh
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+h+sCDGnJXmkskkTHBZ1sbGCn8+QOaE+uvqDa4a/OwnCfQ7ktdTvaLhQPPp6yvEkIpgouRt9oH7ygxCUcM9NXdJxs64MPv/wH0mNL9+eYv2ukC6acvQZfMb78Q8X24qO3kPS/zs20srGaKseiTtf6SZjMAwAl35a/CirNT2m5bKG0EUsGZIH5MDCGnLpTJn1pFKqkdDdQNMUd1WFCa14tjsYKpRxBXTv4LxuSa/ItfF8wWhD7nSsPNFnJwRzgSKIZlDCVSvtLmx6ZRe+3ovi/RZyWryGR/e0ALj5IdYxXFBluHrv0CWHpcIo0MuXn1ufDKRirO5Hkb78DPAcqUaqENBkJ+0HqahJ4m+z5zkQWlUNxB+hsc0vpZBIKcB3FNb/8Hw7weZ+VK8C9Xl5DK/Fj4e0zQ7buWSdA+43Pfm2LhVGxpTQVaYx1k/Dvwes7LbFhjqPEuKwPsMGfH1AJskEKfhdX19+enPv9NO5jbkSwGCiKxwxAokGCNQeqpi9QCLM= postgres@pg01
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWVO8MfnlXHRj3P2rarRX0H7Spbyv5etJwMA3PXtsr7UlJWz7OpbqlbatflCIDnNm1xa5PNKoCGNvTW2EBE4bN1N5fxD6AdgImyuH7lINJ9drj3IcI22YFAExrQGOuJzkKahIfmDaQo8lRPlsTCNLak1GhL28T6JsfwXI0OswIyIIgvZChfk/dxrVS1vz+pg/sCLt7KBwpOELjzIHWxlMK0sTd2TCMe0oMpsOipmO+Kdv+da7beyZUSAL77sSZa074XZZapJ4nANkbq51Nz3lOkl8kjYi4BPy1gPLRuW9MqlX0Y4LBoyJ4EiR6+/eK3Z3ie+o1vzKvSeaFtoZBzhOyt3HzqNfsyuYoP2EjcbgYUbNsGfD6yjh5u40rSwnzUswGGAO2Min6O76UIOewUQksqKi62ygIdsnoI/jhcJK4JAJNBo/FMqifKDsp76zdAzEO3psJRX7IsZpJrVJksD3PZU7JrsZXBPBhiE/MxT2J5RzhPaKV/TEKAh4K3TdqNVc= postgres@pg03
```
##### 2.3 Тест ssh с хостов pg01 pg03
```sh
sudo -u postgres ssh pg02 date 
```

### 3. Установка WAL-G
##### 3.1 Установка бинаря хосты pg01 pg03
```sh
wget https://github.com/wal-g/wal-g/releases/download/v3.0.5/wal-g-pg-ubuntu-22.04-amd64.tar.gz
tar -xvf wal-g-pg-ubuntu-22.04-amd64.tar.gz
sudo mv wal-g-pg-ubuntu-22.04-amd64 /usr/local/bin/wal-g
```
##### 3.2 Настройка конфигов под пользователем postgres на хостах pg01 pg03
```sh
sudo su - postgres 
echo "export PGDATA=/var/lib/postgresql/16/main">>.bash_profile
vim /var/lib/postgresql/.walg.json
{
"PGDATA": "/var/lib/postgresql/16/main",
"PGHOST": "localhost",
"PGPORT": "5432",
"PGUSER": "backuper",
"PGDATABASE": "postgres",
"WALG_SSH_PREFIX": "ssh://pg02/var/lib/postgresql/backup/pg01/",
"SSH_USERNAME": "postgres",
"SSH_PRIVATE_KEY_PATH": "/var/lib/postgresql/.ssh/id_rsa",
"WALG_DELTA_MAX_STEPS": "7"
}
```
##### 3.3 Настройка каталога архива хост pg02
```sh
sudo systemctl stop postgresql
sudo systemctl disable postgresql
sudo rm -rf /var/lib/postgresql/16/main
sudo -u postgres mkdir -p /var/lib/postgresql/backup/pg01
```
##### 3.4 Настройка postgres на хосте pg01
создание пользователя и БД
```sh
sudo -u postgres psql
create user backuper password 'db' superuser createdb createrole replication;
create database otus;
```
заполнение БД данными
```sh
pgbench -i -s 100 otus
postgres=# select pg_size_pretty(pg_database_size('otus'));
 pg_size_pretty
----------------
 1503 MB
(1 row)
```
создание файла паролей
```sh
vim ~/.pgpass
localhost:5432:postgres:backuper:db
chmod 600 ~/.pgpass
```
настройка БД в том числе бэкап рестор wal
```sh
sudo -u postgres psql
alter system set archive_mode = on;
alter system set archive_timeout = 60;
alter system set archive_command = '/usr/local/bin/wal-g wal-push "%p" 2>&1 | tee -a /var/lib/postgresql/walg.log';
alter system set restore_command = '/usr/local/bin/wal-g wal-fetch "%f" "%p" 2>&1 | tee -a /var/lib/postgresql/walg.log';
sudo systemctl restart postgresql
```

### 4. Создание резервных копий WAL-G хост pg01
##### 4.1 Создаём таблицу, запись и делаем полный бэкап БД
```sh
sudo su - postgres
psql otus -c 'create table mytest(id serial,dt timestamp default now())'
psql otus -c 'insert into mytest values (default,default)';
psql otus -c 'select * from mytest';
 id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833

wal-g backup-push -f $PGDATA
wal-g backup-list --pretty

+---+-------------------------------+----------------------------------+--------------------------+--------------+
| # | BACKUP NAME                   | MODIFIED                         | WAL FILE NAME            | STORAGE NAME |
+---+-------------------------------+----------------------------------+--------------------------+--------------+
| 0 | base_000000010000000000000089 | Saturday, 25-Oct-25 16:17:50 UTC | 000000010000000000000089 | default      |
+---+-------------------------------+----------------------------------+--------------------------+--------------+
```
##### 4.2 Добавляем запись и делаем инкрементальный бэкап БД
```sh
psql otus -c 'insert into mytest values (default,default)';
psql otus -c 'select * from mytest';
id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833
  2 | 2025-10-25 16:18:11.638427

wal-g backup-push --delta-from-name base_000000010000000000000089 $PGDATA
wal-g backup-list --pretty
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| # | BACKUP NAME                                              | MODIFIED                         | WAL FILE NAME            | STORAGE NAME |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| 0 | base_000000010000000000000089                            | Saturday, 25-Oct-25 16:17:50 UTC | 000000010000000000000089 | default      |
| 1 | base_00000001000000000000008B_D_000000010000000000000089 | Saturday, 25-Oct-25 16:18:50 UTC | 00000001000000000000008B | default      |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
```
##### 4.3 Добавляем запись и делаем второй инкрементальный бэкап БД
```sh
psql otus -c 'insert into mytest values (default,default)';
psql otus -c 'select * from mytest';
id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833
  2 | 2025-10-25 16:18:11.638427
  3 | 2025-10-25 16:19:12.849934
wal-g backup-push --delta-from-name base_00000001000000000000008B_D_000000010000000000000089 $PGDATA
wal-g backup-list --pretty
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| # | BACKUP NAME                                              | MODIFIED                         | WAL FILE NAME            | STORAGE NAME |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| 0 | base_000000010000000000000089                            | Saturday, 25-Oct-25 16:17:50 UTC | 000000010000000000000089 | default      |
| 1 | base_00000001000000000000008B_D_000000010000000000000089 | Saturday, 25-Oct-25 16:18:50 UTC | 00000001000000000000008B | default      |
| 2 | base_00000001000000000000008D_D_00000001000000000000008B | Saturday, 25-Oct-25 16:19:48 UTC | 00000001000000000000008D | default      |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
```

### 5. Восстановление из архива с первой полной копии и накат wal журналов на хосте pg03
##### 5.1 Восстановление первой записи таблицы
восстанавливаем БД по шагам на разное время и проверяем наличие нужных нам данных в таблице
удаляем параметр archive_command чтобы новая БД не посылала свои wal в архив
```sh
sudo systemctl stop postgresql
sudo su - postgres
pg_ctlcluster 16 main stop
wal-g backup-list --pretty
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| # | BACKUP NAME                                              | MODIFIED                         | WAL FILE NAME            | STORAGE NAME |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| 0 | base_000000010000000000000089                            | Saturday, 25-Oct-25 16:17:50 UTC | 000000010000000000000089 | default      |
| 1 | base_00000001000000000000008B_D_000000010000000000000089 | Saturday, 25-Oct-25 16:18:50 UTC | 00000001000000000000008B | default      |
| 2 | base_00000001000000000000008D_D_00000001000000000000008B | Saturday, 25-Oct-25 16:19:48 UTC | 00000001000000000000008D | default      |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
rm -rf $PGDATA/*
wal-g backup-fetch $PGDATA base_000000010000000000000089
INFO: 2025/10/25 16:21:38.417866 Selecting the backup with name base_000000010000000000000089...
INFO: 2025/10/25 16:21:38.418493 Backup to fetch will be searched in storages: [default]
INFO: 2025/10/25 16:21:59.019478 Finished extraction of part_001.tar.lz4
INFO: 2025/10/25 16:22:04.190118 Finished extraction of part_002.tar.lz4
INFO: 2025/10/25 16:22:04.212486 Finished extraction of backup_label.tar.lz4
INFO: 2025/10/25 16:22:04.252190 Finished extraction of pg_control.tar.lz4
INFO: 2025/10/25 16:22:04.252266
Backup extraction complete.

touch $PGDATA/recovery.signal
sed -i '/archive_command/d' $PGDATA/postgresql.auto.conf
echo "recovery_target_time='2025-10-25 16:18:00'">>$PGDATA/postgresql.auto.conf
echo "recovery_target_action='pause'">>$PGDATA/postgresql.auto.conf
cat $PGDATA/postgresql.auto.conf
rm /var/log/postgresql/postgresql-16-main.log
pg_ctlcluster 16 main start
psql otus -c 'select * from mytest';
 id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833
psql otus -c 'select pg_get_wal_replay_pause_state()'
 pg_get_wal_replay_pause_state
-------------------------------
 paused
```
##### 5.2 Продолжение наката wal и восстановление второй записи таблицы
```sh
pg_ctlcluster 16 main stop
sed -i 's/2025-10-25 16:18:00/2025-10-25 16:19:00/g' $PGDATA/postgresql.auto.conf
pg_ctlcluster 16 main start
psql otus -c 'select * from mytest';
 id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833
  2 | 2025-10-25 16:18:11.638427
```
##### 5.3 Окончательный накат всех доступных wal и восстановление третьей записи таблицы
```sh
pg_ctlcluster 16 main stop
sed -i '/recovery_target_time/d' $PGDATA/postgresql.auto.conf
sed -i '/recovery_target_action/d' $PGDATA/postgresql.auto.conf
pg_ctlcluster 16 main start
psql otus -c 'select * from mytest';
 id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833
  2 | 2025-10-25 16:18:11.638427
  3 | 2025-10-25 16:19:12.849934
```

### 6. Восстановление из архива с полной и всех инкрементальных копий на хосте pg03
Восстанавливаем БД сразу на последнюю возможную точку из архива, по логу видно что используем сразу все архивы, полный и инкрементальные
```sh
pg_ctlcluster 16 main stop
wal-g backup-list --pretty
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| # | BACKUP NAME                                              | MODIFIED                         | WAL FILE NAME            | STORAGE NAME |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
| 0 | base_000000010000000000000089                            | Saturday, 25-Oct-25 16:17:50 UTC | 000000010000000000000089 | default      |
| 1 | base_00000001000000000000008B_D_000000010000000000000089 | Saturday, 25-Oct-25 16:18:50 UTC | 00000001000000000000008B | default      |
| 2 | base_00000001000000000000008D_D_00000001000000000000008B | Saturday, 25-Oct-25 16:19:48 UTC | 00000001000000000000008D | default      |
+---+----------------------------------------------------------+----------------------------------+--------------------------+--------------+
rm -rf $PGDATA/*
wal-g backup-fetch $PGDATA LATEST
INFO: 2025/10/25 16:31:53.616607 Selecting the latest backup...
INFO: 2025/10/25 16:31:53.617096 Backup to fetch will be searched in storages: [default]
INFO: 2025/10/25 16:31:53.898961 LATEST backup is: 'base_00000001000000000000008D_D_00000001000000000000008B'
INFO: 2025/10/25 16:31:53.980344 Delta from base_00000001000000000000008B_D_000000010000000000000089 at LSN 0/8B000028
INFO: 2025/10/25 16:31:54.060412 Delta from base_000000010000000000000089 at LSN 0/89000028
INFO: 2025/10/25 16:32:16.192467 Finished extraction of part_001.tar.lz4
INFO: 2025/10/25 16:32:21.047396 Finished extraction of part_002.tar.lz4
INFO: 2025/10/25 16:32:21.050643 Finished extraction of pg_control.tar.lz4
INFO: 2025/10/25 16:32:21.056333 Finished extraction of backup_label.tar.lz4
INFO: 2025/10/25 16:32:21.056370
Backup extraction complete.
INFO: 2025/10/25 16:32:21.056380 base_000000010000000000000089 fetched. Upgrading from LSN 0/89000028 to LSN 0/8B000028
INFO: 2025/10/25 16:32:21.102890 Finished extraction of part_001.tar.lz4
INFO: 2025/10/25 16:32:21.124440 Finished extraction of pg_control.tar.lz4
INFO: 2025/10/25 16:32:21.159775 Finished extraction of backup_label.tar.lz4
INFO: 2025/10/25 16:32:21.159830
Backup extraction complete.
INFO: 2025/10/25 16:32:21.159858 base_00000001000000000000008B_D_000000010000000000000089 fetched. Upgrading from LSN 0/8B000028 to LSN 0/8D000028
INFO: 2025/10/25 16:32:21.242746 Finished extraction of part_001.tar.lz4
INFO: 2025/10/25 16:32:21.314411 Finished extraction of backup_label.tar.lz4
INFO: 2025/10/25 16:32:21.316110 Finished extraction of pg_control.tar.lz4
INFO: 2025/10/25 16:32:21.316396
Backup extraction complete.

touch $PGDATA/recovery.signal
sed -i '/archive_command/d' $PGDATA/postgresql.auto.conf
rm /var/log/postgresql/postgresql-16-main.log
pg_ctlcluster 16 main start
psql otus -c 'select * from mytest';
 id |             dt
----+----------------------------
  1 | 2025-10-25 16:16:49.814833
  2 | 2025-10-25 16:18:11.638427
  3 | 2025-10-25 16:19:12.849934
```

### 7. Удаление стенда
```sh
./hosts.sh delete
```
