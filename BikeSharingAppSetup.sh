RAND=$(shuf -i 1-99 -n 1)

RGNAME=k8s
AKSNAME=BikeShareTest${RAND}
LOC=eastus

echo "Check helm version, ensure it's v3.x"
helm version --short

echo "Creating ${AKSNAME} AKS cluster"
az group create --name $RGNAME  --location $LOC
az aks create -g $RGNAME -n $AKSNAME --location $LOC --disable-rbac --generate-ssh-keys --node-vm-size=Standard_B2s

az aks use-dev-spaces -g $RGNAME -n $AKSNAME --space dev --yes

mkdir $AKSNAME
cd $AKSNAME
echo "The current working directory: $PWD"

echo "Cloning Dev-Spaces repo"
git clone https://github.com/Azure/dev-spaces
cd $AKSNAME/dev-spaces/samples/BikeSharingApp/

FQDN=$(azds show-context -o json | jq -r '.[] | .hostSuffix')
echo "---"
echo "The AZDS FQDN is $FQDN"

cd charts/
echo "---"
echo "The current working directory: $PWD"

echo "Replacing FQDN placeholder in values.yaml - $FQDN"
sed -i "s/<REPLACE_ME_WITH_HOST_SUFFIX>/${FQDN}/g" values.yaml

echo "Installing bikeshare app on $(date)"
echo "command is: helm install bikesharing . --dependency-update --namespace dev --atomic --timeout 9m --debug"
helm install bikesharing . --dependency-update --namespace dev --atomic --timeout 9m --debug

echo "Listing AZDS URIs"
azds list-uris
