# Setup du projet

## TODO
* setup SFTP
* kind Kustomization
* créer des ressources kind Namespace au cas où

## Reprendre le boulot 
* Démarrer le N150
* Attendre 5min
* `k get pods` pour voir sir k3s est lancé
* `k port-forward svc/argocd-server -n argocd 8081:443`
* Aller sur l'UI `http://localhost:8081`
* Bip-Boup

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

### 11. Déployer meta 

```bash
k create namespace meta
k apply -f argocd/apps-meta.yaml
```

-> Il devrait apparaitre sur l'UI et commencer à tout créer