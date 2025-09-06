# K3S Project

## Introduction

Hello !

Ce projet a pour objectif de monter un mini-cluster k3s sur un N150 pour permettre d'héberger quelques applications de base, mais en fournissant une **infra résiliante**, qui **se scale** en fonction de la demande, et qui profite **d'intégration CI/CD**

Concrètement, les applications qui seront hebergées sur ce cluster sont : 
* Un registry personnel harbor
* Un serveur de dev/staging pour l'association Ski'ut
  * Serveur Laravel
  * BDD MySql
  * Interfaces de monitoring, metrics, PhpMyAdmin...
* Un projet d'hébergement web gratuit pour les étudiant.e.s de l'UTC
  * Pouvant héberger des sites statiques servis par un nginx
  * Ou des web-app dockerisées déployés par des templates Helm

Niveau techno, on sera principalement sur du :
* k3s
* Helm
* argoCD
* GitHub Actions / GitLab CI
* Traefik
* cert-manager
* Loki

## Organisation du projet

```bash
k3s-project/
├── infra/                      # Pile infra transversale
│   ├── ingress/                # IngressController traefik
│   │   └── values.yaml
│   ├── cert-manager/
│   │   └── values.yaml
│   ├── monitoring/             # kube-prometheus-stack, Grafana, Loki (ou EFK mais un peu overkill)
│   │   └── values.yaml
│   ├── metrics-server/
│   │   └── values.yaml
│   └── kustomization.yaml
│
├── registry/                   # Harbor (prendre un chart officiel)
│   ├── values.yaml
│   └── kustomization.yaml
│
├── apps/
│   ├── skiut/
│   │   ├── base/
│   │   │   ├── values.yaml
│   │   │   ├── mysql-values.yaml
│   │   │   └── grafana-dashboard.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       │   └── values.yaml
│   │       └── prod/
│   │           └── values.yaml
│   │
│   ├── hosting/
│   │   ├── static/             # Router statique nginx
│   │   │   └── values.yaml
│   │   ├── dockerized/         # web-apps dockerisées
│   │   │   └── template-values.yaml
│   │   └── overlays/
│   │       └── prod/
│   │           └── values.yaml
│   │
│   └── kustomization.yaml
│
├── argocd/
│   ├── app-of-apps-meta.yaml   # Application "Meta" (App-of-Apps)
│   └── apps-hosting.yaml   # Application enfant Hébergement
│
├── meta/
│   ├── apps-infra.yaml         # Applications enfants pour l'infra
│   ├── apps-registry.yaml      # Application enfant pour Harbor
│   ├── apps-skiut.yaml         # Application enfant SkiUt
│   └── apps-hosting.yaml   # Application enfant Hébergement
│
└── charts/
    ├── skiut/
    └── hosting/
```

## Brouillon d'infra

```bash
Meta
├── infra
│   ├── ingress-controller
│   ├── cert-manager
│   ├── monitoring
│   ├── metrics
│   └── (opt.) logging / external-dns
│
├── registry
│   └── harbor
│
├── skiut
│   ├── web-backend                      # Deployment Laravel + HPA + PDB
│   ├── mysql-database                   # StatefulSet MySQL + PVC
│   ├── redis-cache                      # opt.
│   ├── workers-queue / cron / workflow  # opt.
│   └── monitoring-skiut                 # ServiceMonitor, dashboards
│ 
└── hosting
    ├── static-sites
    │   └── nginx-router    # sert les HTML/CSS/JS
    └── dockerized-apps     # A un niveau supérieur il peut être intéressant de créer un ApplicationSet pour fournir un BDD + interface UI
        ├── app-template    # template/chart pour 1 app
        ├── app1
        └── app2
```

---

<div style="display: flex; justify-content: space-evenly; align-items: center;">
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linux/linux-original.svg" height="50" alt="Linux" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/bash/bash-original.svg" height="50" alt="Shell" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/git/git-original.svg" height="50" alt="Git" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/docker/docker-original.svg" height="50" alt="Docker" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/kubernetes/kubernetes-plain.svg" height="50" alt="Kubernetes" /> 
  <img src="https://www.redhat.com/rhdc/managed-files/helm.svg" height="50" alt="Helm" /> 
  <img src="https://cdn.prod.website-files.com/5f10ed4c0ebf7221fb5661a5/5f2ba11e378c8f49e8b28486_argo.png" height="50" alt="argoCD" /> 
  <img src="https://miro.medium.com/v2/resize:fit:1500/1*7qk0-4XwCKWQO0GU5Hu39w.png" height="50" alt="GitHub Actions" /> 
  <img src="https://forge.inrae.fr/uploads/-/system/project/avatar/6031/gitlab-ci.png" height="50" alt="GitLab CI/CD" /> 
  <img src="https://aperogeek.fr/wp-content/uploads/2016/08/traefik.logo_.png" height="50" alt="Traefik" /> 
  <img src="https://raw.githubusercontent.com/cert-manager/cert-manager/d53c0b9270f8cd90d908460d69502694e1838f5f/logo/logo-small.png" height="50" alt="cert-manager" /> 
  <img src="https://loki-operator.dev/logo.png" height="50" alt="Loki" /> 
</div>