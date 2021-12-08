# Vault Installation

Dies ist ein Playbook, welches die Vault und Consul Installation verskriptet. 
Da es hierbei einige zeitliche Abhängigkeiten bei der Konfiguration gibt, wird die empfohlene Vorgehensweise hier näher erläutert:

**Hinweis:** Dieses Playbook kann zwar technisch wiederholt ausgeführt werden, es ist jedoch nicht sinnvoll. 
Bei einer wiederholten Ausführung kommt es zu einer erneuten Ausstellung eines Root-Zertifikats, was die Invalidierung aller bisher ausgestellten Zertifikate zur Folge hat. 
Sobald Vault also einmal im Einsatz ist, sollte dieses Playbook nicht mehr genutzt werden.

1. #### Basis-Installation

   Installation der Komponenten vault und consul

   ```bash
   ansible-playbook vault_01_basis.yml
   ```

   Nach dem erfolgreichen Durchlauf sollten
   Consul unter der Adresse http://vault.local.home:8500/ui/dc1/kv
   Vault unter der Adresse (http://vault.local.home:8200/ui/vault/init) verfügbar sein. 

2. #### Konfiguration von Vault

   Nun ist ein manueller Schritt nötig, der direkt an der grafischen Oberfläche von Vault vorgenommen werden kann. 
   Dies dient direkt auch einem ersten Test, ob die bisherige Installation und Einrichtung erfolgreich war. 
   Zunächst muss die URL http://vault.local.home:8200/ui/vault/init besucht werden.

   Auf dieser Einrichtungsseite müssen nun die Master-Keys generiert werden. Hier sollten als "Key shares" mindestens 5 ausgewählt werden. 
   Als "Key threshold" mindestens 3. Dies bedeutet, dass 5 Master-Keys zum Freischalten von Vault generiert werden und 
   mindestens 3 davon eingegeben werden müssen um Vault freizuschalten.
   Im darauffolgenden Bildschirm werden die generierten Keys angezeigt. Diese müssen unbedingt gesichert werden.

   Das hier erhaltene Root-Token muss im Playbook als Variable hinterlegt werden (Group-Vars: hc_vault_hosts): **hc_vault.root_token**. 

   Außerdem muss sich per SSH auf einen beliebigen Consul-Host verbunden werden und folgender Befehl eingegeben werden:

   ```bash
   consul keygen
   # BhfgJngQuJvh2AEd/TDcTkCYxHB014QBfP00BNrhQZ0=
   ```

   Als Antwort erhält man einen generierten Encrypt-String, welcher ebenfalls in der gleichen Group-Vars Datei eingetragen werden muss, 
   unter der Variable **hc_vault.encrypt_string**.
   Bevor das Playbook gestartet werden kann, muss Vault in jedem Falle entsperrt sein. 
   Dies kann ebenfalls wieder an der grafischen Oberfläche gemacht werden. 
   Hier fragt Vault nacheinander die definierte Anzahl an Master-Keys ab, bevor es sich entsperren lässt. Diese müssen eingegeben werden.

   Wenn dieser Vorgang erfolgreich war, zeigt Vault die Login-Maske mit der Meldung *Sign in to Vault* an. 
   *Hinweis:* Es sollten sämtliche aufgesetzte Vault Server entsperrt werden.

   #### Erzeugung der Zertifikate

   **Achtung:** Im nachfolgenden Playbook wird ein Root Zertifikat erzeugt, sowie eine Intermediate CA, 
   unter der später alle Zertifikate erzeugt werden.

   Falls Vault mit bestehenden Zertifikaten bestückt werden soll, dann müsste ein PEM Bundle erstellt werden und Vault übergeben
   Hierbei ist strikt auf die Reihenfolge im PEM Bundle zu achten, es muss folgendes enthalten sein:

   1. Intermediate (SubCA) Zertifikat
   2. Root Zertifikat
   3. Key (unencrypted!) der Intermediate CA

   Nur wenn die Zertifikate in dieser Reihenfolge eingefügt werden, kann Vault das PEM Bundle speichern.


   Nun kann die initiale Konfiguration von Vault mittels Playbook fortgesetzt werden:

   ```bash
   ansible-playbook vault_02_config.yml
   ```

   Dieses Playbook lässt sich zwar erneut ausführen, einige Tasks werden dann aber einfach ignoriert, 
   da die Befehle zum Einrichten einer PKI nicht wiederholt werden können.

3. #### Absicherung per SSL

   Nun müssen die Zertifikate für die Consul und Vault Server erzeugt werden. 
   Dazu muss zunächst das RootCA Zertifikat, sowie das Zwischenzertifikat heruntergeladen werden. 
   Dazu kann der folgende Befehl genutzt werden:

   ```bash
   ROOT Zertifikat
   curl http://127.0.0.1:8200/v1/pki/ca/pem --output rootCA.pem
 
   Intermediate Zertifikat
   curl http://127.0.0.1:8200/v1/pki_int/ca_chain --output intermediateCA.pem
   ```
   
   
   Verifizierung der Zertifikate   
   ```bash
   openssl x509 -in intermediateCA.pem -text
   openssl x509 -in rootCA.pem -text
   ```
   bzw.
   ```bash
   openssl x509 -dates -issuer -subject -noout  -in intermediateCA.pem
   openssl x509 -dates -issuer -subject -noout  -in rootCA.pem
   ```

   Es gilt
   ```bash
   openssl verify -CAfile rootCA.pem intermediateCA.pem
   CA.pem: OK
   ```
   
   
   Außerdem muss nun ein konkretes Zertifikat für die Consul und Vault Hosts generiert werden. 
   Es wird ein einziges Zertifikat verwendet, welches auf den DNS-Namen der virtuellen IP ausgestellt ist 
   (z.B. vault.local.home). Die konkreten Konsul- und Vault-Hosts werdern als Subject-Alternative-Names aufgeführt 
   (z.B. vault.local.home, vault2.local.home...).
   Hierzu kann der folgende shell-skript genutzt werden (Token anpassen)

   ```bash   
   bash distCerts.sh
   ```

   Als Antwort kommen hier die Zertifikate und der Private Key zurück. 
   Diese werden in
   *05_ssl_consul*,*06_ssl_vault*, *07_after_all_tasks* eingefügt:

   |Teil im Response|Platzhalter-Datei|Anmerkung|
   |--|--|--|
   |letztes Zertifikat der ca chain|RootCA.pem|RootCA varsamis.home|
   |issuing ca bzw. erstest Zertifikat in der ca chain|CA.pem|IntermediateCA varsamis.home Intermedaite Authority|
   |certificate|consul.pem|Zertifikat für die Vault- und Consul-Hosts|
   |private key|consul.key.dummy|private Key für das Zertifikat für die Vault- und Konsul-Hosts|

   Nun kann das Playbook fortgesetzt werden:

   ```bash
   ansible-playbook vault_03_ssl.yml
   ```

   Nun sollte Vault unter der neuen https-Adresse: https://vault.local.home:8200/ui/vault/ verfügbar sein.

   Consul ist nun unter: https://vault.local.home:8501/ui/dc1/ erreichbar.

4. #### Manuelle Konfiguration

   Nun muss Vault erneut freigeschaltet werden, da der Service im Playbook neu gestartet wurde s.o.).
   Nun folgenden Befehl auf einem entsperrten Vault Host ausführen:

   Über die UI consul als secrets engine enablen

   Nun das Playbook fortsetzen:

   ```bash
   ansible-playbook vault_04_acls.yml
   ```

   Auf einem Consul Server ist folgender Befehl auszuführen um die ACLs zu aktivieren:

   ```bash
   sudo consul acl bootstrap -http-addr=https://192.168.2.49:8501 \
     -client-cert /usr/local/etc/consul/certs/consul.pem \
     -client-key /usr/local/etc/consul/certs/consul.key \
     -ca-file /usr/local/etc/consul/certs/CA.pem
   # AccessorID:       90c00355-d769-3047-aaf7-f670e7eeaaa3
   # SecretID:         2a7331d6-4570-3c89-66e6-face98d578cd
   # Description:      Bootstrap Token (Global Management)
   # Local:            false
   # Create Time:      2021-04-22 19:48:20.758438382 +0000 UTC
   # Policies:
   #    00000000-0000-0000-0000-000000000001 - global-management

   
   # Hier die SecretID einsetzen (auszuführen auf Consul-Host):
   curl -k --header "X-Consul-Token: 2a7331d6-4570-3c89-66e6-face98d578cd" --request PUT --data '{"Name": "Vault", "Type": "management"}' https://192.168.2.49:8501/v1/acl/create
   #{"ID":"5301fbea-40f3-278d-2e9d-002e8a0644a4"}
   ```

   Diese ID muss wiederum in den Group-Vars des Playbooks eingesetzt werden in die Variable **hc_vault.vault_consul_token**.

   Nun kann das Playbook fortgesetzt werden:

   ```bash
   ansible-playbook vault_05_acls.yml
   ```

   Nun ist die Kommunikation nur noch zwischen Vault und Consul möglich, 
   da die Verbindung über ein Token abgesichert ist. 
   Nur dieses Vault Token hat volle Zugriffsrechte auf Consul, alle anderen Anfragen werden standardmäßig abgewiesen.
