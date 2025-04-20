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
Kind : 1 Control plane and 3 Worker nodes  
CNPG : 1 Operator managing rw, r, ro postgresql instances (v16)  
Minio : Backups  
Client : Pod based on postgres:16 image deployed on the control-plane for tests purpose

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
