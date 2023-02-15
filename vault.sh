#!/usr/bin/env sh

kubectl --namespace vault wait --for=condition=Initialized pod/vault-0 && \
while [ `kubectl get pods vault-0 -n vault -o 'jsonpath={..status.phase}'` != "Running"  ]; do sleep 1 ; done

if [ ! -f vault-keys.json ]
then
    kubectl --namespace vault exec -ti vault-0 -- vault operator init -format json > vault-keys.json && sleep 5;
    kubectl --namespace vault exec -ti vault-0 -- mkdir -p /vault/data/keys;
    kubectl --namespace vault exec -ti vault-0 -- sh -c "echo `jq -r .unseal_keys_b64[1] vault-keys.json | base64 ` > /vault/data/keys/_key1";
    kubectl --namespace vault exec -ti vault-0 -- sh -c "echo `jq -r .unseal_keys_b64[2] vault-keys.json | base64 ` > /vault/data/keys/_key2";
    kubectl --namespace vault exec -ti vault-0 -- sh -c "echo `jq -r .unseal_keys_b64[3] vault-keys.json | base64 ` > /vault/data/keys/_key3";
    kubectl --namespace vault exec -ti vault-0 -- sh -c "echo `jq -r .root_token vault-keys.json | base64 ` > /vault/data/keys/_root";
fi

kubectl --namespace vault exec vault-0 -- vault operator unseal `jq -r .unseal_keys_b64[0] vault-keys.json` && \
kubectl --namespace vault exec vault-0 -- vault operator unseal `jq -r .unseal_keys_b64[1] vault-keys.json` && \
kubectl --namespace vault exec vault-0 -- vault operator unseal `jq -r .unseal_keys_b64[2] vault-keys.json`

kubectl --namespace vault exec -ti vault-0 -- vault login token=`jq -r .root_token  vault-keys.json` && \
kubectl --namespace vault exec -ti vault-0 -- vault auth enable kubernetes && \
kubectl --namespace vault exec -ti vault-0 -- sh -c 'vault write auth/kubernetes/config \
                                                        disable_local_ca_jwt=true \
                                                        disable_iss_validation=true \
                                                        kubernetes_host="https://$KUBERNETES_SERVICE_HOST:443" \
                                                        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
                                                        token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" ' && \
kubectl --namespace vault exec -ti vault-0 -- vault secrets enable -path=secret/ kv
kubectl --namespace vault exec -ti vault-0 -- vault kv put secret/dealer dealerjson="`cat abd-charts/simple-service-template/files/dealer.json`"

kubectl --namespace vault exec -ti vault-0 -- vault kv put secret/timerider INFLUXDB_USERNAME="timerider" INFLUXDB_PASSWORD="Center1ty5"
kubectl --namespace vault exec -ti vault-0 -- vault kv put secret/enricher SERVER_CONFIGURATION_UPDATE_ACCESS_PASSWORD="" SERVER_CONFIGURATION_UPDATE_ACCESS_USERNAME=""
kubectl --namespace vault exec -ti vault-0 -- vault kv put secret/configapi DATABASE_USERNAME=root DATABASE_PASSWORD=centQA12au REDIS_PASSWORD=admin1234 REDIS_HOST=redis-master PG_DATABASE_PASSWORD=postgres PG_DATABASE_USERNAME=postgres
kubectl --namespace vault exec -ti vault-0 -- vault kv put secret/sqlrunner DATABASE_USERNAME=root DATABASE_PASSWORD=centQA12au

kubectl --namespace vault exec -ti vault-0 -- sh -c 'echo "path \"secret/timerider\" { capabilities = [\"read\"] }" | vault policy write timerider -' && \
kubectl --namespace vault exec -ti vault-0 -- vault write auth/kubernetes/role/timerider \
                                                bound_service_account_names=default \
                                                bound_service_account_namespaces=abd \
                                                policies=timerider && \
kubectl --namespace vault exec -ti vault-0 -- sh -c 'echo "path \"secret/enricher\" { capabilities = [\"read\"] }" | vault policy write enricher -' && \
kubectl --namespace vault exec -ti vault-0 -- vault write auth/kubernetes/role/enricher \
                                                bound_service_account_names=default \
                                                bound_service_account_namespaces=abd \
                                                policies=enricher && \
kubectl --namespace vault exec -ti vault-0 -- sh -c 'echo "path \"secret/configapi\" { capabilities = [\"read\"] }" | vault policy write configapi -' && \
kubectl --namespace vault exec -ti vault-0 -- vault write auth/kubernetes/role/configapi \
                                                bound_service_account_names=default \
                                                bound_service_account_namespaces=abd \
                                                policies=configapi
kubectl --namespace vault exec -ti vault-0 -- sh -c 'echo "path \"secret/sqlrunner\" { capabilities = [\"read\"] }" | vault policy write sqlrunner -' && \
kubectl --namespace vault exec -ti vault-0 -- vault write auth/kubernetes/role/sqlrunner \
                                                bound_service_account_names=default \
                                                bound_service_account_namespaces=abd \
                                                policies=sqlrunner
