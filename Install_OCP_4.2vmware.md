# Creating OpenShift 4.2 Cluster in VMWare <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

- [Introduction](#introduction)
- [Reference Material and Links](#reference-material-and-links)
- [Recommendations](#recommendations)
- [Configuration](#configuration)
- [Setting up Install Node](#setting-up-install-node)
- [Scaling up Nodes](#scaling-up-nodes)
- [Scaling out Cluster (Adding worker nodes)](#scaling-out-cluster-adding-worker-nodes)
- [Command History](#command-history)

## Introduction

This document shows step by step guide for installing [OpenShift 4.2](<https://docs.openshift.com/>
container-platform/4.2/welcome/index.html) on csplab environment should not be used as a generic
guide. It does not explain the material, rather just a step by step guide as I follow the sources
cited below.

## Reference Material and Links

- <https://github.com/ibm-cloud-architecture/refarch-privatecloud/blob/master/Install_OCP_4.x.md>
- <https://docs.openshift.com/container-platform/4.2/installing/installing_vsphere/installing-vsphere.html>
- OCP Client mirror: <https://mirror.openshift.com/pub/openshift-v4/clients/ocp/>

## Recommendations

Below are some recommendations that should be followed.

- Create all the VMs in vSphere and note the mac addresses.
- The VM "Network Adapter" should be assigned to ocp
- Thin Provision hard disks except the install node.
- Have IP addresses assigned to each of the vm (DNS & DHCP already configured)
- Only turn on the install node, check if proper IP address is assigned
  - Is the mac address correct?
  - Is the Network adapter set to OCP
  - Was there anything wrong with configuring DNS and DHCP server (Talk with [Alec](https://ibm-cloud.slack.com/team/WCBLF8SRZ) or [Victor](https://ibm-cloud.slack.com/team/W3H1D4WAV))
- Ability to SSH into the install node as admin. (TODO: is it safe to update and upgrade install node)

## Configuration

**Node Type**|**Number of Nodes**|**CPU**|**RAM**|**DISK**|**DISK2**
:-----:|:-----:|:-----:|:-----:|:-----:|:-----:
Master|3|16|64|300|
Worker|8|4|16|200|
Storage|3|4|16|200|500
Bootstrap|1|4|16|100|
Install|1|4|16|200|
LB|1|4|16|120|
NFS|1|2|8|500|

**Note:** For installing could pak the workers might need to be scaled up. Common Configs:
**CPAK**|**Number of Worker**|**CPU**|**RAM**|**DISK**|**DISK2**
:-----:|:-----:|:-----:|:-----:|:-----:|:-----:
CP4I|8|16|64|200|
CP4A|8| | | |
CP4Auto|8| | | |
CP4MCM|8| | | |
CP4D|8| | | |

## Setting up Install Node

1. ssh into the Install Node. You need root access to complete most of the steps so ensure that's possible
2. Create a directory for your new cluster.  In this document I will use a cluster named after my userid `mislam`.
    ```
    mkdir /opt/mislam
    ```
3. Check if `apache2` is installed and running and if not install it.
    ```bash
    sudo apt install apache2
    systemctl status apache2
    ```
4. This will create a document root of /var/www/html.  Create a softlink from the document root to your project directory.
    ```
    ln -s /opt/mislam /var/www/html/
    ```
5. Download the OpenShift client and installer.
    ```
    cd /opt
    wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.16/openshift-client-linux-4.2.16.tar.gz
    wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.16/openshift-install-linux-4.2.16.tar.gz
    ```
6. asdlkjfhkjdh
7. alksdjhga
8. ladhfka
9.  iuqyet


## Scaling up Nodes

## Scaling out Cluster (Adding worker nodes)

## Command History

```bash
mkdir /opt/mislam
ls /var/www/html/
sudo apt install apache2
systemctl status apache2
sudo ln -s /opt/mislam/ /var/www/html/
ls -lha
cd /opt
wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.16/openshift-client-linux-4.2.16.tar.gz
wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.16/openshift-install-linux-4.2.16.tar.gz

```
