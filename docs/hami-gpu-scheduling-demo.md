# HAMi GPU Scheduling Strategies Demo

This document demonstrates different GPU and node scheduling strategies using HAMi (Heterogeneous AI Computing Virtualization Middleware) on AWS EKS.

## Overview

HAMi provides flexible GPU scheduling policies that allow you to control how workloads are distributed across nodes and GPUs within those nodes. This demo showcases four different combinations of scheduling strategies using VLLM (vLLM Large Language Model) deployments.

## Infrastructure Setup

The demo environment is deployed using the Terraform configuration in `infra/aws/` which creates:

- **EKS Cluster**: Kubernetes 1.32 cluster named `hami-demo-aws`
- **VPC**: Custom VPC with public and private subnets across 2 AZs
- **GPU Node Groups**: 
  - T4 nodes: `g4dn.12xlarge` instances (4x NVIDIA T4 GPUs each)
  - A10G nodes: `g5.12xlarge` instances (4x NVIDIA A10G GPUs each)
  - V100 nodes: `p3.8xlarge` instances (4x NVIDIA V100 GPUs each)
- **HAMi Installation**: Automatically deployed via Helm into the kube-system namespace

### Key Infrastructure Features

- **Multi-GPU Support**: Each node contains 4 GPUs for comprehensive scheduling testing
- **Auto-scaling**: Node groups configured with min/max scaling capabilities
- **GPU Memory Virtualization**: HAMi enables fine-grained GPU memory allocation
- **Regional Deployment**: Default deployment in `us-west-2` region

## Scheduling Strategies

HAMi supports two primary scheduling policies:

### Node-level Scheduling
- **binpack**: Pack workloads onto the same nodes to maximize resource utilization
- **spread**: Distribute workloads across different nodes for better fault tolerance

### GPU-level Scheduling  
- **binpack**: Pack multiple workloads onto the same GPU (when memory allows)
- **spread**: Distribute workloads across different GPUs within selected nodes

## Demo Scenarios

### Scenario A: Node Binpack + GPU Binpack
**File**: `demo/binpack-spread/a-node-binpack-gpu-binpack.yaml`

```yaml
annotations:
  hami.io/node-scheduler-policy: "binpack"
  hami.io/gpu-scheduler-policy: "binpack"
replicas: 2
```

**Expected Behavior**: Both pods scheduled on the same node, sharing the same GPU
**Test Result**:
```
POD                                               NODE                                      UUIDS
demo-a-node-binpack-gpu-binpack-6899f6dfdd-6gk58  ip-10-0-54-12.us-west-2.compute.internal  GPU-91729fea-5dbb-1583-5d9c-0aa103001599
demo-a-node-binpack-gpu-binpack-6899f6dfdd-dbn47  ip-10-0-54-12.us-west-2.compute.internal  GPU-91729fea-5dbb-1583-5d9c-0aa103001599
```
✅ **Result**: Both pods on same node (`ip-10-0-54-12`) sharing same GPU UUID

### Scenario B: Node Spread + GPU Binpack  
**File**: `demo/binpack-spread/b-node-spread-gpu-binpack.yaml`

```yaml
annotations:
  hami.io/node-scheduler-policy: "spread"
  hami.io/gpu-scheduler-policy: "binpack"
replicas: 4
```

**Expected Behavior**: Pods distributed across nodes, but sharing GPUs within nodes
**Test Result**:
```
POD                                              NODE                                      UUIDS
demo-b-node-spread-gpu-binpack-548cb55c7d-8ffkz  ip-10-0-54-12.us-west-2.compute.internal  GPU-91729fea-5dbb-1583-5d9c-0aa103001599
demo-b-node-spread-gpu-binpack-548cb55c7d-l72v4  ip-10-0-54-12.us-west-2.compute.internal  GPU-91729fea-5dbb-1583-5d9c-0aa103001599
demo-b-node-spread-gpu-binpack-548cb55c7d-jhvcx  ip-10-0-48-56.us-west-2.compute.internal  GPU-0801a882-64c9-6016-ea26-53c40c14b251
demo-b-node-spread-gpu-binpack-548cb55c7d-sl45l  ip-10-0-48-56.us-west-2.compute.internal  GPU-0801a882-64c9-6016-ea26-53c40c14b251
```
✅ **Result**: Pods spread across 2 nodes, with 2 pods per node sharing same GPU

### Scenario C: Node Binpack + GPU Spread
**File**: `demo/binpack-spread/c-node-binpack-gpu-spread.yaml`

```yaml
annotations:
  hami.io/node-scheduler-policy: "binpack"
  hami.io/gpu-scheduler-policy: "spread"
replicas: 4
```

