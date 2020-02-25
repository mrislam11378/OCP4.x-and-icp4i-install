# Install Cloud Pak for Integration on Openshift 4.2 - Offline <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

- [Setting the max_map_count](#setting-the-max_map_count)
- [Download and extract the image](#download-and-extract-the-image)
- [Creating config.yaml](#creating-configyaml)
- [Creating getAllRec.sh](#creating-getallrecsh)
- [Starting the install process](#starting-the-install-process)

## Setting the max_map_count

SSH into all your worker and storage nodes and set the max_map_count to 262144.

**Note:** To ssh into worker and storage nodes, you need `ssh core@[IP/dnsname]`

```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

## Download and extract the image

SSH into your installer node. Go to `/opt` dir and download the image there. To download the image from IBM XL, use this <https://w3-03.ibm.com/software/xl/download/ticket.wss>. But as CP4I 2019.4.1 is already downloaded on the csplab jump server, we'll `wget` from there as it's much faster.

```bash
cd /opt
wget http://storage4.csplab.local/storage/cp4i/ibm-cp-int-2019.4.1-offline.tar.gz
mkdir cp4ioffline
tar xf ibm-cp-int-2019.4.1-offline.tar.gz --directory /opt/cp4ioffline
cd cp4ioffline/installer_files
tree
tar xvf installer_files/cluster/images/common-services-armonk-x86_64.tar.gz -O | sudo docker load
```

## Creating config.yaml

Create a backup of the default `config.yaml` inside of `/opt/cp4ioffline/installer_files/cluster` and paste in the following configs.

```yaml
# Licensed Materials - Property of IBM
# IBM Cloud Pak for Integration
# @ Copyright IBM Corp. 2019 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
---
# Nodes selected to run common services components.
#
# The value of the master, proxy, and management parameters is an array,
# by providing multiple nodes the common services will be configured in
# a high availability configuration.
#
# It is recommended to install the components onto one or more openshift
# worker nodes. The master, proxy, and management components can all share
# the same node or set of nodes.
cluster_nodes:
  master:
    - compute4
  proxy:
    - compute5
  management:
    - compute6
# This storage class is used to store persistent data for the common services
# components
storage_class: rook-ceph-block
## You can set a different storage class for storing log data.
## By default it will use the value of storage_class.
# elasticsearch_storage_class:
default_admin_password: admin
password_rules:
  - '(.*)'
# default_admin_password:
# password_rules:
#   - '^([a-zA-Z0-9\-]{32,})$'
management_services:
  # Common services
  iam-policy-controller: enabled
  metering: enabled
  licensing: disabled
  monitoring: enabled
  nginx-ingress: enabled
  common-web-ui: enabled
  catalog-ui: enabled
  mcm-kui: enabled
  logging: enabled
  audit-logging: disabled
  system-healthcheck-service: disabled
  multitenancy-enforcement: disabled
  configmap-watcher: disabled
roks_enabled: true
roks_url: <oauth route for your cluster>
roks_user_prefix: ""
# This section installs the IBM Cloud Pak for Integration Platform Navigator
# and loads the product charts into the cluster. The navigator will be
# available after installation at:
# https://ibm-icp4i-prod-integration.<openshift apps domain>/
archive_addons:
  icp4i:
    namespace: integration
    repo: local-charts
    path: icp4icontent/IBM-Cloud-Pak-for-Integration-3.0.0.tgz
    charts:
      - name: ibm-icp4i-prod
        values: {}
  mq:
    namespace: mq
    repo: local-charts
    path: icp4icontent/IBM-MQ-Advanced-for-IBM-Cloud-Pak-for-Integration-5.0.0.tgz
  ace:
    namespace: ace
    repo: local-charts
    path: icp4icontent/IBM-App-Connect-Enterprise-for-IBM-Cloud-Pak-for-Integration-3.0.0.tgz
  eventstreams:
    namespace: eventstreams
    repo: local-charts
    path: icp4icontent/IBM-Event-Streams-for-IBM-Cloud-Pak-for-Integration-1.4.0.tgz
  apic:
    namespace: apic
    repo: local-charts
    path: icp4icontent/IBM-API-Connect-Enterprise-for-IBM-Cloud-Pak-for-Integration-1.0.4.tgz
  aspera:
    namespace: aspera
    repo: local-charts
    path: icp4icontent/IBM-Aspera-High-Speed-Transfer-Server-for-IBM-Cloud-Pak-for-Integration-1.2.4.tgz
  datapower:
    namespace: datapower
    repo: local-charts
    path: icp4icontent/IBM-DataPower-Virtual-Edition-for-IBM-Cloud-Pak-for-Integration-1.0.5.tgz
  assetrepo:
    namespace: integration
    repo: local-charts
    path: icp4icontent/IBM-Cloud-Pak-for-Integration-Asset-Repository-3.0.0.tgz
  tracing:
    namespace: tracing
    repo: local-charts
    path: icp4icontent/IBM-Cloud-Pak-for-Integration-Operations-Dashboard-1.0.1.tgz
```

To find out your oauth route run the following

```bash
$ oc get routes --all-namespaces | grep oauth
openshift-authentication   oauth-openshift     oauth-openshift.apps.mislam.ocp.csplab.local
```

And paste in your oauth route in the following part of your `config.yaml`:

```yaml
roks_enabled: true
roks_url: https://oauth-openshift.apps.mnb.ocp.csplab.local -> your oauth route
roks_user_prefix: ""
```

## Creating getAllRec.sh

When the installer fails, this script will echo all the pods that are up and running and pods that are failing.

```bash
cd /opt
touch getAllRec.sh
sudo chmod 755 getAllRec.sh
./getAllRec.sh kube-system
```

getAllRec.sh file

```bash
#!/bin/bash
PROJECT=$1
echo -------------------------------------
echo POD
oc get -n $PROJECT Pod
echo -------------------------------------
echo PVC
oc get -n $PROJECT pvc
echo -------------------------------------
echo SERVICE
oc get -n $PROJECT Service
echo -------------------------------------
echo STATEFULSET
oc get -n $PROJECT StatefulSet
echo -------------------------------------
echo DAMEONSET
oc get -n $PROJECT DaemonSet
echo -------------------------------------
echo DEPLOYMENT
oc get -n $PROJECT Deployment
echo -------------------------------------
echo REPLICASET
oc get -n $PROJECT replicaset
echo -------------------------------------
echo IMAGESTREAM
oc get -n $PROJECT imagestream
echo -------------------------------------
echo ROUTE
oc get -n $PROJECT route
echo -------------------------------------
echo CONFIGMAP
oc get -n $PROJECT ConfigMap
echo -------------------------------------
echo CLIENT
oc get -n $PROJECT Client
echo -------------------------------------
echo JOB
oc get -n $PROJECT Job
echo -------------------------------------
echo SERVICEACCOUNT
oc get -n $PROJECT ServiceAccount
echo -------------------------------------
echo ROLEBINDING
oc get -n $PROJECT RoleBinding
echo -------------------------------------
echo ROLE
oc get -n $PROJECT Role
echo -------------------------------------
echo PODDISRUPTIONBUDGET
oc get -n $PROJECT PodDisruptionBudget
echo -------------------------------------
echo CLUSTERROLEBINDING
#oc get -n $PROJECT ClusterRoleBinding
echo -------------------------------------
echo INGRESS
oc get -n $PROJECT Ingress
echo -------------------------------------
echo MONITORINGDASHBOARD
oc get -n $PROJECT MonitoringDashboard
echo -------------------------------------
echo SECRET
oc get -n $PROJECT secret

```

## Starting the install process

Might fail waiting for pods to come up, retry on failure.

```bash
cd /opt/cp4ioffline/installer_files/cluster
oc config view > kubeconfig
nohup sudo docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z -v /etc/docker:/etc/docker:z --security-opt label:disable ibmcom/icp-inception-amd64:3.2.2 addon -vvv | tee install.log &
```
