[![Generic badge](https://img.shields.io/badge/Version-1.0-<COLOR>.svg)](https://shields.io/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/Naereen/StrapDown.js/graphs/commit-activity)
![Maintainer](https://img.shields.io/badge/maintainer-raphael.chir@gmail.com-blue)
# Cloud Native PG - HA
## Prerequisites for a local deployment

### 🖥️ Hardware Requirements  
- **Processor:** Intel i7 (12 cores)  
- **RAM:** 32 GB  

Note that adjustments will be done for ARM architecture

### Operating System  
The setup has been tested on the following OS:  
```plaintext
Distributor ID: Ubuntu  
Description:    Ubuntu 24.04.1 LTS  
Release:        24.04  
Codename:       noble  
```

### 🛠️ Software Dependencies  
Ensure the following software is installed:  

- **VirtualBox:** `7.x`  
- **Vagrant:** `2.4.3`  

## Tests Architecture 
These compomemts are installed automatically with vagrant  

- Kind : 1 Control plane and 3 Worker nodes  
- Kubectl : K8S CLI  
- CNPG plugin : Kubectl plugin for cnpg  
- CNPG : 1 Operator managing rw, r, ro postgresql instances 
- Minio : Backups  
- Client : Pod based on postgres:16 image deployed on the control-plane for tests purpose
- Prometheus / Grafana : Explore cnpg metrics 

## Start tests

- Launch your VM with vagrant up k8s  
- SSH into it with vagrant ssh k8s  
- Control the topology of your k8s cluster with kubectl get nodes  
- Verify in docker side that you have 4 kind containers + 1 minio containers    
- Access to minio
- All following command are launched from the VM !!  

Verify that you can access to minio UI. Duplicate your webssh and target 9001 port. (creds are admin/password).
Note that minio is not part of k8s, it is a simple docker container. List the running container on your environment:
```
docker ps
```
### Documentation
https://cloudnative-pg.io/documentation/1.25/  

### CNPG API :   
https://cloudnative-pg.io/documentation/1.25/cloudnative-pg.v1/

### CNPG Operator installation
First install the operator : 
```
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-1.25.1.yaml
```
```
kubectl get namespaces
kubectl get deployments.apps -n cnpg-system 
```
See the new objects created by the operator
```
kubectl api-resources
```
### CNPG plugin for kubectl
```
curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sudo sh -s -- -b /usr/local/bin

```
Then
```
kubectl cnpg
```

### Deploy a PostgreSQL cluster
- Change directory to `/vagrant/conf/test-00` (local) or `~/cnpg-ha/conf/tests-00` (labs) to directly access manifests
- Take a look on cluster-example.yaml
- You should consider the CNPG API references https://cloudnative-pg.io/documentation/1.25/cloudnative-pg.v1/
- Install the pg cluster in the default namespace
```
kubectl apply -f cluster-example.yaml
```
Control the status and objects related to the cluster
```
kubectl cnpg status cluster-example
kubectl get pods --label-columns role
kubectl get services
kubectl get pvc
kubectl get pv
kubectl get secrets
kubectl get configmaps
```

```
kubectl get clusters
```
### Operate your data with psql

CNPG plugin comes with psql
```
kubectl cnpg psql cluster-example
```
It avoids to install psql and connect to the rw service cluster-example-rw  
Then you can explore with psql and insert the sample of data
```
kubectl cnpg psql cluster-example < data.sql
```
--> Verify that data are replicated on the replicas

```
select o.id, c.name, p.name, o.quantity, o.total_price from orders o
join customers c on o.customer_id = c.id
join products p on o.product_id = p.id;
```

### Operate your PG cluster

In another panel or web browser tab, open the flows.  
Access to Prometheus dashboard and see cnpg metrics
```
kubectl -n monitoring port-forward services/prometheus-community-kube-prometheus 9090:9090 --address 0.0.0.0 &
```
Access to grafana (creds : admin/prom-operator)
```
kubectl -n monitoring port-forward services/prometheus-community-grafana 3000:80 --address 0.0.0.0 &

```
- Import the dashboard provided by CNPG - https://cloudnative-pg.io/documentation/1.25/quickstart/#grafana-dashboard
- Change the window frame to the last 5 minutes

Promote a new primary
```
kubectl cnpg promote cluster-example cluster-example-2
```
Look each monitoring tool : 
- cnpg status
- pods with --label-column role
- grafana
```
kubectl get cluster
```

### Backup / Restore
- Here we will perform a manual hot backup
- Optional but best practices in prod : `echo "select pg_switch_wal()" | kubectl cnpg psql cluster-example`
- Then apply the backup manifest
```
kubectl apply -f backup.yaml
```
See the status of the backup 
```
kubectl describe backups.postgresql.cnpg.io backup-test
```
--> Go to minio to see the backup

#### Full Restore
Now we will restore all the data in another pg cluster, by creating a new cluster manifest
```
kubectl apply -f full-restore.yaml
```
- Explore the new created clusters, connect with psql to it.  
- Wait a few minutes to see the cluster in Grafana  

#### PITR
Now we will test PITR. 
We insert data in the product table : 
```
INSERT INTO products (name, price, stock) VALUES
('Camera', 99.99, 150),
('Headphone', 190.80, 50);
```
Type `date` to get an idea of the point in time to set.
Then insert a user in customers table
```
INSERT INTO customers (name, email, created_at) VALUES
('Raphael Chir', 'corrupt@malware.com', now());
```
in pitr-restore.yaml modify the date to exclude the last transaction.
Then :
```
kubectl apply -f pitr-restore.yaml
```
Verify that the restore cluster in in the state corresponing of the target recovery time.

### Minor Upgrade  
We will upgrade PostgreSQL from 16.4 to 16.9
In cluster-example.yaml, replace image value by :
```
ghcr.io/cloudnative-pg/postgresql:16.9-1-bookworm@sha256:cf533c5f141b13a327d4678f49a1ace3bd5475f847e08d33b33255fde85717dc
```
- Then apply the manifest.
- Use grafana to see the rolling upgrade in action with the new version of PostgreSQL

### Major Upgrade  
We will upgrade PostgreSQL from 16 to 17.
As we use cnpg operator 1.25, we need to import one or more existing PostgreSQL databases inside a brand new CloudNativePG cluster. Use cluster-example-upgrade-16-to-17.yaml. This upgrade is based on the concept of online logical backups.
```
kubectl apply -f cluster-example-upgrade-16-to-17.yaml
```

CloudNativePG supports three methods for performing major upgrades:
- Logical dump/restore – Blue/green deployment, offline.
- Native logical replication – Blue/green deployment, online.
- Physical with pg_upgrade – In-place upgrade, offline (covered in the "Offline In-Place Major Upgrades" section below)- (from operator 1.26)

Use in cluster-example.yaml manifest this image :  
```
ghcr.io/cloudnative-pg/postgresql:17.5-7-bookworm
```
The apply and take a look on the pods

### Resiliency
Fence a replica to avoid that it is elected as a primary (simulate a corrupt replica)
```
kubectl cnpg fencing on cluster-example cluster-example-2
```
Then delete the primary pod
Unfence the replica (as it would be ok)
```
kubectl cnpg fencing off cluster-example cluster-example-2
```
Scale out your cluster
```
kubectl scale cluster cluster-restore --replicas=3
```

### SQL GUI Clients
```
kubectl cnpg pgadmin4 cluster-example
```
(creds user@pgadmin.com/kuM6AqD94X4ow90P1xVs0avfNq0qA6VM)


## Tests plan
| Tests                                   | Comments                                                                                       |
|----------------------------------------|------------------------------------------------------------------------------------------------|
| Switchover / Promote                   | kubectl cnpg promote cluster-example cluster-example-2`                                       |
| Failover (primary issue)               | kubectl delete pods cluster-example-1`                                                        |
| Failover (primary issue with idle cnx) | 1 idle primary connexion  kubectl delete pods cluster-example-1                   |
| Failover (worker issue)                | docker stop edbpg-worker2                                                                    |
| PostgreSQL minor version update        | Modify PostgreSQL version kubectl apply -f cluster-example.yaml                  |
| PostgreSQL extension update            | Activate / deactivate:  pg_stat_statements.max: "10000" pg_stat_statements.track: all kubectl apply -f cluster-example.yaml                  |
| Patching K8S                            | kubectl drain edbpg-worker --ignore-daemonsets --delete-emptydir-data Uncordon to reactivate the worker  kubectl uncordon edbpg-worker                          |

## Metrologie

Obviously you can deploy Prometheus / Grafana and build your dashboard with cnpg metrics

Connect to your VM and deploy test-script-pod.yaml
```
vagrant up k8s
...
vagrant ssh k8s
```
```
kubectl cluster-info
kubectl get nodes
kubectl apply -f /vagrant/conf/tests-01/cluster-example.yaml
cd /vagrant/conf/test-01
. ./cnpg-k8s-status.sh
kubectl apply -f cnpg-ha-tester.yaml
vagrant@k8s:/vagrant/conf/tests-01$ kubectl logs -f cnpg-ha-tester 
⏱️  Starting at : Sun Apr 20 02:49:49 PM UTC 2025
------------------------------
NOTICE:  relation "tt" already exists, skipping
CREATE TABLE
❌ Unavailability start at : 2025-04-20 14:50:27.188
✅ Unavailability ended at : 2025-04-20 14:50:37.889
⌛ Unavailability duration: 4.699s
------------------------------
```
Try to decrease Unavailability with tuning configuration. Use a retry strategy ...

## Troubleshooting tools

If you need curl and jq, instead of using busybox try :
```
kubectl run curl-jq --image=alpine -it --rm --restart=Never -- sh
apk add --no-cache curl jq
```