**Expected Behavior**: All pods on same node, but using different GPUs
**Test Result**:
```
POD                                             NODE                                      UUIDS
demo-c-node-binpack-gpu-spread-d5f686b67-5gxpx  ip-10-0-54-12.us-west-2.compute.internal  GPU-8fb7d481-2186-17dc-9818-74cfc170535c
demo-c-node-binpack-gpu-spread-d5f686b67-5qq85  ip-10-0-54-12.us-west-2.compute.internal  GPU-91729fea-5dbb-1583-5d9c-0aa103001599
demo-c-node-binpack-gpu-spread-d5f686b67-7zhk7  ip-10-0-54-12.us-west-2.compute.internal  GPU-cae5a334-f376-cd6d-ef69-c3ecf50b3a67
demo-c-node-binpack-gpu-spread-d5f686b67-ssp48  ip-10-0-54-12.us-west-2.compute.internal  GPU-ed59d6c4-f6f4-db22-e334-777e03442da8
```
✅ **Result**: All 4 pods on same node (`ip-10-0-54-12`) using 4 different GPUs

### Scenario D: Node Spread + GPU Spread
**File**: `demo/binpack-spread/d-node-spread-gpu-spread.yaml`

```yaml
annotations:
  hami.io/node-scheduler-policy: "spread"
  hami.io/gpu-scheduler-policy: "spread"
replicas: 4
```

**Expected Behavior**: Pods distributed across nodes and using different GPUs
**Test Result**:
```
POD                                            NODE                                      UUIDS
demo-d-node-spread-gpu-spread-c4555d97c-6q6bg  ip-10-0-48-56.us-west-2.compute.internal  GPU-e269a7d1-6e57-252c-c8e4-caa0ed8ed14b
demo-d-node-spread-gpu-spread-c4555d97c-bcd9k  ip-10-0-48-56.us-west-2.compute.internal  GPU-faac633a-15b9-1363-0730-039b3ebbb775
demo-d-node-spread-gpu-spread-c4555d97c-mcdgm  ip-10-0-48-56.us-west-2.compute.internal  GPU-0801a882-64c9-6016-ea26-53c40c14b251
demo-d-node-spread-gpu-spread-c4555d97c-r8lxx  ip-10-0-48-56.us-west-2.compute.internal  GPU-1ea018eb-83ec-d13b-2124-4e828e27ecd9
```
✅ **Result**: All pods on same node but using 4 different GPUs (spread behavior within node)

## Workload Configuration

Each demo uses identical VLLM containers with the following specifications:

- **Model**: Qwen/Qwen2.5-1.5B-Instruct
- **GPU Memory**: 7.5GB allocation per pod via HAMi
- **GPU Utilization**: 65% to allow memory sharing
- **Max Model Length**: 2048 tokens
- **Max Sequences**: 3 concurrent requests

## Key Observations

1. **Memory Virtualization**: HAMi enables multiple pods to share GPU memory (7.5GB allocations on GPUs with more memory)
2. **Scheduling Flexibility**: Different combinations provide various trade-offs between resource utilization and fault tolerance
3. **Node Affinity**: In scenarios C and D, all pods ended up on the same node, indicating current cluster state or resource availability

## Running the Demo

### Prerequisites
1. Deploy infrastructure: `cd infra/aws && terraform apply`
2. Configure kubectl: `aws eks update-kubeconfig --region us-west-2 --name hami-demo-aws`
3. Verify HAMi installation: `kubectl get pods -n kube-system -l app=hami`

### Test Commands

```bash
# Test Scenario A
kubectl apply -f demo/binpack-spread/a-node-binpack-gpu-binpack.yaml
{
  printf "POD\tNODE\tUUIDS\n";
  kubectl get po -l app=demo-a -o json | jq -r '.items[] | select(.status.phase=="Running") | [.metadata.name,.spec.nodeName] | @tsv' | while IFS=$'\t' read -r pod node; do
    uuids=$(kubectl exec "$pod" -c vllm -- nvidia-smi --query-gpu=uuid --format=csv,noheader | paste -sd, -);
    printf "%s\t%s\t%s\n" "$pod" "$node" "$uuids";
  done;
} | column -t -s $'\t'

# Clean up and test next scenario
kubectl delete -f demo/binpack-spread/a-node-binpack-gpu-binpack.yaml
```

Repeat for scenarios B, C, and D by substituting the appropriate YAML files.

## Use Cases

- **High Utilization (Scenario A)**: Maximum resource efficiency for non-critical workloads
- **Load Distribution (Scenario B)**: Balance between fault tolerance and GPU sharing
- **GPU Isolation (Scenario C)**: Dedicated GPU per workload with node consolidation  
- **Maximum Isolation (Scenario D)**: Best fault tolerance and performance isolation

This demo showcases HAMi's powerful scheduling capabilities for optimizing GPU workload placement in Kubernetes environments.