# Fixing Eventstream issue for users in ICP4I

Box Folder Link to ifix: <https://ibm.ent.box.com/folder/96355482759>

## Add proper roles to User- `kube:admin` and login to docker

```bash
oc policy add-role-to-user registry-viewer kube:admin
oc adm policy add-cluster-role-to-user registry-viewer kube:admin
docker login $(oc registry info) -u kubeadmin -p $(oc whoami -t)

# try the following login if the prev one fails during docker push
docker login image-registry.openshift-image-registry.svc:5000 -u kubeadmin -p $(oc whoami -t)
```

## Load the tar.gz images

```Bash
docker load --input ./icp-identity-provider-tr-fix.tar.gz
docker load --input ./common-web-ui.tar.gz
docker load --input ./icp-identity-manager-ar-fix.tar.gz
docker load --input ./eventstreams-ifix.tar.gz

docker images #Note the Image name and TAG
```

The Loaded Images in my case were:

```bash
hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com/ibmcom/icp-identity-provider-amd64:727dfef
hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com/ibmcom/common-web-ui-amd64:1.1.0-e3cb15
hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com/ibmcom/icp-identity-manager-amd64:d11b984
```

My base domain name: `default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local`

## Tag the loaded images and push them to registry

**NOTE: might need to run portForward.sh** if authentication fails.

```bash
while true;
  do
    kubectl -n openshift-image-registry port-forward svc/image-registry 5000:5000;
  done
```

```bash
## docker tag <old image name:TAG> <new image name:TAG>
docker tag  hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com/ibmcom/icp-identity-provider-amd64:727dfef  default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local/kube-system/icp-identity-provider-amd64:727dfef
docker tag  hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com/ibmcom/common-web-ui-amd64:1.1.0-e3cb15     default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local:5000/kube-system/common-web-ui-amd64:1.1.0-e3cb15
docker tag  hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com/ibmcom/icp-identity-manager-amd64:d11b984   default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local:5000/kube-system/icp-identity-manager-amd64:d11b984
docker tag  mycluster.icp:8500/es/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix                 image-registry.openshift-image-registry.svc:5000/eventstreams/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix

# Probably don't need this
docker tag  mycluster.icp:8500/es/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix                 default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local/eventstreams/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix

docker push default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local:5000/kube-system/icp-identity-provider-amd64:727dfef
docker push default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local/kube-system/common-web-ui-amd64:1.1.0-e3cb15
docker push default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local/kube-system/icp-identity-manager-amd64:d11b984
docker push image-registry.openshift-image-registry.svc:5000/eventstreams/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix

# probably don't need it
docker push default-route-openshift-image-registry.apps.res-cp4i.ocp.csplab.local/eventstreams/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix
```

## In progress

```bash
oc project eventstreams
oc get deployment

deployer-dockercfg-ptgfs
oc get is
oc get is -n kube-system
oc project
oc project kube-system
oc get deamonset
oc get daemonset
sudo docker images
oc get secrets
oc get secrets | grep deployer
oc edit daemonset common-web-ui
exit
```

```bash
oc edit deployment es1-ibm-es-access-controller-deploy
```

Search for `/image:` and look for the values with `access-control`
Replace the image field value in with `image-registry.openshift-image-registry.svc:5000/eventstreams/eventstreams-access-controller-ce-icp-linux-amd64:2019-12-17.30.00-ifix`

Run the command. fingers crossed and hope everything works. Otherwise ping rengan lol

```bash
watch oc get pods
```

## Future

Setting up IAM for login: <https://www.ibm.com/support/knowledgecenter/SSTPTP_1.6.0/com.ibm.netcool_ops.doc/csd/installer/3.2.2/config_yaml.html>

```yml
roks_enabled: true
roks_url: https://c100-e.us-east.containers.cloud.ibm.com:3xxx
```

kube-system

Ask:

* How to get Red Hat Subscription
