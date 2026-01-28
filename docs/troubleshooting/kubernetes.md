# Kubernetes Issues

Troubleshooting Kubernetes-related problems.

## Connection Issues

### Unable to Connect

```bash
# Update kubeconfig
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1

# Verify
kubectl cluster-info
```

### Unauthorized

Check IAM credentials are valid:

```bash
aws sts get-caller-identity
```

## Pod Issues

### ImagePullBackOff

```bash
# Check events
kubectl describe pod -n tasky <pod-name>

# Check image exists
kubectl get deployment -n tasky -o yaml | grep image
```

### CrashLoopBackOff

```bash
# Check logs
kubectl logs -n tasky <pod-name>

# Check events
kubectl describe pod -n tasky <pod-name>
```

## Service Issues

### LoadBalancer Pending

```bash
# Check service
kubectl describe svc -n tasky tasky-service

# Check AWS load balancer
aws elbv2 describe-load-balancers
```
