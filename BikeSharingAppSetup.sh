RAND=$(shuf -i 1-99 -n 1)

RGNAME=k8s
AKSNAME=BikeShareTest${RAND}
LOC=eastus

echo "Check helm version, ensure it's v3.x"
helm version --short

echo "Creating $AKSNAME AKS cluster"
az group create --name $RGNAME  --location $LOC
az aks create -g $RGNAME -n $AKSNAME --location $LOC --disable-rbac --generate-ssh-keys

az aks use-dev-spaces -g $RGNAME -n $AKSNAME --space dev --yes

git clone https://github.com/Azure/dev-spaces
cd dev-spaces/samples/BikeSharingApp/

FQDN=$(azds show-context -o json | jq -r '.[] | .hostSuffix')
echo $FQDN

cd charts/
sed -i "s/<REPLACE_ME_WITH_HOST_SUFFIX>/${FQDN}/g" values.yaml

echo "installing bikeshare app on $(date)"
helm install bikesharing . --dependency-update --namespace dev --atomic --timeout 9m

azds list-uris