export_keys () {
    export PRIVATE="$(echo "$KEYS" | sed -n 's;Secret:\s\+\(.*\);\1;p')"
    export PUBLIC="$(echo "$KEYS" | sed -n 's;Public:\s\+\(.*\);\1;p')"
}
generate_keypair () {
    while [ "${PUBLIC:0:1}" == { ] || [ "${PRIVATE:0:1}" == { ] || [ "${PUBLIC:0:1}" == } ] || [ "${PRIVATE:0:1}" == } ] || [ "$PUBLIC" == *"$"* ] || [ "$PRIVATE" == *"$"* ] || [ "$PUBLIC" == *"&"* ] || [ "$PRIVATE" == *"&"* ] || [ "$PUBLIC" == *":"* ] || [ "$PRIVATE" == *":"* ] || [ "$PUBLIC" == *"*"* ] || [ "$PRIVATE" == *"*"* ]
    do      
        KEYS="$($RESOURCE_DIR/generate_curev_keypair)" && export_keys
    done
}

export RESOURCE_DIR="./secret-key"
KEYS="$($RESOURCE_DIR/generate_curev_keypair)"
export_keys && generate_keypair
export AUTHENTICATION_DEALER_CLUSTER_PRIVATE="$(echo "$KEYS" | sed -n 's;Secret:\s\+\(.*\);\1;p')"
export AUTHENTICATION_DEALER_CLUSTER_PUBLIC="$(echo "$KEYS" | sed -n 's;Public:\s\+\(.*\);\1;p')"
KEYS="$($RESOURCE_DIR/generate_curev_keypair)"
export_keys && generate_keypair
export AUTHENTICATION_DEALER_REGISTER_PUBLIC="$(echo "$KEYS" | sed -n 's;Public:\s\+\(.*\);\1;p')"
export AUTHENTICATION_DEALER_REGISTER_PRIVATE="$(echo "$KEYS" | sed -n 's;Secret:\s\+\(.*\);\1;p')"
KEYS="$($RESOURCE_DIR/generate_curev_keypair)"
export_keys && generate_keypair
export AUTHENTICATION_DEALER_QUEUE_PUBLIC="$(echo "$KEYS" | sed -n 's;Public:\s\+\(.*\);\1;p')"
export AUTHENTICATION_DEALER_QUEUE_PRIVATE="$(echo "$KEYS" | sed -n 's;Secret:\s\+\(.*\);\1;p')"
KEYS="$($RESOURCE_DIR/generate_curev_keypair)"
export_keys && generate_keypair
export AUTHENTICATION_DEALER_EVENT_PUBLIC="$(echo "$KEYS" | sed -n 's;Public:\s\+\(.*\);\1;p')"
export AUTHENTICATION_DEALER_EVENT_PRIVATE="$(echo "$KEYS" | sed -n 's;Secret:\s\+\(.*\);\1;p')"
KEYS="$($RESOURCE_DIR/generate_curev_keypair)"
export_keys && generate_keypair
export AUTHENTICATION_DEALER_HANDLER_PUBLIC="$(echo "$KEYS" | sed -n 's;Public:\s\+\(.*\);\1;p')"
export AUTHENTICATION_DEALER_HANDLER_PRIVATE="$(echo "$KEYS" | sed -n 's;Secret:\s\+\(.*\);\1;p')"
export ENGINE_REST_JWT_SECRET="$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c20)"
export ENGINE_REST_PASSWRD_SALT="$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c20)"
export ENGINE_DB_CONN_URL="postgresql://postgres:postgres@postgres-postgres/dealer"
export ENGINE_UI_API_TOKEN="ryk4uuasanvf03hs28lu7nzqbq1b5a"
export license=$(/usr/bin/uuidgen)
export dns_name='demo.abd.com'


kubectl --namespace vault exec -ti vault-0 -- vault kv put secret/dealer AUTHENTICATION_DEALER_CLUSTER_PRIVATE=$AUTHENTICATION_DEALER_CLUSTER_PRIVATE AUTHENTICATION_DEALER_CLUSTER_PUBLIC=$AUTHENTICATION_DEALER_CLUSTER_PUBLIC AUTHENTICATION_DEALER_REGISTER_PUBLIC=$AUTHENTICATION_DEALER_REGISTER_PUBLIC AUTHENTICATION_DEALER_REGISTER_PRIVATE=$AUTHENTICATION_DEALER_REGISTER_PRIVATE AUTHENTICATION_DEALER_QUEUE_PUBLIC=$AUTHENTICATION_DEALER_QUEUE_PUBLIC AUTHENTICATION_DEALER_QUEUE_PRIVATE=$AUTHENTICATION_DEALER_QUEUE_PRIVATE AUTHENTICATION_DEALER_EVENT_PUBLIC=$AUTHENTICATION_DEALER_EVENT_PUBLIC AUTHENTICATION_DEALER_EVENT_PRIVATE=$AUTHENTICATION_DEALER_EVENT_PRIVATE AUTHENTICATION_DEALER_HANDLER_PUBLIC=$AUTHENTICATION_DEALER_HANDLER_PUBLIC AUTHENTICATION_DEALER_HANDLER_PRIVATE=$AUTHENTICATION_DEALER_HANDLER_PRIVATE ENGINE_REST_JWT_SECRET=$ENGINE_REST_JWT_SECRET ENGINE_REST_PASSWRD_SALT=$ENGINE_REST_PASSWRD_SALT ENGINE_DB_CONN_URL=$ENGINE_DB_CONN_URL ENGINE_UI_API_TOKEN=$ENGINE_UI_API_TOKEN
kubectl --namespace vault exec -ti vault-0 -- sh -c 'echo "path \"secret/dealer\" { capabilities = [\"read\"] }" | vault policy write dealer -' && \
kubectl --namespace vault exec -ti vault-0 -- vault write auth/kubernetes/role/dealer \
                                                      bound_service_account_names=default \
                                                      bound_service_account_namespaces=abd \
                                                      policies=dealer
