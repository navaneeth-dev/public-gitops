public-gitops

Production public servics GitOps Kubernetes HA.

1st Server Node:

```bash
curl -sfL https://get.k3s.io | sh -s - server \
    --cluster-init \
    --tls-san=10.0.0.2 \
    --cluster-cidr=10.42.0.0/16,fd12:cafe:42::/56 --service-cidr=10.43.0.0/16,fd12:cafe:43::/112
```

Join Servers:

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=TOKEN_HERE sh -s - server \
    --server https://10.0.0.52:6443 \
    --tls-san=10.0.0.2 \
    --cluster-cidr=10.42.0.0/16,fd12:cafe:42::/56 --service-cidr=10.43.0.0/16,fd12:cafe:43::/112
```

