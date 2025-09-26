# Monitoring Stack - Migration vers GitOps

### Port forward
```kubectl port-forward -n monitoring service/grafana 3000:80```
```kubectl port-forward -n monitoring service/prometheus-server 9090:80```

### Data Sources
- **Prometheus** : Automatiquement configuré sur `http://prometheus-server.monitoring.svc.cluster.local:80`

### Dashboards
Les dashboards suivants sont automatiquement importés :
- **Kubernetes Cluster Monitoring** (ID 315) : Surveillance générale du cluster
- **Kube-State-Metrics / Node Exporter** (ID 6417) : Métriques détaillées des nœuds et pods

## Persistance

### Grafana
- **Volume** : 5Gi PVC avec storage class `local-path`
- **Données sauvegardées** : Dashboards, datasources, utilisateurs, préférences

### Prometheus
- **Volume** : 10Gi PVC avec storage class `local-path`  
- **Rétention** : 15 jours de métriques
- **Alertmanager** : 2Gi PVC pour les alertes

## Structure des fichiers

```
monitoring/
├── README.md                           # Ce fichier
├── kustomization.yaml                  # Configuration Kustomize
├── prometheus.yaml                     # Application ArgoCD pour Prometheus
├── grafana.yaml                        # Application ArgoCD pour Grafana
├── kube-state-metrics.yaml            # Application ArgoCD pour kube-state-metrics
├── grafana-datasources-configmap.yaml # Configuration des datasources Grafana
└── grafana-dashboards-configmap.yaml  # Dashboards Grafana préconfigurés
```

## Avantages de cette approche GitOps

1. **Source de vérité** : Toute la configuration est versionnée dans Git
2. **Persistance** : Les données Grafana survivent aux redémarrages/crashes
3. **Reproductibilité** : Facile à déployer sur de nouveaux environnements
4. **Évolutivité** : Facile d'ajouter de nouveaux dashboards ou datasources
5. **Rollback** : Possibilité de revenir en arrière via Git

## Ajout de nouveaux dashboards

Pour ajouter un nouveau dashboard :

1. Exportez le JSON depuis Grafana UI
2. Créez un nouveau ConfigMap dans `grafana-dashboards-configmap.yaml`
3. Ajoutez le label `grafana_dashboard: "1"`
4. Commitez les changements - ArgoCD appliquera automatiquement

## Troubleshooting

### Grafana ne démarre pas
```bash
# Vérifier les logs
kubectl logs -n monitoring deployment/grafana

# Vérifier les PVC
kubectl describe pvc -n monitoring
```

### Dashboards manquants
```bash
# Vérifier les ConfigMaps
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# Redémarrer Grafana pour forcer le rechargement
kubectl rollout restart deployment/grafana -n monitoring
```

### Prometheus ne scrape pas
```bash
# Vérifier la configuration Prometheus
kubectl get configmap prometheus-server -n monitoring -o yaml

# Vérifier les targets dans Prometheus UI
# Status -> Targets
```
