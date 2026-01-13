# TODO

## FIX

- [ ] Pourquoi n'y a t il pas de métriques du node worker ?

## CHORE

- [ ] Redéfinir les resources
- [ ] Définir taint et tolérations :
  - Prom, Grafana, AlertManager, CronJobs Skiut c'est sur le worker
- [ ] Définir liveness et readiness probes
- [ ] Redirection skiut.mdlmr.fr -> skiut.mdlmr.fr/skiutc et idem pour nimportequoi.mdlmr.fr -> mdlmr.fr
- [ ] Mieux ranger les serviceMonitor :
  - Sois les supprimer
  - Sois les deployer dans leur namespace concerné
  - Et voir si il n'y a pas d'autres serviceMonitor sympa à deploy
- [ ] Voir pour parser les templates de value Helm (Traefik, Alloy, Loki, etc.) avec un LLM et voir ce qu'il peut etre interessant à garder
- [ ] Globalement mieux ranger monitoring entre chart helm, overload de config, dashboards, etc.
- [ ] Définir des kustomization.yaml partout ou nul part

## FEAT

- [ ] Voir pour des métriques sur tous les services : loki, tempo, traefik, etc.
- [ ] Dashboards Grafana ArgoCD, Cloudflare, Traefik...
- [ ] Redis global (app "utils")
- [ ] ELK pour se former dessus en parallèle (app "monitoring-v2")
- [ ] OTel en parallele de Alloy (et pour log/metrics/traces Filebeat, metricbeat, APM server) (app "monitoring-v2")
- [ ] Kubernetes dashboard
- [ ] Sysdig et/ou Falco et/ou trivy operator (app "security")
- [ ] Configuration Alloy boostée aux hormones : https://grafana.com/docs/opentelemetry/collector/grafana-alloy/
- [ ] Minio et/ou Longhorn et/ou Ceph pour du stockage S3 et des PV dynamiques (app "utils")
- [ ] TFA avec Google (https://mattdyson.org/blog/2024/02/using-traefik-with-cloudflare-tunnels/) ou Keycloak
- [ ] Serveur ski'ut en nodejs
- [ ] Templatiser Ski'ut en Helm, surtout pour injecter les env
- [ ] Kargo
- [ ] Chaos Mesh, Kubecost, kube-resource-report, kube-bench, etc.
- [ ] Uptime Kuma
- [ ] Registry Harbor
- [ ] Gitea
- [ ] Hosting
- [ ] External DNS

## TODO - Website

- [ ] Ajuster le shadow violet sur les techno
- [ ] Ajouter un filtre sur les projets
- [ ] Mettre à jour les liens, descriptions, langages... dans les projects
- [ ] Proposer plusieurs screens/pdf de chaque projet
