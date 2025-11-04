# Введение в Kubernetes: Работа с хранилищами данных и конфигурациями

Цель:
- развернуть PostgreSQL в локальном Kubernetes-кластере Minikube, обеспечить её доступность и масштабируемость


### 1. Cоздание стенда
##### 1.1 Создание Виртуальной машины в облаке https://cloud.yandex.ru
```sh
yc compute instance create \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,auto-delete,type=network-hdd,size=50GB \
  --name bananaflow-19730802 \
  --public-address 51.250.31.197 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --memory 16GB --cores 4 --core-fraction 20 --preemptible
```
###### Просмотр списка виртаульных машин
```sh
yc compute instance list
```
###### 1.2 Управление виртуальной машиной
```sh
yc compute instance stop --name bananaflow-19730802
yc compute instance start --name bananaflow-19730802
yc compute instance delete --name bananaflow-19730802
```

### 2 Установка Minikube
https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fdebian+package
```sh
ssh -i ~/.ssh/id_rsa yc-user@51.250.31.197
sudo apt update && sudo apt upgrade -y && sudo apt install -y vim docker docker.io net-tools postgresql-client-common postgresql-client-14
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
sudo usermod -aG docker yc-user && newgrp docker
```

### 3. Старт kubernetes и проверка
```sh
minikube start --kubernetes-version=v1.34.0
alias kubectl="minikube kubectl --"
minikube kubectl get nodes
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   2m11s   v1.34.0
```

### 4. Создание и запуск postgres как statefulset
##### 4.1 Создание namespace
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/demo-namespace.yaml
kubectl apply -f demo-namespace.yaml
```
##### 4.2 Создание Secret с паролями
```sh
yc-user@epdkp32fmcq8t9ckur46:~$ echo -n "pgpass"|base64
cGdwYXNz
yc-user@epdkp32fmcq8t9ckur46:~$ echo -n "upass"|base64
dXBhc3M=
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-secret.yaml
kubectl apply -f postgres-secret.yaml
```
##### 4.3 Создание конфигов
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-config.yaml
kubectl apply -f postgres-config.yaml
```
##### 4.4 Создание дисковой подсистемы
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-pvc.yaml
kubectl apply -f postgres-pvc.yaml
kubectl get pvc postgres-pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
postgres-pvc   Bound    pvc-22006eb3-2683-48b3-a78a-2a3189a06ee4   10Gi       RWO            standard       <unset>                 15s
```
##### 4.3 Создание конфигов
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-config.yaml
kubectl apply -f postgres-config.yaml
```

### 5. Оптимизация настроек ОС
##### 5.1 HugePage
###### Вычисляем оптимальный размер
```sh
yc-user@epd9b2clad1ukm0lgl9j:~$ grep -e "^HugePages" /proc/meminfo
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
yc-user@epd9b2clad1ukm0lgl9j:~$ sudo  head -1 /var/lib/postgresql/16/main/postmaster.pid
703
yc-user@epd9b2clad1ukm0lgl9j:~$ grep ^VmPeak /proc/703/status
VmPeak:  8674956 kB
yc-user@epd9b2clad1ukm0lgl9j:~$ echo $((8674956 / 2048 + 1))
4236
```
###### Устанавливаем HugePage
```sh
echo "vm.nr_hugepages = 4236" |sudo tee -a /etc/sysctl.conf 
```
##### 5.2 Устанавливаем transparent_hugepage
```sh
sudo vim /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'
[Install]
WantedBy=multi-user.target

sudo systemctl daemon-reload
sudo systemctl enable disable-thp.service
sudo systemctl start disable-thp.service
```
##### 5.3 Устанавливаем размер swappiness
```sh
cat /proc/sys/vm/swappiness
60
echo "vm.swappiness=5" |sudo tee -a /etc/sysctl.conf
```
##### 5.4 Перезагружаем хост

### 6. Тест 2 pgbench (сделана перезагрузка виртуалки и затем несколько запусков pgbench, в зачёт идёт лучший по цифрам запуск)
```sh
sudo -u postgres pgbench -j 4 -v -c 80 -T 60 otus ; sudo -u postgres pgbench -j 4 -v -c 80 -T 60 otus ; sudo -u postgres pgbench -j 4 -v -c 80 -T 60 otus
starting vacuum...end.
starting vacuum pgbench_accounts...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1000
query mode: simple
number of clients: 80
number of threads: 4
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 29413
number of failed transactions: 0 (0.000%)
latency average = 163.173 ms
initial connection time = 122.453 ms
tps = 490.277494 (without initial connection time)
```

