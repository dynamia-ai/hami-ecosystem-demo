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
replicas: 4
```

**Expected Behavior**: All 4 pods scheduled on the same node, sharing GPUs with binpack strategy
**Test Result**:

```
POD                                               NODE                                       UUIDS
demo-a-node-binpack-gpu-binpack-6899f6dfdd-8z8rx  ip-10-0-52-161.us-west-2.compute.internal  GPU-b0e94721-ad7c-6034-4fc8-9f0d1ac7d60d
demo-a-node-binpack-gpu-binpack-6899f6dfdd-dtx7b  ip-10-0-52-161.us-west-2.compute.internal  GPU-85caf98e-de2d-1350-ed83-807af940c199
demo-a-node-binpack-gpu-binpack-6899f6dfdd-nfbz4  ip-10-0-52-161.us-west-2.compute.internal  GPU-b0e94721-ad7c-6034-4fc8-9f0d1ac7d60d
demo-a-node-binpack-gpu-binpack-6899f6dfdd-wtd47  ip-10-0-52-161.us-west-2.compute.internal  GPU-85caf98e-de2d-1350-ed83-807af940c199
```

✅ **Result**: All 4 pods on same node (`ip-10-0-52-161`) sharing 2 GPUs (2 pods per GPU)

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
POD                                              NODE                                       UUIDS
demo-b-node-spread-gpu-binpack-548cb55c7d-8tg22  ip-10-0-52-161.us-west-2.compute.internal  GPU-dedbdfb2-408f-9ded-402f-e3dc22c08f66
demo-b-node-spread-gpu-binpack-548cb55c7d-h9ds6  ip-10-0-61-248.us-west-2.compute.internal  GPU-5f432a79-775e-db04-1e15-82307fdb5a1b
demo-b-node-spread-gpu-binpack-548cb55c7d-ncwdl  ip-10-0-61-248.us-west-2.compute.internal  GPU-5f432a79-775e-db04-1e15-82307fdb5a1b
demo-b-node-spread-gpu-binpack-548cb55c7d-stx67  ip-10-0-52-161.us-west-2.compute.internal  GPU-dedbdfb2-408f-9ded-402f-e3dc22c08f66
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
POD                                             NODE                                       UUIDS
demo-c-node-binpack-gpu-spread-d5f686b67-8zbz9  ip-10-0-61-248.us-west-2.compute.internal  GPU-041286d5-ed3d-4823-096e-a4c80fe17fb9
demo-c-node-binpack-gpu-spread-d5f686b67-hn2md  ip-10-0-61-248.us-west-2.compute.internal  GPU-b639414c-f867-90c3-dd3b-a2bd094a703e
demo-c-node-binpack-gpu-spread-d5f686b67-rrpzb  ip-10-0-61-248.us-west-2.compute.internal  GPU-4bfe5899-5368-2e73-de03-d34894b6d75c
demo-c-node-binpack-gpu-spread-d5f686b67-sv8fg  ip-10-0-61-248.us-west-2.compute.internal  GPU-5f432a79-775e-db04-1e15-82307fdb5a1b
```

✅ **Result**: All 4 pods on same node (`ip-10-0-61-248`) using 4 different GPUs

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
demo-d-node-spread-gpu-spread-c4555d97c-5gqkf  ip-10-0-52-161.us-west-2.compute.internal  GPU-b0e94721-ad7c-6034-4fc8-9f0d1ac7d60d
demo-d-node-spread-gpu-spread-c4555d97c-666dc  ip-10-0-61-248.us-west-2.compute.internal  GPU-5f432a79-775e-db04-1e15-82307fdb5a1b
demo-d-node-spread-gpu-spread-c4555d97c-8xjbh  ip-10-0-61-248.us-west-2.compute.internal  GPU-4bfe5899-5368-2e73-de03-d34894b6d75c
demo-d-node-spread-gpu-spread-c4555d97c-k727x  ip-10-0-52-161.us-west-2.compute.internal  GPU-dedbdfb2-408f-9ded-402f-e3dc22c08f66
```

✅ **Result**: Pods spread across 2 nodes, with 2 pods per node using different GPUs

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
3. **Node Distribution**: Node spread policy effectively distributes pods across multiple nodes when resources are available
4. **GPU Sharing**: Binpack GPU policy successfully shares GPUs between multiple pods when memory allows

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
