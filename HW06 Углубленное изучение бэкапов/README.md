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
вставка строк(пример):
```sh
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+h+sCDGnJXmkskkTHBZ1sbGCn8+QOaE+uvqDa4a/OwnCfQ7ktdTvaLhQPPp6yvEkIpgouRt9oH7ygxCUcM9NXdJxs64MPv/wH0mNL9+eYv2ukC6acvQZfMb78Q8X24qO3kPS/zs20srGaKseiTtf6SZjMAwAl35a/CirNT2m5bKG0EUsGZIH5MDCGnLpTJn1pFKqkdDdQNMUd1WFCa14tjsYKpRxBXTv4LxuSa/ItfF8wWhD7nSsPNFnJwRzgSKIZlDCVSvtLmx6ZRe+3ovi/RZyWryGR/e0ALj5IdYxXFBluHrv0CWHpcIo0MuXn1ufDKRirO5Hkb78DPAcqUaqENBkJ+0HqahJ4m+z5zkQWlUNxB+hsc0vpZBIKcB3FNb/8Hw7weZ+VK8C9Xl5DK/Fj4e0zQ7buWSdA+43Pfm2LhVGxpTQVaYx1k/Dvwes7LbFhjqPEuKwPsMGfH1AJskEKfhdX19+enPv9NO5jbkSwGCiKxwxAokGCNQeqpi9QCLM= postgres@pg01
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWVO8MfnlXHRj3P2rarRX0H7Spbyv5etJwMA3PXtsr7UlJWz7OpbqlbatflCIDnNm1xa5PNKoCGNvTW2EBE4bN1N5fxD6AdgImyuH7lINJ9drj3IcI22YFAExrQGOuJzkKahIfmDaQo8lRPlsTCNLak1GhL28T6JsfwXI0OswIyIIgvZChfk/dxrVS1vz+pg/sCLt7KBwpOELjzIHWxlMK0sTd2TCMe0oMpsOipmO+Kdv+da7beyZUSAL77sSZa074XZZapJ4nANkbq51Nz3lOkl8kjYi4BPy1gPLRuW9MqlX0Y4LBoyJ4EiR6+/eK3Z3ie+o1vzKvSeaFtoZBzhOyt3HzqNfsyuYoP2EjcbgYUbNsGfD6yjh5u40rSwnzUswGGAO2Min6O76UIOewUQksqKi62ygIdsnoI/jhcJK4JAJNBo/FMqifKDsp76zdAzEO3psJRX7IsZpJrVJksD3PZU7JrsZXBPBhiE/MxT2J5RzhPaKV/TEKAh4K3TdqNVc= postgres@pg03
```
##### 2.3 Тест ssh с хостов pg01 pg03
ssh test
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
##### 3.2 Настройка postgres на хосте pg01
```sh
sudo -u postgres psql
create user backuper password 'db' superuser createdb createrole replication;
create database otus;
pgbench -i -s 100 otus
psql -l
postgres=# select pg_size_pretty(pg_database_size('otus'));
 pg_size_pretty
----------------
 1503 MB
(1 row)
vim ~/.pgpass
localhost:5432:postgres:backuper:db
chmod 600 ~/.pgpass
sudo -u postgres psql
alter system set archive_mode = on;
alter system set archive_timeout = 60;
alter system set archive_command = '/usr/local/bin/wal-g wal-push "%p" 2>&1 | tee -a /var/lib/postgresql/walg.log';
alter system set restore_command = '/usr/local/bin/wal-g wal-fetch "%f" "%p" 2>&1 | tee -a /var/lib/postgresql/walg.log';
sudo systemctl restart postgresql
```


### Установка Patroni
##### 4.1 Меняем конфиги БД на хостах pg01 + pg02
```sh
sudo su postgres
echo "listen_addresses = '*'">> /etc/postgresql/16/main/postgresql.conf
echo "host all all 0.0.0.0/0 scram-sha-256">>/etc/postgresql/16/main/pg_hba.conf
echo "host replication all 0.0.0.0/0 scram-sha-256">>/etc/postgresql/16/main/pg_hba.conf
```
##### 4.2 Останавливаем и удаляем БД на хосте pg02
```sh
sudo systemctl stop postgresql
sudo systemctl disable postgresql
sudo rm -rf /var/lib/postgresql/16/main/*
sudo systemctl stop patroni
sudo wget -O /etc/patroni/config.yml https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW05%20Постоение%20кластера%20Patroni/patroni_02_config.yml
sudo cat /etc/patroni/config.yml
```

