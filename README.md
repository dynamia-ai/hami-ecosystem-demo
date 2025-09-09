# HAMi Ecosystem Demo

A minimal, reproducible demo for running GPU workloads with HAMi on Kubernetes. Today it provisions AWS EKS with GPU node groups and installs HAMi via Helm; multi‑cloud modules (GCP/Azure/ACK) are in progress. Demo manifests cover vLLM Production Stack, Xinference, JupyterHub, and Volcano.

## Repository Structure

- `infra/aws`: Terraform to provision VPC + EKS and install HAMi
  - `infra/aws/main.tf:42`: EKS cluster with two GPU node groups labeled `accelerator: t4` and `accelerator: a10g`
  - `infra/aws/main.tf:119`: Installs HAMi Helm chart into `kube-system`
  - `infra/aws/variables.tf:1`: Region, cluster name/version, VPC CIDR
  - `infra/aws/outputs.tf:1`: Useful outputs including `kubectl_config_command`
- `demo/workloads`: Example vLLM Deployments + Services
  - `demo/workloads/a10g.yaml`: Mistral 7B AWQ and Qwen2.5 7B AWQ on A10G
  - `demo/workloads/t4.yaml`: Qwen2.5 1.5B on T4

## What Gets Created (AWS)

- VPC with public/private subnets and NAT
- EKS cluster with IRSA enabled, cluster addons (CoreDNS, kube-proxy, VPC CNI, EBS CSI)
- Two GPU node groups (on‑demand):
  - `g4dn.12xlarge` labeled `accelerator=t4`
  - `g5.12xlarge` labeled `accelerator=a10g`
- HAMi installed via Helm in `kube-system`

## Prerequisites

- Terraform ≥ 1.5
- AWS account + credentials with EKS/VPC permissions
- AWS CLI v2 configured (`aws sts get-caller-identity` works)
- kubectl
- (Optional) Helm locally if you want to manage charts outside Terraform

## Quick Start (AWS)

1) Initialize and apply

```
cd infra/aws
terraform init
terraform apply -auto-approve
```

2) Configure kubectl

Use the output to set kubeconfig:

```
terraform output -raw kubectl_config_command
# copy-paste the printed command to run it, e.g.:
aws eks update-kubeconfig --region us-west-2 --name hami-demo-aws
```

3) Verify cluster, HAMi, and GPU resources

```
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.hami\.io/node-nvidia-register}{"\n"}{end}'

# e.g.:
ip-10-0-xx-xxx.us-west-2.compute.internal	GPU-f8e75627-86ed-f202-cf2b-6363fb18d516,10,15360,100,NVIDIA-Tesla T4,0,true,0,hami-core:GPU-7f2003cf-a542-71cf-121f-0e489699bbcf,10,15360,100,NVIDIA-Tesla T4,0,true,1,hami-core:GPU-90e2e938-7ac3-3b5e-e9d2-94b0bd279cf2,10,15360,100,NVIDIA-Tesla T4,0,true,2,hami-core:GPU-2facdfa8-853c-e117-ed59-f0f55a4d536f,10,15360,100,NVIDIA-Tesla T4,0,true,3,hami-core:
ip-10-0-xx-xxx.us-west-2.compute.internal	GPU-bd5e2639-a535-7cba-f018-d41309048f4e,10,23028,100,NVIDIA-NVIDIA A10G,0,true,0,hami-core:GPU-06f444bc-af98-189a-09b1-d283556db9ef,10,23028,100,NVIDIA-NVIDIA A10G,0,true,1,hami-core:GPU-6385a85d-0ce2-34ea-040d-23c94299db3c,10,23028,100,NVIDIA-NVIDIA A10G,0,true,2,hami-core:GPU-d4acf062-3ba9-8454-2660-aae402f7a679,10,23028,100,NVIDIA-NVIDIA A10G,0,true,3,hami-core:
```

## Deploy Demo Workloads

Apply the sample deployments and services:

```
kubectl apply -f demo/workloads/a10g.yaml
kubectl apply -f demo/workloads/t4.yaml
```

Port-forward one service to test locally (vLLM OpenAI-compatible):

```
kubectl port-forward svc/vllm-a10g-mistral7b-awq 8000:8000
```

Test a simple chat completion:

```
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  --data-binary @- <<'JSON' | jq -r '.choices[0].message.content'
{
  "model": "solidrust/Mistral-7B-Instruct-v0.3-AWQ",
  "temperature": 0.3,
  "messages": [
    {
      "role": "user",
      "content": "Write a 3-sentence weekly update about improving GPU sharing on EKS with memory capping. Audience: non-technical executives."
    }
  ]
}
JSON
```

## Clean Up

```
cd infra/aws
terraform destroy -auto-approve
```

## Roadmap

- Multi‑cloud quick deploy: GCP (GKE), Azure (AKS), Alibaba Cloud (ACK), optional on‑prem (Cluster API)
- vLLM Production Stack demo: autoscaling (HPA/KEDA), model PVCs, gateway, telemetry
- Xinference demo: deploy server + sample models, OpenAI‑compatible endpoint, HAMi‑aware scheduling
- JupyterHub demo: GPU notebook profiles, per‑user limits/quotas, CUDA images
- Volcano integration: gang scheduling for multi‑GPU jobs, training/batch examples
- Observability & autoscaling: DCGM exporter, Prometheus/Grafana dashboards, cluster/node autoscaler

## License

MIT