### 7. Изменение настроек БД - отключение fsync
```sh
sudo -u postgres psql -c "alter system set fsync='off'"
sudo -u postgres psql -c "alter system set full_page_writes='off'"
sudo systemctl restart postgresql;
sudo -u postgres psql -c "select name,setting,source from pg_settings where source!='default'"
               name               |                 setting                 |       source
----------------------------------+-----------------------------------------+--------------------
 application_name                 | psql                                    | client
 client_encoding                  | UTF8                                    | client
 cluster_name                     | 16/main                                 | configuration file
 config_file                      | /etc/postgresql/16/main/postgresql.conf | override
 data_directory                   | /var/lib/postgresql/16/main             | override
 DateStyle                        | ISO, MDY                                | configuration file
 default_text_search_config       | pg_catalog.english                      | configuration file
 dynamic_shared_memory_type       | posix                                   | configuration file
 effective_cache_size             | 3145728                                 | configuration file
 effective_io_concurrency         | 2                                       | configuration file
 external_pid_file                | /var/run/postgresql/16-main.pid         | configuration file
 fsync                            | off                                     | configuration file
 full_page_writes                 | off                                     | configuration file
 hba_file                         | /etc/postgresql/16/main/pg_hba.conf     | override
 ident_file                       | /etc/postgresql/16/main/pg_ident.conf   | override
 lc_messages                      | C.UTF-8                                 | configuration file
 lc_monetary                      | C.UTF-8                                 | configuration file
 lc_numeric                       | C.UTF-8                                 | configuration file
 lc_time                          | C.UTF-8                                 | configuration file
 listen_addresses                 | *                                       | configuration file
 log_line_prefix                  | %m [%p] %q%u@%d                         | configuration file
 log_timezone                     | Etc/UTC                                 | configuration file
 maintenance_work_mem             | 2097152                                 | configuration file
 max_connections                  | 100                                     | configuration file
 max_parallel_maintenance_workers | 16                                      | configuration file
 max_wal_size                     | 4096                                    | configuration file
 min_wal_size                     | 1024                                    | configuration file
 port                             | 5432                                    | configuration file
 shared_buffers                   | 1048576                                 | configuration file
 ssl                              | on                                      | configuration file
 ssl_cert_file                    | /etc/ssl/certs/ssl-cert-snakeoil.pem    | configuration file
 ssl_key_file                     | /etc/ssl/private/ssl-cert-snakeoil.key  | configuration file
 TimeZone                         | Etc/UTC                                 | configuration file
 transaction_deferrable           | off                                     | override
 transaction_isolation            | read committed                          | override
 transaction_read_only            | off                                     | override
 unix_socket_directories          | /var/run/postgresql                     | configuration file
 work_mem                         | 83968                                   | configuration file
(38 rows)
```

### 8. Тест 3 pgbench (сделана перезагрузка виртуалки и затем несколько запусков pgbench, в зачёт идёт лучший по цифрам запуск)
```sh
sudo -u postgres pgbench -j 4 -v -c 80 -T 60 otus ; sudo -u postgres pgbench -j 4 -v -c 80 -T 60 otus ; sudo -u postgres pgbench -j 4 -v -c 80 -T 60 otus
pgbench (16.10 (Ubuntu 16.10-1.pgdg22.04+1))
starting vacuum...end.
starting vacuum pgbench_accounts...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1000
query mode: simple
number of clients: 80
number of threads: 4
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 324556
number of failed transactions: 0 (0.000%)
latency average = 14.785 ms
initial connection time = 106.568 ms
tps = 5410.918620 (without initial connection time)
```

### 9. Итого и вывод
##### 9.1 Производительность с настройками ОС по умолчанию
tps = 175.074525 (without initial connection time)
##### 9.2 Производительность с настройками ОС transparent_hugepage=off,hugepage=on,swappiness=5
tps = 490.277494 (without initial connection time)
##### 9.3 Производительность с настройками БД отключение синхронной записи wal
tps = 5410.918620 (without initial connection time)
##### 9.4 Вывод:
**Настройка ОС может дать кратное повышение производительности.**


### 10. Удаление стенда
```sh
yc compute instance delete --name bananaflow-19730802
```
