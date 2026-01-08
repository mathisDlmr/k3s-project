#!/usr/bin/env bash
set -euo pipefail

CP_NODE_NAME="master"
CLOUDFLARE_TUNNEL_TOKEN=""
CLOUDFLARE_API_TOKEN=""

# ---------------------------
# 0. Vérification des variables
# ---------------------------
echo "[0/10] Vérification des variables..."
for var in CLOUDFLARE_TUNNEL_TOKEN CLOUDFLARE_API_TOKEN; do
  if [ -z "${!var}" ]; then
    echo "Erreur : la variable $var n'est pas définie"
    exit 1
  fi
done

# ---------------------------
# 1. Configuration réseau
# ---------------------------
echo "[1/10] Configuration réseau..."

if ping -c1 1.1.1.1 &>/dev/null; then
  echo "Réseau déjà configuré, passage à l'étape suivante."
else
  read -p "Voulez-vous configurer le wifi ou ethernet ? (w/e) " NET_CHOICE

  if [ "$NET_CHOICE" == "w" ]; then
    read -p "Nom du wifi : " WIFI_NAME
    read -p "Mot de passe du wifi : " WIFI_PASSWORD
    sudo tee /etc/netplan/00-config.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  wifis:
    wlp1s0:
      dhcp4: true
      access-points:
        "$WIFI_NAME":
          password: "$WIFI_PASSWORD"
EOF

    sudo netplan generate
    sudo netplan apply
    ip a
  elif [ "$NET_CHOICE" == "e" ]; then
    sudo tee /etc/netplan/00-config.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      dhcp4: true
EOF

    sudo netplan generate
    sudo netplan apply
    ip a
  else
    echo "Choix invalide. Sortie du script."
    exit 1
  fi
fi

echo "En attente de la connexion au réseau..."
while ! ping -c1 1.1.1.1 &>/dev/null; do
  sleep 1
done

# ---------------------------
# 2. SSH
# ---------------------------
echo "[2/10] Installation SSH..."
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# ---------------------------
# 3. Firewall
# ---------------------------
echo "[3/10] Activation firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 6443/tcp
sudo ufw enable

# ---------------------------
# 4. Tailscale + récupération IP
# ---------------------------
sudo apt install -y tailscale
sudo systemctl enable --now tailscaled
echo "Connectez-vous à Tailscale (tailscale up --ssh)..."
sudo tailscale up --ssh
TAILSCALE_IP=$(tailscale ip -4)
echo "IP Tailscale détectée : $TAILSCALE_IP"

# ---------------------------
# 5. K3S Control-plane
# ---------------------------
curl -sfL https://get.k3s.io | sh -s - server \
  --node-name "$CP_NODE_NAME" \
  --tls-san 127.0.0.1 \
  --tls-san localhost \
  --tls-san "$TAILSCALE_IP" \
  --disable traefik

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/token)

# ---------------------------
# 6. Worker node
# ---------------------------
USE_WORKER="N"
read -p "Voulez-vous ajouter un worker ? (y/N) " USE_WORKER
if [ "$USE_WORKER" == "y" ]; then
  read -p "Nom du worker : " WORKER_NODE_NAME
  echo "Pour ajouter le worker, connectez-vous au worker et lancez :"
  echo "./setup-worker.sh --cp-ip $TAILSCALE_IP --token $K3S_TOKEN --node-name $WORKER_NODE_NAME"
  read -p "Appuyez sur Entrée quand le worker est ajouté pour continuer..."
fi

# ---------------------------
# 7. ArgoCD
# ---------------------------
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
kubectl -n argocd port-forward svc/argocd-server 8081:443 &

echo "Déploiement de apps-meta.yaml..."
kubectl apply -f ./argocd/apps-meta.yaml

# ---------------------------
# 8. SealedSecrets
# ---------------------------
KUBESEAL_VERSION="0.34.0"
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal

echo "Attente que le pod sealed-secrets-controller soit prêt..."
kubectl wait --for=condition=Ready pod -l name=sealed-secrets-controller -n kube-system --timeout=120s

# ---------------------------
# 9. Secrets Cloudflare
# ---------------------------
echo "[Création des secrets Cloudflare...]"

mkdir -p ./infra/cloudflared

cat > ./infra/cloudflared/cloudflare-api-token-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: infra
type: Opaque
data:
  api-token: $(echo -n "$CLOUDFLARE_API_TOKEN" | base64)
EOF

cat > ./infra/cloudflared/cloudflare-tunnel-token-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-tunnel-token-secret
  namespace: infra
type: Opaque
data:
  token: $(echo -n "$CLOUDFLARE_TUNNEL_TOKEN" | base64)
EOF

# ---------------------------
# 10. Inotify config for log collection
# ---------------------------
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=512
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances = 512" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "Chiffrement des secrets avec kubeseal..."
kubeseal --controller-namespace infra --controller-name sealed-secrets --format yaml < ./infra/cloudflared/cloudflare-api-token-secret.yaml > ./infra/cloudflared/cloudflare-api-token-sealed-secret.yaml
kubeseal --controller-namespace infra --controller-name sealed-secrets --format yaml < ./infra/cloudflared/cloudflare-tunnel-token-secret.yaml > ./infra/cloudflared/cloudflare-tunnel-token-sealed-secret.yaml
git add infra/cloudflared/cloudflare-api-token-sealed-secret.yaml infra/cloudflared/cloudflare-tunnel-token-sealed-secret.yaml
git commit -m "chore(infra: cloudflare): roll cloudflare sealed-secrets with new encryption key"
git push

echo "Setup terminé !"
echo "Accès ArgoCD UI: http://localhost:8081 (login: admin, mot de passe $ARGOCD_PWD)"
echo "Pour accéder au control-plane depuis votre pc, faites le rejoindre le réseau Tailscale et ajouter dans ~/.kube/config : "
cat $KUBECONFIG
