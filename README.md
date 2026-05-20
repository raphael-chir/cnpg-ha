[![Generic badge](https://img.shields.io/badge/Version-1.0-<COLOR>.svg)](https://shields.io/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/Naereen/StrapDown.js/graphs/commit-activity)
![Maintainer](https://img.shields.io/badge/maintainer-raphael.chir@gmail.com-blue)
# Cloud Native PG - Demo
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

- **libvirt:** `10.0.0`
- **QEMU** `QEMU emulator version 8.2.2` 
- **KMS** `6.17.0-19-generic`    
- **Vagrant:** `2.4.9`  

## Tests Architecture 
These components are installed automatically with vagrant  

- Kind : 1 Control plane and 3 Worker nodes  
- Kubectl : K8S CLI + kubectl CNPG plugin  
- Cert-manager : for managing TLS (not ready yet)  
- Minio : Backups  
- Prometheus / Grafana : Explore cnpg metrics 

## Tests your initial config

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
https://cloudnative-pg.io/docs/1.28/


### CNPG Operator installation
First install the operator : 
```
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.28/releases/cnpg-1.28.1.yaml
```
And verify
```
kubectl rollout status deployment \
  -n cnpg-system cnpg-controller-manager
```

See the new objects created by the operator
```
kubectl api-resources
```

### Install Barman CNPG plugin
```
kubectl apply -f \
        https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/v0.11.0/manifest.yaml
```
And verify
```
kubectl rollout status deployment \
  -n cnpg-system barman-cloud
```
### Deploy a PostgreSQL cluster
- Change directory to `/vagrant/manifests` (local) or `~/cnpg-ha/manifests` (labs) to directly access manifests
- Take a look on pg-cluster.yaml
- You should consider the CNPG API references https://cloudnative-pg.io/docs/1.28/cloudnative-pg.v1  
- Install the pg cluster in the default namespace
```
kubectl apply -f 00-pg-cluster.yaml
```
Control the status and objects related to the cluster
```
kubectl get pods --label-columns role
kubectl get services
kubectl get pvc
kubectl get pv
kubectl get secrets
kubectl get configmaps
```
See cluster status
```
kubectl cnpg status pg-cluster
```

```
kubectl get clusters
```
### Operate your data with psql

CNPG plugin comes with psql
```
kubectl cnpg psql pg-cluster
```
It avoids to install psql and connect to the rw service pg-cluster-rw  
Then you can explore with psql and insert the sample of data
```
kubectl cnpg psql pg-cluster < data.sql
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
kubectl cnpg promote pg-cluster pg-cluster-2
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
- Optional but best practices in prod : `echo "select pg_switch_wal()" | kubectl cnpg psql pg-cluster`
- Then apply the backup manifest
```
kubectl apply -f 01-pg-cluster-backup.yaml
```
See the status of the backup 
```
kubectl describe backups.postgresql.cnpg.io pg-backup
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

Since CNPG Operator 1.26, CloudNativePG supports Physical upgrade with pg_upgrade – In-place upgrade, offline - for performing major upgrades

Use in cluster-example.yaml manifest this image :  
```
ghcr.io/cloudnative-pg/postgresql:17.5-7-bookworm
```
The apply and take a look on the pods

### Resiliency

1 - Scale out your cluster
```
kubectl scale cluster cluster-restore --replicas=3
```
2 - Delete the primary pod of your cluster to see failover in action

3 - Fence a replica to avoid that it is elected as a primary (simulate a corrupt replica)
```
kubectl cnpg fencing on cluster-example cluster-example-2
```
Then delete the primary pod
Unfence the replica (as it would be ok)
```
kubectl cnpg fencing off cluster-example cluster-example-2
```

### SQL GUI Clients
```
kubectl cnpg pgadmin4 --mode desktop cluster-example
```
(if needed creds user@pgadmin.com/kuM6AqD94X4ow90P1xVs0avfNq0qA6VM)

### Performance tests

Use pgbench, a tools that create 4 tables to simulate banking transactions.  
First init the database
```
kubectl cnpg pgbench --job-name pgb-init cluster-example -- --initialize --scale 10
```
Scale is just the factor to multiply your table data. Base is for each tables :
- pgbench_accounts = 100 000 rows
- pgbench_branches =  1 row
- pgbench_tellers = 10 rows
- pgbench_history = 0 row (feed during the test)

Execute the workload and see the metrics in action in Grafana
```
kubectl cnpg pgbench --job-name pgb-run00 cluster-example -- --client 50 --time 180 --jobs 2
```

## HA Tests plan
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

### If you need curl and jq, instead of using busybox try :
```
kubectl run curl-jq --image=alpine -it --rm --restart=Never -- sh
apk add --no-cache curl jq
```

### How to test with a proxy between your k8s cluster in kind and minio in docker

Try mitmproxy, deploy a docker container in your kind network
```
docker run --rm -it -p 8080:8080 -p 192.168.56.10:8081:8081 --name mitmproxy --network kind mitmproxy/mitmproxy mitmweb --web-host 0.0.0.0
```
Then go to the UI : http://192.168.56.10:8081/?<your token provide in the output of previous command>  

Modify your cluster manifest by adding in spec section
```
  env:
  - name: HTTP_PROXY
    value: http://mitmproxy:8080
```
Apply the manifest

## CRC / OpenShift

### CRC parameters
```
crc config --help
```
Before starting crc
```
crc config view
crc setup check
```

If you want to get your credentials :
```
crc console --credentials
```
### OLM - Operator Lifecycle Manager
To install CNPG on CRC/Openshift we :  
1 - Create cnpg-system namespaces  
2 - Apply a Security Context Constraints (SCC) to cnpg-system  
3 - Create an OperatorGroup to define the target namespaces it can operate.  
4 - Explore the package manifests to find out operator, source and channel  
5 - Create Subscription bases on the desired version of operator  
6 - Check the status of the operator  
7 - Test a deployment   
8 - Clean all

#### cnpg-system
First create cnpg-system namespace where CNPG operator will live.
```
oc create ns cnpg-system
```
Before deploying anything in that namespace, give it some rights policy
```
oc adm policy add-scc-to-group anyuid system:serviceaccounts:cnpg-system
```
#### Create OperatorGroup
Now we open the operator scope to cluster-wide instead of doing it namespace by namespace. Here a manifest to apply, note that there is no restrictions to specific namespaces.
```
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cnpg-og
  namespace: cnpg-system
spec:
  targetNamespaces: []
EOF
```
#### Create Subscription
We verify that the community certified operator CNPG is available
```
oc get packagemanifests -n openshift-marketplace | grep -i cloudnative-pg
```
Define what you want to install.
Take a look on channel to get the desired version
```
oc get packagemanifest cloudnative-pg \
  -n openshift-marketplace \
  -o jsonpath='{.status.channels[*].name}'
```
Or the default channel
```
oc get packagemanifest cloudnative-pg \
-n openshift-marketplace \
-o jsonpath='{.status.defaultChannel}'
```
Apply this manifest
```
CHANNEL=$(oc get packagemanifest cloudnative-pg -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cloudnative-pg
  namespace: cnpg-system
spec:
  name: cloudnative-pg
  channel: ${CHANNEL}
  source: certified-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
```
#### Check status
csv = Cluster Service Version representing the installed operator
```
oc get csv -n cnpg-system -w
```
Verify if SCC policy is really applied
```
oc -n <user-ns> get pod <pod> -o jsonpath='{.metadata.annotations.openshift\.io/scc}{"\n"}'
```
#### Test a deployment
Here is what we configure :
```
cnpg-system
   └── operator

team-a
   └── cluster postgres

team-b
   └── cluster postgres

team-c
   └── cluster postgres
```
Quick test
```
oc apply -f - <<'EOF'                             
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg1
  namespace: user-a
spec:
  instances: 1
  storage:
    size: 5Gi
EOF

```

#### Clean all 
```
oc -n cnpg-system delete subscription cloudnative-pg --ignore-not-found=true
oc -n cnpg-system delete csv --all --ignore-not-found=true
oc -n cnpg-system delete installplan --all --ignore-not-found=true

oc delete ns cnpg-system --ignore-not-found=true

oc get crd | grep 'postgresql.cnpg.io' | awk '{print $1}' | xargs -r oc delete crd

# For users namespaces do
oc delete ns user-a --ignore-not-found=true

oc get crd | grep 'postgresql.cnpg.io' || echo "OK: no more CRDs CNPG"
oc get ns | egrep 'cnpg-system|user-a' || echo "OK: namespaces deleted"
```

If you don't use OLM, here is a few commands to deploy CNPG Operator :
```bash
# Create namespace
oc create namespace cnpg-system
# Apply anyuid scc to cnpg-system
oc adm policy add-scc-to-group anyuid system:serviceaccounts:cnpg-system
# Patch anyuid rule
oc patch scc anyuid --type=merge -p '{
  "seccompProfiles": ["runtime/default","unconfined"],
  "defaultSeccompProfile": "runtime/default"
}'
# Deploy CNPG Operator
oc apply --server-side --force-conflicts -f \
https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.28/releases/cnpg-1.28.0.yaml 
```
If you need to restart the deployment
```bash
 oc -n cnpg-system rollout restart deploy cnpg-controller-manager
```

