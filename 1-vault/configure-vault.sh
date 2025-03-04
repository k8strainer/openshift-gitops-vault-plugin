## Configure Vault & Secret, O.Liebel 04-03-2025
echo "Starte Setup für Argco CD Vault Plugin: Kubernetes Auth, KV Store, Secret- Erzeugung."
VAULT_AUTO_UNSEAL_ROOT_TOKEN=$(grep root_token ../vault-auto-unseal-keys.txt |awk -F: '{print $2}'|sed 's/ //g')
echo "$VAULT_AUTO_UNSEAL_ROOT_TOKEN"
oc exec -n vault -ti vault-0 -- vault login -tls-skip-verify ${VAULT_AUTO_UNSEAL_ROOT_TOKEN}
oc exec -n vault -ti vault-0 -- vault auth enable kubernetes
oc exec -n vault -ti vault-0 -- vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc"
oc exec -n vault -ti vault-0 -- vault secrets enable -path=kvstore kv-v2

echo "Erzeuge Secret"
oc exec -n vault -ti vault-0 -- vault kv put kvstore/vplugin/supersecret username="myuser" password="mypassword"
oc exec -n vault -ti vault-0 -- vault kv get kvstore/vplugin/supersecret

# prepare app
oc new-project vplugindemo
oc project vplugindemo

# Step - Configure argocd vault plugin auth to vault ###

# Create the service account to be used by argo vault plugin to auth to vault
oc create serviceaccount vplugin
# Create a role in vault to bind our service account to the policy we created earlier
oc -n vault exec vault-0 -- vault write auth/kubernetes/role/vplugin \
    bound_service_account_names=vplugin \
    bound_service_account_namespaces=vplugindemo \
    policies=vplugin \
    ttl=1h

# Create the secret for the argo vault plugin to use to configure vault connection
# Supported parameters list: https://argocd-vault-plugin.readthedocs.io/en/stable/config/
oc -n vplugindemo create -f 2-argocd/secret-vault-configuration.yaml
## comment tbd
oc -n vplugindemo create -f 2-argocd/configmap-plugin.yaml

# Step Create Argo CD App
oc create -f 2-argocd/application-example.yaml
