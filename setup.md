# Présentation

## Techno :

- k3s
- ArgoCD
- SealedSecrets
- Cert-manager
- Cloudflare Tunnel
- Traefik
- Prometheus
- Grafana
- Alertmanager
- Déploiement complet d'une stack pour Ski'UT

## ArgoCD

ArgoCD est notre outil de GitOps. Concrètement, il lit notre repository Git contenant toutes nos configurations Kubernetes (manifests, Helm charts, Kustomize) et synchronise automatiquement le cluster avec ce qui est défini dans Git.
On a défini une application meta qui déploie toutes les autres applications du cluster, ce qui permet de centraliser le contrôle et d’avoir une chaîne de déploiement automatisée et versionnée.

Grâce à ArgoCD, on peut :

- Déployer des applications dans n’importe quel namespace.
- Suivre l’état exact des ressources dans le cluster.
- Automatiser le self-healing et le prune pour supprimer les ressources obsolètes.
- Centraliser la gestion de secrets avec SealedSecrets et cert-manager.

## SealedSecrets

SealedSecrets permet de chiffrer nos secrets Kubernetes afin de pouvoir les stocker dans Git en toute sécurité. Chaque secret est chiffré avec la clé publique du contrôleur SealedSecrets dans le cluster et déchiffré automatiquement lorsqu’il est appliqué dans le cluster.

Avantages :

- Pas besoin de stocker les secrets en clair dans Git.
- Les secrets restent portables entre clusters : chaque cluster a sa propre clé privée pour déchiffrer les secrets.
- Compatible avec ArgoCD et GitOps, donc les secrets sont appliqués automatiquement au déploiement des applications.

## Cert-manager

Pour permettre une connexion HTTPS sans avoir à renouveler les certificats TLS à la main, le plus simple est d’installer cert-manager.
Cert-manager s’occupe tout seul de communiquer avec Let’s Encrypt et de résoudre les challenges DNS/HTTP pour récupérer un certificat.

- Les certificats sont ensuite stockés dans des Secrets Kubernetes, prêts à être utilisés par les Ingress.
- La ressource ClusterIssuer permet de définir le CA et la méthode de validation (HTTP-01 ou DNS-01).
- Dans notre setup, on utilise souvent DNS-01 via Cloudflare pour que le challenge fonctionne même derrière un tunnel.

## Cloudflare Tunnel

Afin de pouvoir installer le serveur sur n’importe quel réseau sans ouvrir de port, un tunnel Cloudflare est utilisé.
Concrètement, un DaemonSet `cloudflared` maintient une connexion sortante persistante vers l’infrastructure Cloudflare. Tout le trafic HTTP(S) est ensuite routé vers les services du cluster via Traefik.

```bash
[ Navigateur ] ⇄ HTTPS ⇄ [ Cloudflare Edge ]
                              ⇅
                              ⇅ (Tunnel sortant maintenu)
                              ⇅
                       [ cloudflared Daemon ] → [ Ingress Controller Traefik ] → [ Services ]
```

Avantages :

- Pas besoin d’ouvrir les ports sur ta box.
- Tout est routé de manière sécurisée via Cloudflare.
- Permet d’utiliser des certificats TLS publics avec cert-manager.

## Traefik

Traefik est notre Ingress Controller.
Il écoute sur les ports 80 et 443 et route les requêtes HTTP(S) vers les services correspondants en fonction des Ingress définis.

- Supporte nativement TLS avec cert-manager, Let’s Encrypt et ACME.
- Peut être exposé en NodePort, LoadBalancer, ou derrière Cloudflare Tunnel.
- Gère le routage vers plusieurs services comme registry.mdlmr.fr, skiut.mdlmr.fr, hosting.mdlmr.fr ou argocd.mdlmr.fr.
- Permet d’ajouter du middleware (auth, redirections, headers) très facilement.

## Prometheus

Prometheus est le système de monitoring et de collecte de métriques.
Il récupère automatiquement les métriques exposées par les services et pods Kubernetes via des endpoints /metrics.

- Très utile pour suivre l’état du cluster, des nodes et des applications.
- Compatible avec Grafana pour visualiser les données via des dashboards.
- Permet de créer des alertes basées sur les métriques observées.

## Grafana

Grafana est l’outil de visualisation des métriques.

- Permet de créer des dashboards dynamiques pour voir la charge CPU, la mémoire, l’usage réseau, etc.
- Peut se connecter à Prometheus et d’autres bases de données de métriques.
- Permet également de visualiser les traces envoyées par Grafana Tempo si on active l’OpenTelemetry dans nos services backend.

## Alertmanager

Alertmanager est le composant de gestion des alertes pour Prometheus.

- Reçoit les alertes générées par Prometheus.
- Permet de regrouper, dédoublonner, inhiber ou envoyer les alertes vers différents canaux (email, Slack, webhook…).
- Permet de ne pas être spammé par des alertes répétitives et d’avoir un suivi centralisé des incidents.

## Ski'UT

Déploiement complet d’une stack pour Ski’UT, l’association UTCéenne qui organise chaque année un voyage au ski et propose une application mobile pour animer le voyage.

La stack déployée comprend :

