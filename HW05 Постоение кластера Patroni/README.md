# Постоение кластера Patroni

Цель:
- развернуть отказоустойчивый кластер PostgreSQL с Patroni

### 1. Cоздание стенда из 7 хостов = 3 etcd + 3 postgres + 1 main
##### 1.1 Создание хостов одним скриптом
```sh
./hosts_create.sh 3 3
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
sudo wget -O etcd -P /etc/default https://github.com/serjb1973/otus_2025/blob/main/HW05%20Постоение%20кластера%20Patroni/etcd01
sudo cp etcd01.txt /etc/default/etcd
```
#etcd02
```sh
sudo cp etcd02.txt /etc/default/etcd
```
#etcd03
```sh
sudo cp etcd03.txt /etc/default/etcd
```
##### 2.4 Рестарт сервиса и проверка etcd
```sh
sudo systemctl restart etcd
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=10.129.0.11:2379,10.129.0.12:2379,10.129.0.13:2379
etcdctl endpoint status -w table
etcdctl cluster-health
etcdctl member list
```
##### 2.5 Доп проверка
#etcd01
```sh
etcdctl put foo "Hello World"
```
#etcd02
```sh
export ETCDCTL_API=3
etcdctl get foo
```

### 3. Установка Postgresql на четыре хоста
##### 3.1 Подключение с хоста main
```sh
ssh -i ~/.ssh/id_rsa yc-user@pg01
ssh -i ~/.ssh/id_rsa yc-user@pg01
ssh -i ~/.ssh/id_rsa yc-user@pg01
```
##### 3.2 Установка пакетов postgres на каждом хосте и на хосте main
```sh
sudo apt install -y postgresql-common && sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && sudo apt-get update && sudo apt -y install postgresql-16  && sudo apt -y install patroni
```

### Установка Patroni на три хоста
##### 4.1 Меняем конфиги БД на хостах pg01 + pg02 + pg03
```sh
sudo su postgres
echo "listen_addresses = '*'">> /etc/postgresql/16/main/postgresql.conf
vim /etc/postgresql/16/main/pg_hba.conf
host all all 0.0.0.0/0 scram-sha-256
host replication all 0.0.0.0/0 scram-sha-256
```
##### 4.3 Переносим конфиги БД на хостах pg02 + pg03 для patroni, он ожидает конфиг файл в $PGDATA, иначе не проходит инициализация
```sh
sudo -u postgres cp /etc/postgresql/16/main/postgresql.conf /var/lib/postgresql/16/main/
sudo -u postgres cp -rp /etc/postgresql/16/main/conf.d /var/lib/postgresql/16/main/
```
##### 4.3 Останавливаем БД на хостах pg02 + pg03
```sh
sudo systemctl stop postgresql
```
#pg02
```sh
cp patrony_02_config.yml /etc/patroni/config.yml
```
#pg03
```sh
cp patrony_02_config.yml /etc/patroni/config.yml
```
##### 4.4 Останавливаем БД на хосте pg01 и поднимаем её через сервис patroni
```sh
create user patroni password 'pat' superuser createdb createrole replication;
cp patrony_01_config.yml /etc/patroni/config.yml
sudo -u postgres patroni --validate-config /etc/patroni/config.yml
sudo vim /etc/patroni/config.yml
sudo systemctl stop postgresql
sudo -u postgres cp /etc/postgresql/16/main/postgresql.conf /var/lib/postgresql/16/main/
sudo -u postgres cp -rp /etc/postgresql/16/main/conf.d /var/lib/postgresql/16/main/
sudo systemctl restart patroni
patronictl -c /etc/patroni/config.yml show-config
patronictl -c /etc/patroni/config.yml list
```
##### 4.5 Выключаем сервис postgresql pg01
```sh
sudo systemctl disable postgresql
```
##### 4.6 Восстанавливаем реплики на хостах pg02 + pg03
```sh
rm -rf /var/lib/postgresql/16/main/*
sudo vim /etc/patroni/config.yml
sudo systemctl restart patroni
patronictl -c /etc/patroni/config.yml list
sudo systemctl disable postgresql
```

### 5. Тест Patroni
##### 5.1 Создаём таблицу на master БД pg01
```sh
sudo -u postgres psql -h pg01 -U patroni postgres
select pg_is_in_recovery();
select * from pg_get_replication_slots();
create database otus;
\c otus
create table mytest (id serial);
insert into mytest values (default);
select * from mytest;
```
##### 5.2 Проверяем репликацию на pg02
```sh
sudo -u postgres psql -h pg02 -U patroni otus
select * from mytest;
select pg_is_in_recovery();
select now()-pg_last_xact_replay_timestamp() as replay_lag;
```
##### 5.3 Делаем switchover
```sh
patronictl -c /etc/patroni/config.yml list
patronictl -c /etc/patroni/config.yml switchover
```

### 6. Установка Haproxy
##### 6.1 Переносим конфиги на хосте main
```sh
sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
sudo haproxy -c -V -f /etc/haproxy/haproxy.cfg
```
##### 6.2 Рестартуем сервис
```sh
sudo haproxy -c -V -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo systemctl status haproxy
```

### 7. Тест Patroni+Haproxy
##### 7.1 Соединение через Haproxy
```sh
sudo -u postgres psql -h 51.250.31.197 -U patroni -p 5555 otus
```
##### 7.2 Переключение БД
```sh
select pg_read_file('/etc/hostname');
patronictl -c /etc/patroni/config.yml switchover
select pg_read_file('/etc/hostname');
```
##### 7.3 Остановка хоста с БД в роли master 
```sh
yc compute instance stop bananaflow-19730802-pg02
select pg_read_file('/etc/hostname');
```

### 8. Удаление стенда
```sh
./hosts.sh delete
```
