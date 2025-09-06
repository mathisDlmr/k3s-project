# Setup du projet

## TODO
* setup SFTP

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
sed -i 's/127.0.0.1/<ip>/' k3s.yaml
echo "KUBECONFIG=$(pwd)/k3s.yaml" >> ~/.bashrc
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

### 9. Déployer meta 

```bash
k create namespace meta
k apply -f argocd/apps-meta.yaml
```

-> Il devrait apparaitre sur l'UI

### 10. 