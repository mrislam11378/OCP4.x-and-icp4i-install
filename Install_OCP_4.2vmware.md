# Creating OpenShift 4.2 Cluster in VMWare <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

- [Introduction](#introduction)
- [Reference Material and Links](#reference-material-and-links)
- [Recommendations](#recommendations)
- [Configuration](#configuration)
- [Setting up Install Node](#setting-up-install-node)
- [Scaling up Nodes](#scaling-up-nodes)
- [Scaling out Cluster (Adding worker nodes)](#scaling-out-cluster-adding-worker-nodes)
- [Appendix](#appendix)
  - [[A] Command History](#a-command-history)
  - [[B] install-config.yaml for vmware cluster](#b-install-configyaml-for-vmware-cluster)
  - [[C] append-bootstrap.ign for vmware cluster](#c-append-bootstrapign-for-vmware-cluster)
- [FAQ](#faq)

## Introduction

This document shows step by step guide for installing [OpenShift 4.2](https://docs.openshift.com/container-platform/4.2/welcome/index.html) on csplab environment should not be used as a generic
guide. It does not explain the material, rather just a step by step guide as I follow the sources
cited below.
**NOTE: The resource pool, folder name in vSphere and route base (xx.$USER.ocp.csplab.local), the user folder inside /opt MUST match**

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

    ```bash
    mkdir /opt/mislam
    ```

3. Check if `apache2` is installed and running and if not install it.

    ```bash
    sudo apt install apache2
    systemctl status apache2
    ```

4. This will create a document root of `/var/www/html`.  Create a softlink from the document root to your project directory.

    ```bash
    ln -s /opt/mislam /var/www/html/
    ```

5. Download the OpenShift client and installer.

    ```bash
    cd /opt
    wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.16/openshift-client-linux-4.2.16.tar.gz
    wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.16/openshift-install-linux-4.2.16.tar.gz
    ```

6. Explode the files into `/opt`

    ```bash
    gunzip -c openshift-client-linux-4.2.16.tar.gz |tar -xvf -
    gunzip -c openshift-install-linux-4.2.16.tar.gz |tar -xvf -
    ```

7. Now copy the `oc` and `kubectl` binaries into your path

    ```bash
    sudo cp oc /usr/local/bin/
    sudo cp kubectl /usr/local/bin/
    ```

8. Create an ssh key for your primary user. Accept the default location for the file.

   ```bash
   ssh-keygen -t rsa -b 4096 -N ''
   ```

9. Start the ssh agent

    ```bash
    eval "$(ssh-agent -s )"
    ```

10. Add your private key to the ssh-agent

    ```bash
    ssh-add ~/.ssh/id_rsa
    ```

11. You will need a pull secret so your cluster can download the needed containers. Get your pull secret from <https://cloud.redhat.com/openshift/install/vsphere/user-provisioned> and put it into a file in your `/opt` directory (e.g. pull-secret.txt). You will need this in the next step. Go to the link, login with your ibm account, scroll down to pull secret, copy that to clipboard and save it in `/opt/pull-secret.txt`

    ```bash
    vim pull-secret.txt #press `i` to goto insert mode, `cmd+v` to paste, `esc` to exit insert mode and `:wq` to save and quit
    ```

12. In your project directory (`/opt/mislam`), create a file named `install-config.yaml` and paste the following configs.

    ```bash
    apiVersion: v1
    baseDomain: ocp.csplab.local
    compute:
    - hyperthreading: Enabled
    name: worker
    replicas: 0
    controlPlane:
    hyperthreading: Enabled
    name: master
    replicas: 3
    metadata:
    name: [name of your cluster] # in my case mislam as I create /mislam inside of /opt
    platform:
    vsphere:
        vcenter: demo-vcenter.csplab.local
        username: [Muhammad.Islam] # my vSphere username i.e. the login used for vSphere
        password: [********] # your password
        datacenter: CSPLAB
        defaultDatastore: SANDBOX_TIER4
    pullSecret: '[your pull secret. Dont forget the single quotes]'
    sshKey: '[your public ssh-key from ~/.ssh/id-rsa.pub. Dont forget the single quotes]'
    ```

**NOTE:** It is recommended to make a backup of the `install-config.yaml` file as it will be deleted during manifests creation. I create the backup in the /opt directory rather than the project directory but feel free to have it somewhere else.

```bash
    cp install-config.yaml /opt/install-config.yaml.bak
```

13. Now it's time to create your manifest files. Go back to `/opt` dir and run the following command. This will create the manifest files inside your project directory (`/mislam` for me). Make sure to **backup** your `install-config.yaml` before creating your manifests if you want to save the config.

    ```bash
    cd /opt
    ./openshift-install create manifests --dir=./mislam  # replace --dir=[contents] with your project dir
    ```

14. Now we will create the ignition files. Run the following command from `/opt`. This will **consume** all your manifests file so you might want to create backups.

    ```bash
    ./openshift-install create ignition-configs --dir=./mislam # replace --dir=[contents] with your project dir
    ```

This will create `bootstrap.ign`, `master.ign`, `worker.ign`, `/auth` and `metadata.json` inside your project directory.

15. In your project folder (`/opt/mislam`), create a new file named `append-bootstrap.ign` and paste the following contents.
**NOTE: Replace anything in [square brackets] with your values**

    ```bash
    {
    "ignition": {
        "config": {
        "append": [
            {
            "source": "[http://172.18.6.67/mislam/bootstrap.ign]",
            "verification": {}
            }
        ]
        },
        "timeouts": {},
        "version": "2.1.0"
    },
    "networkd": {},
    "passwd": {},
    "storage": {},
    "systemd": {}
    }
    ```

16. new piont.
17. asd.
18. poasdf.
19. new point.

## Scaling up Nodes

## Scaling out Cluster (Adding worker nodes)

## Appendix

### [A] Command History

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
gunzip -c openshift-client-linux-4.2.16.tar.gz | tar -xvf -
gunzip -c openshift-install-linux-4.2.16.tar.gz | tar -xvf -
sudo cp oc /usr/local/bin/
sudo cp kubectl /usr/local/bin/
ssh-keygen -t rsa -b 4096 -N ''
ls ~/.ssh/
eval "$(ssh-agent -s )"
ssh-add ~/.ssh/id_rsa
vim pull-secret.txt #Paste your pull secret
cd /opt/mislam
vim install-config.yaml #Paste the vmware configs
cp install-config.yaml /opt/install-config.yaml.bak
cd /opt
./openshift-install create manifests --dir=./mislam  # replace --dir=[contents] with your project dir
./openshift-install create ignition-configs --dir=./mislam # replace --dir=[contents] with your project dir
vim append-bootstrap.ign #Paste the append-bootstrap.ign config
```

### [B] install-config.yaml for vmware cluster

```bash
apiVersion: v1
baseDomain: ocp.csplab.local
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: [name of your cluster] # in my case mislam as I create /mislam inside of /opt
platform:
  vsphere:
    vcenter: demo-vcenter.csplab.local
    username: [Muhammad.Islam] # my vSphere username i.e. the login used for vSphere
    password: [********] # your password
    datacenter: CSPLAB
    defaultDatastore: SANDBOX_TIER4
pullSecret: '[your pull secret. Dont forget the single quotes]'
sshKey: '[your public ssh-key from ~/.ssh/id-rsa.pub. Dont forget the single quotes]'
```

**Note**: Goto <https://github.com/ibm-cloud-architecture/refarch-privatecloud/blob/master/Install_OCP_4.x.md#create-the-installation-server> for proper explanation of each field

### [C] append-bootstrap.ign for vmware cluster

**Note:** Replace the contents inside square brackets with the URL to your bootstrap.ign. (In my case it's `http://172.18.6.67/mislam/bootstrap.ign`).

```bash
{
  "ignition": {
    "config": {
      "append": [
        {
          "source": "[http://172.18.6.67/mislam/bootstrap.ign]",
          "verification": {}
        }
      ]
    },
    "timeouts": {},
    "version": "2.1.0"
  },
  "networkd": {},
  "passwd": {},
  "storage": {},
  "systemd": {}
}
```

## FAQ

1. Why is the source url inside append-bootstrap.ign `/mislam/bootstrap.ign` instead of `/opt/mislam/bootstrap.ign` in the url?
**Ans:** Well, in an earlier step you created a softlink from the document root (`/var/www/html`) to your project directory (`/opt/mislam`) after ensuring httpd server (apache2) is installed and running. So when you have an httpd server running in linux, only the contents inside `/var/www/html` are accessible using the ip where our softlink to `/opt/mislam` is located. httpd does it so that any random unauthorized person doesn't get access to the entire file system but only what's public i.e. things inside `/www/html`. Refer to [Victor's Guide](https://github.com/ibm-cloud-architecture/refarch-privatecloud/blob/master/Install_OCP_4.x.md) for more details.