##### 4.3 Останавливаем БД на хосте pg01 и поднимаем её через сервис patroni
```sh
sudo -u postgres psql
create user patroni password 'pat' superuser createdb createrole replication;
sudo systemctl stop patroni
sudo wget -O /etc/patroni/config.yml https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW05%20Постоение%20кластера%20Patroni/patroni_01_config.yml
sudo -u postgres patroni --validate-config /etc/patroni/config.yml
sudo vim /etc/patroni/config.yml
sudo systemctl stop postgresql
sudo systemctl disable postgresql
sudo systemctl start patroni
patronictl -c /etc/patroni/config.yml show-config
patronictl -c /etc/patroni/config.yml list
yc-user@pg01:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) -+----+-----------+
| Member | Host        | Role   | State   | TL | Lag in MB |
+--------+-------------+--------+---------+----+-----------+
| pg01   | 10.129.0.21 | Leader | running |  2 |           |
+--------+-------------+--------+---------+----+-----------+
```
##### 4.4 Восстанавливаем реплику на pg02 
```sh
sudo systemctl start patroni
patronictl -c /etc/patroni/config.yml list
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Leader  | running   |  2 |           |
| pg02   | 10.129.0.22 | Replica | streaming |  2 |         0 |
+--------+-------------+---------+-----------+----+-----------+
```

### 5. Тест Patroni
##### 5.1 Создаём таблицу на master БД pg01
```sh
sudo -u postgres psql -h pg01 -U patroni postgres
postgres=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 pg01        +
postgres=# select pg_is_in_recovery();
 pg_is_in_recovery
-------------------
 f
(1 row)
select * from pg_get_replication_slots();
postgres=# select * from pg_get_replication_slots();
 slot_name | plugin | slot_type | datoid | temporary | active | active_pid | xmin | catalog_xmin | restart_lsn | confirmed_flush_lsn | wal_status | safe_wal_size | two_phase | conflicting
-----------+--------+-----------+--------+-----------+--------+------------+------+--------------+-------------+---------------------+------------+---------------+-----------+-------------
 pg02      |        | physical  |        | f         | t      |       1115 |      |              | 0/3000148   |                     | reserved   |               | f         |
(1 row)
create database otus;
\c otus
create table mytest (id serial);
insert into mytest values (default);
otus=# select * from mytest;
 id
----
  1
(1 row)
```
##### 5.2 Проверяем репликацию на pg02
```sh
sudo -u postgres psql -h pg02 -U patroni otus
otus=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 pg02        +

(1 row)

otus=# select * from mytest;
 id
----
  1
(1 row)

otus=# select pg_is_in_recovery();
 pg_is_in_recovery
-------------------
 t
(1 row)

otus=# select now()-pg_last_xact_replay_timestamp() as replay_lag;
   replay_lag
-----------------
 00:01:32.959131
(1 row)
```
##### 5.3 Делаем switchover
```sh
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Leader  | running   |  2 |           |
| pg02   | 10.129.0.22 | Replica | streaming |  2 |         0 |
+--------+-------------+---------+-----------+----+-----------+
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml switchover
Current cluster topology
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Leader  | running   |  2 |           |
| pg02   | 10.129.0.22 | Replica | streaming |  2 |         0 |
+--------+-------------+---------+-----------+----+-----------+
Primary [pg01]:
Candidate ['pg02'] []:
When should the switchover take place (e.g. 2025-10-21T16:54 )  [now]:
Are you sure you want to switchover cluster 16/main, demoting current leader pg01? [y/N]: y
2025-10-21 15:54:43.35232 Successfully switched over to "pg02"
+ Cluster: 16/main (7563341935804649837) --+----+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| pg01   | 10.129.0.21 | Replica | stopped |    |   unknown |
| pg02   | 10.129.0.22 | Leader  | running |  2 |           |
+--------+-------------+---------+---------+----+-----------+
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Replica | streaming |  3 |         0 |
| pg02   | 10.129.0.22 | Leader  | running   |  3 |           |
+--------+-------------+---------+-----------+----+-----------+
```

### 6. Установка Haproxy
##### 6.1 Переносим конфиги на хосте main
```sh
sudo systemctl stop haproxy
sudo wget -O /etc/haproxy/haproxy.cfg https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW05%20Постоение%20кластера%20Patroni/haproxy.cfg
```
##### 6.2 Рестартуем сервис
```sh
sudo haproxy -c -V -f /etc/haproxy/haproxy.cfg
sudo systemctl start haproxy
sudo systemctl status haproxy
```

