#!/bin/bash

set -o nounset \
    -o errexit

printf "Deleting previous (if any)..."
rm -rf secrets
mkdir secrets
mkdir -p tmp
echo " OK!"
# Generate CA key
printf "Creating CA..."
openssl req -new -x509 -keyout tmp/ca.confluent.io.key -out tmp/ca.confluent.io.crt -days 7300 -subj '/C=US/ST=CA/L=Mountain View/O=Confluent\, Inc./OU=Information Technology/CN=ca.confluent.io' -passin pass:cnf123 -passout pass:cnf123 >/dev/null 2>&1

echo " OK!"

for i in 'kafka-ssl' 'producer' 'consumer' 'schema-registry'
do
	printf "Creating cert and keystore of $i..."
	# Create keystores
	keytool -genkey -noprompt \
				 -alias $i \
				 -dname "CN=$i, OU=Information Technology, O=Confluent\, Inc., L=Mountain View, C=US, ST=CA" \
				 -keystore secrets/$i.keystore.jks \
				 -keyalg RSA \
				 -storepass cnf123 \
				 -keypass cnf123 >/dev/null 2>&1

	# Create CSR, sign the key and import back into keystore
	keytool -keystore secrets/$i.keystore.jks -alias $i -certreq -file tmp/$i.csr -storepass cnf123 -keypass cnf123 >/dev/null 2>&1

	openssl x509 -req -CA tmp/ca.confluent.io.crt -CAkey tmp/ca.confluent.io.key -in tmp/$i.csr -out tmp/$i-ca-signed.crt -days 7300 -CAcreateserial -passin pass:cnf123  >/dev/null 2>&1

	keytool -keystore secrets/$i.keystore.jks -alias CARoot -import -noprompt -file tmp/ca.confluent.io.crt -storepass cnf123 -keypass cnf123 >/dev/null 2>&1

	keytool -keystore secrets/$i.keystore.jks -alias $i -import -file tmp/$i-ca-signed.crt -storepass cnf123 -keypass cnf123 >/dev/null 2>&1

	# Convert keystore to pkscs12
	keytool -srcstorepass cnf123 -importkeystore -srckeystore secrets/$i.keystore.jks -destkeystore secrets/$i.keystore.jks -deststoretype pkcs12 -deststorepass cnf123  2>&1

	# Create truststore and import the CA cert.
	keytool -keystore secrets/$i.truststore.jks -alias CARoot -import -noprompt -file tmp/ca.confluent.io.crt -storepass cnf123 -keypass cnf123 >/dev/null 2>&1

	# Convert truststore to pkscs12
	keytool -srcstorepass cnf123 -importkeystore -srckeystore secrets/$i.truststore.jks -destkeystore secrets/$i.truststore.jks -deststoretype pkcs12 -deststorepass cnf123  2>&1
  echo " OK!"
done

echo "cnf123" > secrets/cert_creds
#rm -rf tmp

echo "SUCCEEDED"
