# Creating OpenShift 4.2 Cluster in VMWare <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

- [Introduction](#introduction)
- [Reference Material and Links](#reference-material-and-links)
- [Recommendations](#recommendations)
- [Common mistakes](#common-mistakes)
- [Cluster Configuration](#cluster-configuration)
- [Setting up Install Node](#setting-up-install-node)
- [Setting up Load Balancer](#setting-up-load-balancer)
- [Scaling up Nodes](#scaling-up-nodes)
- [Scaling out Cluster (Adding worker nodes)](#scaling-out-cluster-adding-worker-nodes)
- [Appendix](#appendix)
  - [[A] Command History](#a-command-history)
    - [Install node](#install-node)
    - [Load Balancer](#load-balancer)
  - [[B] install-config.yaml for vmware cluster](#b-install-configyaml-for-vmware-cluster)
  - [[C] append-bootstrap.ign for vmware cluster](#c-append-bootstrapign-for-vmware-cluster)
  - [[D] haproxy.conf for vmware cluster](#d-haproxyconf-for-vmware-cluster)
- [FAQ](#faq)

## Introduction

This document shows step by step guide for installing [OpenShift 4.2](https://docs.openshift.com/container-platform/4.2/welcome/index.html) on csplab environment should not be used as a generic
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
- Only turn on the install node and load balancer until all the configs are done, check if proper IP address is assigned. If not
  - Is the mac address correct?
  - Is the Network adapter set to OCP (Common mistake)
  - Was there anything wrong with configuring DNS and DHCP server (Talk with [Alec](https://ibm-cloud.slack.com/team/WCBLF8SRZ) or [Victor](https://ibm-cloud.slack.com/team/W3H1D4WAV))
- Ability to SSH into the install node as admin. Although it is possible to use the Web Console in vSphere, I **strongly** recommend using ssh unless someone wants to type a lot as Web Console doesn't support copy-paste

## Common mistakes

- The resource pool, folder name in vSphere and route base (xx.$USER.ocp.csplab.local), the user folder inside /opt MUST match
- Anywhere you see a [square brackets], replace the contents along with the brackets and paste in your content
- Do not turn on the master, worker, storage nodes untill all the configs will done in the install node and load balancer.

## Cluster Configuration

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

Use `ocp42-installer-template` as template. It should exist in `CSPLAB->SANDBOX->FastStart2020Templates` but the location might change in the future.

1. ssh into the Install Node. You need root access to complete most of the steps so ensure that's possible.

    ```bash
    ssh sysadmin@[IP address of installer]
    ```

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
**NOTE: Replace anything in [square brackets] with your values**
  
    <details> <summary> Show install-config.yaml </summary>
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
    </details>
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

    <details> <summary> Show append-bootstrap.ign </summary>
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
    </details>

16. In your project directory (`/opt/mislam`), encode `master.ign`, `worker.ign`, and `append-bootstrap.ign` into base64 strings.

    ```bash
    cd /opt/mislam
    base64 -w0 append-bootstrap.ign > append-bootstrap.base64
    base64 -w0 master.ign > master.base64
    base64 -w0 worker.ign > worker.base64
    ```

17. Now login to vSphere, go to your cluster, select your bootstrap node. Then Configure -> Settings -> vApp Options -> Properties. </br>
    ![vApp Options](images/setIgnConfigData.png) </br>

18. You will have two properties one labeled `Ignition config data encoding` and one labeled `Ignition config data`. Select the property labeled `Ignition config data encoding` and click `Set Value` at the top of the table. In the blank, put base64 and click OK.
    On your installation machine cat the text of append-bootstrap.b64 file to the screen:
  
    ```bash
    cat append-bootstrap.base64
    ```

19. Copy the output from this file. Back in the vSphere web client, select the property labeled `Ignition config data` and click `Set Value` at the top of the table. Paste the base64 string in your clipboard into this blank and click OK.
20. Repeat these steps for each node in your cluster. For the `master/control nodes` use the `master.base64` ignition file and for the `compute/worker nodes` use the `worker.base64` text.

Now you have set up your install node. But before moving on some packages should be installed for future steps.

```bash
sudo apt update
sudo apt install jq nmap
```

## Setting up Load Balancer

Use `ocp42-lb-template` as template. Same location as the installer template. We will only configure 1 load balancer but in production environment it is strongly recommended to have 2. Also ensure you have gotten assigned ip addresses for each of your nodes before progressing as they will be necessary.

1. In vSphere, turn on the load balancer. Then from the install node, ssh into the load balancer.

   ```bash
   ssh sysadmin@[ip address of load balancer]
   ```

2. Install `haproxy` package

   ```bash
   sudo apt install haproxy
   ```

3. Now copy and paste the following settings for haproxy.cfg and insert the correct values for any `<brackets>`. Although I recommend inserting the values first and then copying. Also it's a good idea to backup the default haproxy.cfg

   ```bash
   sudo cp haproxy.cfg haproxy.cfg.bak
   sudo vim /etc/haproxy/haproxy.cfg
   ```

    <details>
      <summary>Show haproxy.conf</summary>

      ```bash
      global
          log /dev/log    local0
          log /dev/log    local1 notice
          chroot /var/lib/haproxy
          stats socket /run/haproxy/admin.sock mode 660 level admin
          stats timeout 30s
          user haproxy
          group haproxy
          daemon
          # Default SSL material locations
          ca-base /etc/ssl/certs
          crt-base /etc/ssl/private
          # Default ciphers to use on SSL-enabled listening sockets.
          # For more information, see ciphers(1SSL). This list is from:
          #  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
      #   ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
      #   ssl-default-bind-options no-sslv3
          ssl-default-bind-ciphers PROFILE=SYSTEM
          ssl-default-server-ciphers PROFILE=SYSTEM
      defaults
          log global
          mode    http
          option  httplog
          option  dontlognull
          retries 3
              timeout http-request  10s
              timeout queue  1m
              timeout connect 10s
              timeout client  1m
              timeout server  1m
              timeout http-keep-alive  10s
              timeout check  10s
          maxconn 3000
      frontend api
          bind *:6443
          mode tcp
          default_backend     api
      frontend machine-config
          bind *:22623
          mode tcp
          default_backend     machine-config
      frontend http
          bind *:80
          mode http
          default_backend     http
      frontend https
          bind *:443
          mode tcp
          default_backend https
      backend api
          mode tcp
          balance roundrobin
          server bootstrap       <IP Address>:6443 check
          server control-plane-0 <IP Address>:6443 check
          server control-plane-1 <IP Address>:6443 check
          server control-plane-2 <IP Address>:6443 check
      backend machine-config
          mode tcp
          balance roundrobin
          server bootstrap       <IP address>:22623 check
          server control-plane-0 <IP address>:22623 check
          server control-plane-1 <IP address>:22623 check
          server control-plane-2 <IP address>:22623 check
      backend http
          balance roundrobin
          mode    http
          server  compute-0 <IP address>:80 check
          server  compute-1 <IP address>:80 check
          server  compute-2 <IP address>:80 check
          server  compute-3 <IP address>:80 check
          server  compute-4 <IP address>:80 check
          server  compute-5 <IP address>:80 check
          server  compute-6 <IP address>:80 check
          server  compute-7 <IP address>:80 check
          server  storage-0 <IP address>:80 check
          server  storage-1 <IP address>:80 check
          server  storage-2 <IP address>:80 check
      backend https
          balance roundrobin
          mode tcp
          server  compute-0 <IP Address>:443 check
          server  compute-1 <IP Address>:443 check
          server  compute-2 <IP Address>:443 check
          server  compute-3 <IP Address>:443 check
          server  compute-4 <IP Address>:443 check
          server  compute-5 <IP Address>:443 check
          server  compute-6 <IP Address>:443 check
          server  compute-7 <IP Address>:443 check
          server  storage-0 <IP Address>:443 check
          server  storage-1 <IP Address>:443 check
          server  storage-2 <IP Address>:443 check
      ```
  
    </details>

4. Now start `haproxy`. Also should do `systemctl enable haproxy` so that it starts up everytime the load balancer restarts.

    ```bash
    sudo systemctl start haproxy  #if already running, try systemctl restart. To check status, do systemctl status
    sudo systemctl enable haproxy
    ```

That's it. Load Balancer in configured.

## Scaling up Nodes

## Scaling out Cluster (Adding worker nodes)

## Appendix

### [A] Command History

#### Install node

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
cp append-bootstrap.ign mislam/append-bootstrap.ign
cd /opt/mislam
base64 -w0 append-bootstrap.ign > append-bootstrap.base64
base64 -w0 master.ign > master.base64
base64 -w0 worker.ign > worker.base64


export KUBECONFIG=/opt/mislam/auth/kubeconfig
```

#### Load Balancer

```bash
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

### [D] haproxy.conf for vmware cluster

```bash
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    # Default ciphers to use on SSL-enabled listening sockets.
    # For more information, see ciphers(1SSL). This list is from:
    #  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
#   ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
#   ssl-default-bind-options no-sslv3
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM
defaults
    log global
    mode    http
    option  httplog
    option  dontlognull
    retries 3
        timeout http-request  10s
        timeout queue  1m
        timeout connect 10s
        timeout client  1m
        timeout server  1m
        timeout http-keep-alive  10s
        timeout check  10s
    maxconn 3000
frontend api
    bind *:6443
    mode tcp
    default_backend     api
frontend machine-config
    bind *:22623
    mode tcp
    default_backend     machine-config
frontend http
    bind *:80
    mode http
    default_backend     http
frontend https
    bind *:443
    mode tcp
    default_backend https
backend api
    mode tcp
    balance roundrobin
    server bootstrap       <IP Address>:6443 check
    server control-plane-0 <IP Address>:6443 check
    server control-plane-1 <IP Address>:6443 check
    server control-plane-2 <IP Address>:6443 check
backend machine-config
    mode tcp
    balance roundrobin
    server bootstrap       <IP address>:22623 check
    server control-plane-0 <IP address>:22623 check
    server control-plane-1 <IP address>:22623 check
    server control-plane-2 <IP address>:22623 check
backend http
    balance roundrobin
    mode    http
    server  compute-0 <IP address>:80 check
    server  compute-1 <IP address>:80 check
    server  compute-2 <IP address>:80 check
    server  compute-3 <IP address>:80 check
    server  compute-4 <IP address>:80 check
    server  compute-5 <IP address>:80 check
    server  compute-6 <IP address>:80 check
    server  compute-7 <IP address>:80 check
    server  storage-0 <IP address>:80 check
    server  storage-1 <IP address>:80 check
    server  storage-2 <IP address>:80 check
backend https
    balance roundrobin
    mode tcp
    server  compute-0 <IP Address>:443 check
    server  compute-1 <IP Address>:443 check
    server  compute-2 <IP Address>:443 check
    server  compute-3 <IP Address>:443 check
    server  compute-4 <IP Address>:443 check
    server  compute-5 <IP Address>:443 check
    server  compute-6 <IP Address>:443 check
    server  compute-7 <IP Address>:443 check
    server  storage-0 <IP Address>:443 check
    server  storage-1 <IP Address>:443 check
    server  storage-2 <IP Address>:443 check
```

## FAQ

- Why are the correct IP addresses not being assigned to my nodes?
**Ans:** You might've assigned a wrong network adapter in your vms. Make sure the network adapter is `OCP` and not `csplab`

- Why is the source url inside append-bootstrap.ign `/mislam/bootstrap.ign` instead of `/opt/mislam/bootstrap.ign` in the url?
**Ans:** Well, in an earlier step you created a softlink from the document root (`/var/www/html`) to your project directory (`/opt/mislam`) after ensuring httpd server (apache2) is installed and running. So when you have an httpd server running in linux, only the contents inside `/var/www/html` are accessible using the ip where our softlink to `/opt/mislam` is located. httpd does it so that any random unauthorized person doesn't get access to the entire file system but only what's public i.e. things inside `/www/html`. Refer to [Victor's Guide](https://github.com/ibm-cloud-architecture/refarch-privatecloud/blob/master/Install_OCP_4.x.md) for more details.