### 7. Тест Patroni+Haproxy
##### 7.1 Соединение через Haproxy
```sh
sudo -u postgres psql -h 51.250.31.197 -U patroni -p 5555 otus
otus=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 pg02        +
```
##### 7.2 Переключение БД
```sh
yc-user@pg01:~$ patronictl -c /etc/patroni/config.yml switchover
Current cluster topology
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Replica | streaming |  3 |         0 |
| pg02   | 10.129.0.22 | Leader  | running   |  3 |           |
+--------+-------------+---------+-----------+----+-----------+
Primary [pg02]:
Candidate ['pg01'] []:
When should the switchover take place (e.g. 2025-10-21T17:12 )  [now]:
Are you sure you want to switchover cluster 16/main, demoting current leader pg02? [y/N]: y
2025-10-21 16:12:45.94027 Successfully switched over to "pg01"
+ Cluster: 16/main (7563341935804649837) --+----+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| pg01   | 10.129.0.21 | Leader  | running |  3 |           |
| pg02   | 10.129.0.22 | Replica | stopped |    |   unknown |
+--------+-------------+---------+---------+----+-----------+
yc-user@pg01:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Leader  | running   |  4 |           |
| pg02   | 10.129.0.22 | Replica | streaming |  4 |         0 |
+--------+-------------+---------+-----------+----+-----------+
```
##### 7.3 Соединение через Haproxy после switchover в той же сессии
```sh
otus=# select pg_read_file('/etc/hostname');
FATAL:  terminating connection due to administrator command
SSL connection has been closed unexpectedly
The connection to the server was lost. Attempting reset: Succeeded.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
otus=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 pg01        +
```
##### 7.4 Остановка хоста с БД в роли master - failover
```sh
yc compute instance stop bananaflow-19730802-pg01
```
##### 7.5 Соединение через Haproxy после failover в той же сессии
```sh
otus=# select pg_read_file('/etc/hostname');
FATAL:  terminating connection due to administrator command
SSL connection has been closed unexpectedly
The connection to the server was lost. Attempting reset: Succeeded.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
otus=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 pg02        +
```
##### 7.6 Проверка состояния patroni после failover
```sh
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) -+----+-----------+
| Member | Host        | Role   | State   | TL | Lag in MB |
+--------+-------------+--------+---------+----+-----------+
| pg02   | 10.129.0.22 | Leader | running |  5 |           |
+--------+-------------+--------+---------+----+-----------+
yc-user@pg02:~$
```
##### 7.7 Старт упавшего хоста хоста с БД в роли master 
```sh
yc compute instance start bananaflow-19730802-pg01
```
##### 7.8 Проверка состояния patroni после старта хоста после падения
```sh
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) -+----+-----------+
| Member | Host        | Role   | State   | TL | Lag in MB |
+--------+-------------+--------+---------+----+-----------+
| pg02   | 10.129.0.22 | Leader | running |  5 |           |
+--------+-------------+--------+---------+----+-----------+
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) --+----+-----------+
| Member | Host        | Role    | State   | TL | Lag in MB |
+--------+-------------+---------+---------+----+-----------+
| pg01   | 10.129.0.21 | Replica | stopped |    |   unknown |
| pg02   | 10.129.0.22 | Leader  | running |  5 |           |
+--------+-------------+---------+---------+----+-----------+
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) ---+----+-----------+
| Member | Host        | Role    | State    | TL | Lag in MB |
+--------+-------------+---------+----------+----+-----------+
| pg01   | 10.129.0.21 | Replica | starting |    |   unknown |
| pg02   | 10.129.0.22 | Leader  | running  |  5 |           |
+--------+-------------+---------+----------+----+-----------+
yc-user@pg02:~$ patronictl -c /etc/patroni/config.yml list
+ Cluster: 16/main (7563341935804649837) ----+----+-----------+
| Member | Host        | Role    | State     | TL | Lag in MB |
+--------+-------------+---------+-----------+----+-----------+
| pg01   | 10.129.0.21 | Replica | streaming |  5 |         0 |
| pg02   | 10.129.0.22 | Leader  | running   |  5 |           |
+--------+-------------+---------+-----------+----+-----------+
```

### 8. Удаление стенда
```sh
./hosts.sh delete
```
