curl http://127.0.0.1:8200/v1/pki/ca/pem --output rootCA.pem
curl http://127.0.0.1:8200/v1/pki_int/ca_chain --output intermediateCA.pem

echo "$(openssl x509 -dates -issuer -subject -noout  -in intermediateCA.pem)"
echo "$(openssl x509 -dates -issuer -subject -noout  -in rootCA.pem)"

curl -X POST \
  http://192.168.2.50:8200/v1/pki_int/issue/local-home \
  -H 'Cache-Control: no-cache' \
  -H 'Content-Type: application/json' \
  -H 'x-vault-token: s.yNbvM6TEVHwmJqdAJQjLB3lG' \
  -d '{
        "common_name":"vault.local.home",
   	    "alt_names":"vault.local.home,consul.local.home,pi50.local.home,pi49.local.home",
   	    "ip_sans":"192.168.2.50,192.168.2.49",
   	    "ttl":"8760h",
        "format":"pem",
   	    "exclude_cn_from_sans":true
   }' --output response.json

cat response.json  | jq --raw-output ".data.private_key" > consul.key
cat response.json  | jq --raw-output ".data.certificate" > consul.pem
cat response.json  | jq --raw-output ".data.ca_chain[0]" > _rootCA_.pem
cat response.json  | jq --raw-output ".data.issuing_ca" > _CA_.pem

cp _rootCA_.pem roles/vault/05_ssl_consul/files/cert/rootCA.pem
cp _CA_.pem     roles/vault/05_ssl_consul/files/cert/CA.pem
cp consul.key   roles/vault/05_ssl_consul/files/cert/consul.key
cp consul.pem   roles/vault/05_ssl_consul/files/cert/consul.pem

cp _rootCA_.pem roles/vault/06_ssl_vault/files/cert/rootCA.pem
cp _CA_.pem     roles/vault/06_ssl_vault/files/cert/CA.pem
cp consul.key   roles/vault/06_ssl_vault/files/cert/consul.key
cp consul.pem   roles/vault/06_ssl_vault/files/cert/consul.pem

cp _rootCA_.pem roles/vault/07_after_all_tasks/files/cert/rootCA.pem
cp _CA_.pem     roles/vault/07_after_all_tasks/files/cert/CA.pem
cp consul.key   roles/vault/07_after_all_tasks/files/cert/consul.key
cp consul.pem   roles/vault/07_after_all_tasks/files/cert/consul.pem

rm _rootCA_.pem
rm _CA_.pem
rm response.json
