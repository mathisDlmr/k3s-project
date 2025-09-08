# Setup du projet

## Website 
- [ ] Ajuster le shadow violet sur les techno
- [ ] Ajouter un filtre sur les projets
- [ ] Mettre à jour les liens, descriptions, langages... dans les projects
- [ ] Proposer plusieurs screens/pdf de chaque projet

## Projets
* Skiut
* Uptime Kuma
* Monitoring Prom Grafana / Loki
* Hosting étu
* Registry Harbor
* Gitea

## TODO
* setup kubectl et ssh avec une ouverture de port
* setup SFTP
* créer des ressources kind Namespace au cas où
* kind Kustomization
* Actuellement le certificat de sécurité récupéré n'est pas vraiment utilisé car validé pour le domaine, mais pas pour l'IP 192...... En effet, comme Let's Encrypt n'arrive pas à tester l'IP privée, ça fail. Il faudra réessayer avec les ports ouverts et en ajoutant l'ip dans les hosts tls de cluster-ingress

## Tuto

### 1. Installer une OS Server (e.g. Ubuntu Server) sur un Rasp, N150, ...

### 2. Installer et configurer la connexion SSH (généralement possible à l'installation)

### 3. Configurer le wifi

```bash
sudo nano /etc/netplan/01-wifi.yaml
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

### 4. Tester la connexion SSH

Récupérer l'IP du réseau
```bash
ip a
```

Scanner le réseau
```bash
nmap -sn <reseau>/<mask>
```

Trouver l'ip du serveur et se ssh dessus
```bash
ssh <login>@<ip>
```

### 5. Optionnel mais pratique : configurer le DHCP de sa box pour donner une ip fixe au serveur

### 6. Installer k3s

```bash
curl -sfL https://get.k3s.io | sh -
```

### 7. Config son kubectl

```bash
scp <login>@<ip>:/etc/rancher/k3s/k3s.yaml ./k3s.yaml
```

Modifier le fichier pour pointer vers le serveur
```bash
mkdir -p ~/.kube
sed -i 's/127.0.0.1/<ip>/' ~/.kube/config
k get pods -A
```

-> Normalement on y retrouve les services de k3s par défaut (coredns, traefik, ...)

### 8. Déployer argoCD

```bash
k create namespace argocd
k apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
k get pods -n argocd
k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
k port-forward svc/argocd-server -n argocd 8081:443
```

-> L'UI est maintenant accessible sur `http://localhost:8081`. Le login est `admin` est le mdp a été révélé par le secret ci-dessus

### 9. Déployer cert-manager

Pour permettre une connexion HTTPS sans avoir à renouveler les certificats TLS à la main, le plus simple est d'installer cert-manager.
Cert-manager s'occupe tout seul de communiquer avec Lets-Encrypt et résoudre les challenges DNS/HTTP pour récupérer un certificat.
Une fois le certificat délivré, il le stocke dans un secret qui peut être ensuite utilisé par l'Ingress.
La ressource cluster-issuer permet simplement de configurer le CA qu'on utilise.

```bash
k create namespace cert-manager
k apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
k get pods -n cert-manager
```

### 12. Cloudflare Tunnel

Afin de permettre l'installation du serveur sur n'importe quel réseau sans ouvrir de port, un tunnel cloudflare a été défini.
Concrètement, un Daemonset `cloudflared` agit pour maintenir une connexion persistante vers CloudFlare qui sert de tunnel :
```
[ Navigateur ] ⇄ HTTPS ⇄ [ Cloudflare Edge ]
                              ⇅
                              ⇅ (Tunnel sortant maintenu)
                              ⇅
                       [ cloudflared Daemon ] → [ Ingress Controller Traefik ] → [ Services ]
```

Pour ça, créer le namespace infra et ajouter en secret le token de cloudflare
```bash
kubectl create namespace infra
kubectl create secret generic cloudflared-token --from-literal=token='<token>' -n infra
```
Ensuite, il faut configurer le DNS du tunel cloudflare pour chaque sous-domaine DNS souhaité en lui donnant une target dans le cluster. Cela se fait depuis Zero Trust -> Networks -> Tunnels -> Public hostname
**Attention** : comme la sortie du tunnel est dans le cluster, la target est au format `https://....namespace.svc.cluster.local:port` (exemple : http://argocd-server.argocd.svc.cluster.local:80)

### 13. Challenge DNS

Pour permettre à Let's Encrypt de faire ses challenges, il faut soit 
* Configurer les CNAME pour permettre les challenges HTTP sur chaque CNAME
* Créer un token API avec droits d'édition sur les zones DNS pour faire des challenges DNS
La deuxième solution étant plus simple, c'est celle qu'on implémente ici.
Pour ça il faut aller sur cloudfare pour créer le token api et lui donner des droits d'édition sur la zone DNS mdlmr
```bash
kubectl create secret generic cloudflare-api-token-secret --from-literal=api-token='<token>' -n infra
```

On peut vérifier après avec 
```bash
k describe certificate mdlmr-fr-tls -n infra
```

En cas d'erreur, vérifier les challenges : 
```bash
k describe certificate mdlmr-fr-tls -n infra
k describe certificaterequest mdlmr-fr-tls -n infra
k get challenges -A
k describe challenge mdlmr-fr-tls-<id_de_challenge> -n infra
```

### 14. Rendre ArgoCD accessible

Pour rendre argoCD accessible, il suffit de désactiver la sécurité comme notre https se fait maintenant au niveau de l'ingress, et que l'ingress sert ensuite vert notre service.
On ajoute donc à argocd-cmd-params-cm :

```yaml
data:
  server.insecure: "true"
```

Puis on redémarre argocd : 
```bash
k rollout restart deployment argocd-server -n argocd
```


<!-- ### 14. SSH à travers le tunnel

Il est possible d'activer la connexion SSH depuis l'UI de CloudFlare.
Pour ça il faut ajouter un public hostname avec le protocole SSH qui target le port `http://localhost:22`.
Ensuite, côté dev, il faut ajouter 
```bash
echo '

Host ssh.mdlmr.fr
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
  User user' >> ~/.ssh/config
```

Le serveur est maintenant accessible depuis `ssh login@ssh.mdlm.fr`

### 15. Kubectl à travers le tunnel -->



### Fin. Déployer meta 

```bash
k create namespace meta
k apply -f argocd/apps-meta.yaml
```

-> Il devrait apparaitre sur l'UI et commencer à tout créer