- Backend Laravel
  - Deployment, Service, Ingress, ConfigMap et SealedSecret.
  - HPA et PDB pour garantir un fonctionnement stable.
  - CronJob pour envoyer automatiquement des notifications.
  - PVC pour stocker les données persistantes et les partager entre les différentes instances backend.
- MySQL StatefulSet
  - Service, ConfigMap et SealedSecret.
- ProxySQL
  - Deployment, Service et ConfigMap pour gérer les pools de connexions à la DB.
- PhpMyAdmin
  - Deployment, Service et Ingress pour visualiser la base de données.

# Setup

## 1. Installer une OS Server (e.g. Ubuntu Server) sur un Rasp, Nuc, ...

## 2. Configurer le wifi

```bash
sudo nano /etc/netplan/00-config.yaml
```

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      dhcp4: true
  wifis:
    wlp1s0:
      dhcp4: true
      access-points:
        "NomDuWifi":
          password: "MotDePasseWifi"
```

```bash
sudo netplan generate
sudo netplan apply
ip a
```

## 3. Configurer ssh

```bash
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

## 4. Activer le firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 6443/tcp
sudo ufw enable
```

## 5. Installer tailscale

```bash
sudo apt update
sudo apt install -y tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh
tailscale status
sudo ufw allow in on tailscale0
```

## 6. Installer k3s sur le control-plane

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --node-name <CP_NODE_NAME> \
  --tls-san 127.0.0.1 \
  --tls-san localhost \
  --tls-san <IP_LAN> \
  --tls-san <IP_TAILSCALE> \
  --disable traefik
```

## 7. (Optionnel) Ajouter un node worker

### 7.1. Configurer le worker

Refaire les étapes 1 à 5 sur le worker

### 7.2. Récupérer le token du control-plane

Sur le noeud master :

```bash
sudo cat /var/lib/rancher/k3s/server/token
```

### 7.3. Ajouter le worker au cluster

Sur le noeud worker :

```bash
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://<CP_TAILSCALE_IP>:6443 \
  --token <TOKEN> \
  --node-name <WORKER_NODE_NAME>
```

### 7.4. Définir les labels des nodes (exemple)

Exemple avec

- Un control-plane
  - stable
  - puissant
- Un worker
  - instable
  - faible

```bash
kubectl label node <CP_NODE_NAME> \
  node-role=stable \
  node-power=high

kubectl label node <WORKER_NODE_NAME> \
  node-role=unstable \
  node-power=low

kubectl taint node <CP_NODE_NAME> \
  instability=true:NoSchedule
```

### 7.5. Vérifier le cluster

```bash
kubectl get nodes
```

## 8. Donner accès au cluster à son pc

```bash
scp <login>@<CP_IP>:/etc/rancher/k3s/k3s.yaml ./k3s.yaml
```

Modifier le fichier pour pointer vers le control-plane

```bash
mkdir -p ~/.kube
sed -i 's/127.0.0.1/<CP_TAILSCALE_IP>/' ~/.kube/config
k get pods -A
```

## 9. Installer argocd

```bash
k create namespace argocd
k apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
k get pods -n argocd
k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
k port-forward svc/argocd-server -n argocd 8081:443
```

-> L'UI est maintenant accessible sur `http://localhost:8081`. Le login est `admin` est le mdp a été révélé par le secret ci-dessus

## 10. Donner les accès du repo à ArgoCD

```bash
ssh-keygen -t ed25519 -C "mon.email@domain.com"
```

Ensuite, ajouter la clé publique dans le repo : Settings > Deploy keys
Puis ajouter la clé privée dans ArgoCD : Settings > Repository

## 11. Créer l'app meta qui va tout déployer

```bash
k apply -f argocd/apps-meta.yaml
```

## 12. Installer kubeseal pour chiffrer nos secrets

```bash
KUBESEAL_VERSION='0.34.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
```

### 12.1. Chiffrer les secrets

Qui dit nouveau cluster, dit nouvelle clé privée pour sealed-secrets, et donc nouveaux secrets chiffrés.

```bash
cat <secret.yaml> | kubeseal --controller-namespace infra --controller-name sealed-secrets --format yaml > <sealed-secret.yaml>
```

Les secrets à recréer à partir de clés définies sont :

- cloudflare-api-token-secret.yaml
- cloudflare-tunnel-token-secret.yaml

Les autres peuvent être définis manuellement.

# TODO

## TODO

- Définir taint et tolérations :
  - Prom, Grafana, AlertManager, CronJobs Skiut c'est sur le worker
- Mieux ranger les serviceMonitor :
  - Sois les supprimer
  - Sois les deployer dans leur namespace concerné
  - Et voir si il n'y a pas d'autres serviceMonitor sympa à deploy
- Mieux gérer les certificats de sécruité et DNS
- Pourquoi l'arborescende sur l'ui de argoCD n'est pas bonne ?
- ArgoCD projects ?

- [ ] Loki (Promtail + logcli ?)
- [ ] Tempo
- [ ] External DNS
- [ ] Kargo
- [ ] Uptime Kuma
- [ ] Registry Harbor
- [ ] Gitea
- [ ] Hosting

## TODO - Website

- [ ] Ajuster le shadow violet sur les techno
- [ ] Ajouter un filtre sur les projets
- [ ] Mettre à jour les liens, descriptions, langages... dans les projects
- [ ] Proposer plusieurs screens/pdf de chaque projet
