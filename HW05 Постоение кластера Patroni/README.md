# Постоение кластера Patroni

Цель:
- развернуть отказоустойчивый кластер PostgreSQL с Patroni

### 1. Cоздание стенда из  3 etcd + 2 postgres + 1 main
##### 1.1 Создание хостов одним скриптом
```sh
./hosts_create.sh 3 2
+----------------------+----------------------------+---------------+---------+----------------+--------------+
|          ID          |            NAME            |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP  |
+----------------------+----------------------------+---------------+---------+----------------+--------------+
| epd0mbfkodlgfc0tajor | bananaflow-19730802-pg02   | ru-central1-b | RUNNING | 51.250.110.151 | 10.129.0.22  |
| epd9caboje7daoq32313 | bananaflow-19730802-etcd01 | ru-central1-b | RUNNING | 89.169.161.178 | 10.129.0.11  |
| epdal79rhhdgd44rifc6 | bananaflow-19730802-pg01   | ru-central1-b | RUNNING | 89.169.181.44  | 10.129.0.21  |
| epdgv7fhchu16nc2u77q | bananaflow-19730802-main   | ru-central1-b | RUNNING | 51.250.31.197  | 10.129.0.101 |
| epdiosm6tidu39hjkksm | bananaflow-19730802-etcd02 | ru-central1-b | RUNNING | 89.169.166.141 | 10.129.0.12  |
| epdj7pf88airbrbmo48m | bananaflow-19730802-etcd03 | ru-central1-b | RUNNING | 89.169.181.216 | 10.129.0.13  |
+----------------------+----------------------------+---------------+---------+----------------+--------------+
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
yc compute instance stop --name bananaflow-19730802-main
yc compute instance start --name bananaflow-19730802-main
yc compute instance delete --name bananaflow-19730802-main
```
##### 1.2 Перенос ключа на ност main, дял удобства работы со стендом
```sh
scp -i ~/.ssh/id_rsa -R ~/.ssh/id_rsa yc-user@51.250.31.197:~/.ssh/  
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
chmod 400 ~/.ssh/id_rsa
```
##### 1.3 Подключение на хост main и установка необходимых пакетов
```sh
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
sudo apt update && sudo apt upgrade -y && sudo apt install -y vim && sudo apt install -y postgresql-common && sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && sudo apt-get update && sudo apt -y install postgresql-16 && sudo apt -y install haproxy
```

### 2. Установка Etcd на три хоста
##### 2.1 Подключение с хоста main
```sh
ssh -i ~/.ssh/id_rsa yc-user@etcd01
ssh -i ~/.ssh/id_rsa yc-user@etcd02
ssh -i ~/.ssh/id_rsa yc-user@etcd03
```
##### 2.2 Установка пакета etcd на каждом хосте
```sh
sudo apt update && sudo apt upgrade -y && sudo apt install -y vim && sudo apt -y install etcd
sudo systemctl status etcd
sudo systemctl stop etcd
```
##### 2.3 Меняем конфиг файл
#etcd01
```sh
sudo wget -O /etc/default/etcd https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW05%20Постоение%20кластера%20Patroni/etcd01
```
#etcd02
```sh
sudo wget -O /etc/default/etcd https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW05%20Постоение%20кластера%20Patroni/etcd02
```
#etcd03
```sh
sudo wget -O /etc/default/etcd https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW05%20Постоение%20кластера%20Patroni/etcd03
```
##### 2.4 Рестарт сервиса и проверка etcd
```sh
sudo systemctl restart etcd
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=10.129.0.11:2379,10.129.0.12:2379,10.129.0.13:2379
etcdctl endpoint status -w table
+------------------+------------------+---------+---------+-----------+-----------+------------+
|     ENDPOINT     |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM | RAFT INDEX |
+------------------+------------------+---------+---------+-----------+-----------+------------+
| 10.129.0.11:2379 | cbebe40647788a92 |  3.3.25 |   20 kB |     false |         5 |          9 |
| 10.129.0.12:2379 | f2a1b7d07b486f3e |  3.3.25 |   20 kB |     false |         5 |          9 |
| 10.129.0.13:2379 | b1b546f51ce9d0a8 |  3.3.25 |   20 kB |      true |         5 |          9 |
+------------------+------------------+---------+---------+-----------+-----------+------------+
etcdctl member list
yc-user@etcd01:~$ etcdctl member list
b1b546f51ce9d0a8, started, etcd03, http://10.129.0.13:2380, http://10.129.0.13:2379
cbebe40647788a92, started, etcd01, http://10.129.0.11:2380, http://10.129.0.11:2379
f2a1b7d07b486f3e, started, etcd02, http://10.129.0.12:2380, http://10.129.0.12:2379
yc-user@etcd01:~$
```
##### 2.5 Доп проверка
#etcd01
```sh
yc-user@etcd01:~$ etcdctl put foo "Hello World"
OK
```
#etcd02
```sh
yc-user@etcd02:~$ export ETCDCTL_API=3
etcdctl get foo
foo
Hello World
yc-user@etcd02:~$
```

### 3. Установка Postgresql
##### 3.1 Подключение с хоста main
```sh
ssh -i ~/.ssh/id_rsa yc-user@pg01
ssh -i ~/.ssh/id_rsa yc-user@pg02
```
##### 3.2 Установка пакетов postgres на каждом хосте
```sh
sudo apt install -y postgresql-common && sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && sudo apt-get update && sudo apt -y install postgresql-16  && sudo apt -y install patroni
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
##### 7.4 Остановка хоста с БД в роли master 
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
