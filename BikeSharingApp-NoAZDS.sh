RAND=$(shuf -i 1-99 -n 1)
 
RGNAME=k8s
AKSNAME=BikeSharing${RAND}
BIKEAPPNS=bikeapp
INGRESSNAME=bikesharing-traefik
LOC=eastus
SUBSCRIPTION=$(az account show --query 'id' -o tsv)
 
echo "Check helm version, ensure it's v3.x"
helm version --short
 
echo "Creating ${RGNAME} resource group"
az group create --name $RGNAME  --location $LOC




# echo "Creating service principal"
# SERVICE_PRINCIPAL=$(az ad sp create-for-rbac \
#  --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$RGNAME \
#  --role Contributor \
#  --output json)

# AKS_SP_ID=$(echo $SERVICE_PRINCIPAL | jq -r '.appId')
# AKS_SP_PASS=$(echo $SERVICE_PRINCIPAL | jq -r '.password')

echo "Creating ${AKSNAME} AKS Cluster"
az aks create \
  -g $RGNAME \
  -n $AKSNAME \
  --location $LOC \
  --generate-ssh-keys #\
  #--service-principal $AKS_SP_ID \
  #--client-secret $AKS_SP_PASS 
 
echo "Setting the Kube context"
az aks get-credentials -g $RGNAME -n $AKSNAME
 
PUBLICIP=$(az network public-ip create --resource-group $RGNAME --name BikeSharingPip${RAND} --sku Standard --allocation-method static --query publicIp.ipAddress -o tsv)
echo "BikeSharing ingress Public ip: " $PUBLICIP

echo "Assigning the AKS Service Principal, RBAC access to the being a Network Contributor"
SPID=$(az aks show -n ${AKSNAME} -g ${RGNAME} --query servicePrincipalProfile.clientId -o tsv)
if [[ "${SPID}" == "msi" ]]; then
   # Managed identity cluster
   SPID=$(az aks show -n ${AKSNAME} -g ${RGNAME} --query identity.principalId -o tsv)
fi
az role assignment create --assignee ${SPID} --scope "/subscriptions/${SUBSCRIPTION}/resourceGroups/${RGNAME}" --role "Network Contributor"
 
echo "Create namespace ${INGRESSNAME}"
kubectl create namespace $INGRESSNAME
 
# Use Helm to deploy a traefik ingress controller
echo "helm repo add && helm repo update"
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update
echo "helm install traefik ingress controller"
helm install $INGRESSNAME stable/traefik \
    --namespace $INGRESSNAME \
    --set kubernetes.ingressClass=traefik \
    --set fullnameOverride=$INGRESSNAME \
    --set rbac.enabled=true \
    --set service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-resource-group"="$RGNAME" \
    --set loadBalancerIP=$PUBLICIP \
    --set kubernetes.ingressEndpoint.useDefaultPublishedService=true \
    --version 1.85.0
 
mkdir $AKSNAME
cd $AKSNAME
echo "The current working directory: $PWD"
 
echo "Cloning Dev-Spaces repo"
git clone https://github.com/Microsoft/Mindaro
cd dev-spaces/samples/BikeSharingApp/
 
NIPIOFQDN=${PUBLICIP}.nip.io
echo "The Nip.IO FQDN would be " $NIPIOFQDN
 
cd charts/
echo "---"
echo "The current working directory: $PWD"
 
echo "Create namespace bikeapp"
kubectl create ns bikeapp

echo "Replacing ingress controller annotation in values.yaml"
sed -i "" "s/traefik-azds/traefik/g" values.yaml

echo "helm install bikesharingapp"
helm install bikesharingapp $PWD \
      --set bikesharingweb.ingress.hosts={$BIKEAPPNS.bikesharingweb.${NIPIOFQDN}} \
      --set gateway.ingress.hosts={$BIKEAPPNS.gateway.${NIPIOFQDN}} \
      --dependency-update \
      --namespace $BIKEAPPNS \
      --atomic
