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
kubectl get namespace
NAME              STATUS   AGE
default           Active   68s
demo              Active   7s
kube-node-lease   Active   68s
kube-public       Active   68s
kube-system       Active   68s

```
##### 4.2 Создание Secret с паролями
```sh
echo -n "pgpass"|base64
cGdwYXNz
echo -n "upass"|base64
dXBhc3M=
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-secret.yaml
kubectl apply -f postgres-secret.yaml
kubectl -n demo get secret
NAME               TYPE     DATA   AGE
postgres-secrets   Opaque   2      3m34s

```
##### 4.3 Создание конфигов
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-config.yaml
kubectl apply -f postgres-config.yaml
kubectl -n demo get configmap
NAME               DATA   AGE
kube-root-ca.crt   1      5m12s
postgres-config    2      34s

```
##### 4.4 Создание дисковой подсистемы
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-pvc.yaml
kubectl apply -f postgres-pvc.yaml
kubectl -n demo get pvc postgres-pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
postgres-pvc   Bound    pvc-138d8d11-5230-4d3e-983f-ff3dc60e628d   10Gi       RWO            standard       <unset>                 12s
```
##### 4.5 Создание StatefulSet с PostgreSQL 17
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-statefulset.yaml
kubectl apply -f postgres-statefulset.yaml
kubectl -n demo get pods -l app=postgres
NAME         READY   STATUS              RESTARTS   AGE
postgres-0   0/1     ContainerCreating   0          12s
```
##### 4.5 Создание сервиса
```sh
wget https://github.com/serjb1973/otus_2025/raw/refs/heads/main/HW10%20Введение%20в%20Kubernetes%20Работа%20с%20хранилищами%20данных%20и%20конфигурациями/postgres-service.yaml
kubectl apply -f postgres-service.yaml
kubectl -n demo get svc postgres
NAME       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
postgres   ClusterIP   10.106.249.104   <none>        5432/TCP   9s
```

### 5. Подключение к БД снаружи и создание таблицы 
##### 5.1 Проброс порта
```sh
kubectl port-forward -n demo svc/postgres 5432:5432
Forwarding from 127.0.0.1:5432 -> 5432
Forwarding from [::1]:5432 -> 5432
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
otus=# select pg_postmaster_start_time()-now();
     ?column?
------------------
 -00:01:51.023688
(1 row)
```
##### 5.4 Пересоздание БД
```sh
 kubectl -n demo get pods -l app=postgres ; kubectl -n demo delete pod postgres-0 ;  kubectl -n demo get pods -l app=postgres
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   1/1     Running   0          3m48s
pod "postgres-0" deleted from demo namespace
NAME         READY   STATUS              RESTARTS   AGE
postgres-0   0/1     ContainerCreating   0          0s

kubectl -n demo get pods -l app=postgres
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   0/1     Running   0          6s

kubectl port-forward -n demo svc/postgres 5432:5432
Forwarding from 127.0.0.1:5432 -> 5432
Forwarding from [::1]:5432 -> 5432
```
##### 5.5 Проверка наличия таблицы
```sh
psql -h localhost -p 5432 -U otus_user -W -d otus
upass
otus=# select * from mytest;
 id |     dt
----+------------
  1 | 2025-11-04
(1 row)
otus=# select pg_postmaster_start_time()-now();
     ?column?
------------------
 -00:00:44.467609
(1 row)
otus=# select pg_postmaster_start_time()-now();
     ?column?
------------------
 -00:00:48.232838
(1 row)
```
### 6. Удаление стенда
```sh
yc compute instance delete --name bananaflow-19730802
```
