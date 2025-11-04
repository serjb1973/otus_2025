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
##### 4.5 Создание StatefulSet с PostgreSQL 17
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-statefulset.yaml
kubectl apply -f postgres-statefulset.yaml
kubectl get pods -l app=postgres
NAME         READY   STATUS              RESTARTS   AGE
postgres-0   0/1     ContainerCreating   0          12s
```
##### 4.5 Создание сервиса
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-service.yaml
kubectl apply -f postgres-service.yaml
kubectl get svc postgres
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
postgres   ClusterIP   10.101.53.137   <none>        5432/TCP   13s
```

### 5. Подключение к БД снаружи и создание таблицы 
##### 5.1 Проброс порта
```sh
kubectl port-forward -n demo svc/postgres 5432:5432
```
##### 5.2 Подключение к БД 
```sh
psql -h localhost -p 5432 -U otus_user -W -d otus
upass
```
##### 5.3 Создание таблицы 
```sh
otus=# create table mytest(id serial,dt date default now());
CREATE TABLE
otus=# insert into mytest values(default,default);
INSERT 0 1
otus=# select * from mytest;
 id |     dt
----+------------
  1 | 2025-11-04
(1 row)
otus=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 postgres-0  +
select pg_postmaster_start_time()-now();
```
##### 5.4 Пересоздание БД
```sh
kubectl get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
postgres-0   1/1     Running   0          23m   10.244.0.9   minikube   <none>           <none>

kubectl delete pod postgres-0 ;  kubectl get pods -l app=postgres
pod "postgres-0" deleted from default namespace
NAME         READY   STATUS              RESTARTS   AGE
postgres-0   0/1     ContainerCreating   0          0s

kubectl get pods -l app=postgres
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   1/1     Running   0          5s

kubectl port-forward -n demo svc/postgres 5432:5432
Forwarding from 127.0.0.1:5432 -> 5432
Forwarding from [::1]:5432 -> 5432
```
##### 5.5 Проверка наличия таблицы
```sh
yc-user@epdkp32fmcq8t9ckur46:~$ psql -h localhost -p 5432 -U otus_user -W -d otus
otus=# select * from mytest;
 id |     dt
----+------------
  1 | 2025-11-04
(1 row)

otus=# select pg_read_file('/etc/hostname');
 pg_read_file
--------------
 postgres-0  +
otus=# select pg_postmaster_start_time()-now();
     ?column?
------------------
 -00:05:01.395844
(1 row)
```
### 6. Удаление стенда
```sh
yc compute instance delete --name bananaflow-19730802
```
