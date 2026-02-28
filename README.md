EKS Mega Project: Full-Stack Deployment (2026)
This repository contains the automation scripts and Kubernetes manifests to deploy a Java-based Bank Application with a MySQL backend on Amazon EKS.

Terraform Repository: TechPilotz Mega-Project-Terraform

🛠️ Phase 1: Environment Setup
Execute these commands on your Linux Management Server (Ubuntu recommended) to install the necessary CLI tools.

1. Install AWS CLI
Configure your credentials to allow Terraform and eksctl to interact with your AWS account.

Bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install
aws configure
2. Install Terraform
Provisions the VPC, Subnets, and EKS Cluster.

Bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(ls_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform -y
3. Install Kubectl & EKSCTL
kubectl manages the cluster, while eksctl simplifies IAM and OIDC configurations.

Bash
# Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# EKSCTL
curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
tar -xzf eksctl_$(uname -s)_amd64.tar.gz
sudo mv eksctl /usr/local/bin
🏗️ Phase 2: Cluster Provisioning & Authentication
4. Provision Infrastructure
Clone the repo and run Terraform.

Bash
git clone https://github.com/TechPilotz/Mega-Project-Terraform_2026.git
cd Mega-Project-Terraform_2026
terraform init
terraform apply --auto-approve
5. Update Kubeconfig
Connect your local kubectl to the newly created EKS cluster.

Bash
aws eks --region ap-south-1 update-kubeconfig --name techpilotz-cluster
kubectl get nodes
🔐 Phase 3: Add-ons & Identity Management (IRSA)
6. Associate OIDC Provider
Required for Kubernetes Service Accounts to assume AWS IAM Roles.

Bash
eksctl utils associate-iam-oidc-provider --region ap-south-1 --cluster techpilotz-cluster --approve
7. Setup EBS CSI Driver (Storage)
Allows Kubernetes to dynamically provision AWS EBS volumes for the MySQL database.

Bash
# Create IAM Service Account
eksctl create iamserviceaccount \
  --region ap-south-1 \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster techpilotz-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts

# Deploy Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.35"
8. Install Networking & Security
Bash
# NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml 

# Cert-Manager (For SSL/TLS)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
🚀 Phase 4: Application Deployment
Save the following as deployment.yaml and run kubectl apply -f deployment.yaml -n webapps.

Kubernetes Manifest (deployment.yaml)
YAML
apiVersion: v1
kind: Namespace
metadata:
  name: webapps
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: webapps
type: Opaque
data:
  MYSQL_ROOT_PASSWORD: VGVzdEAxMjM= # Decodes to Test@123
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: webapps
data:
  MYSQL_DATABASE: bankappdb
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: webapps
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: webapps
spec:
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - image: mysql:8
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_ROOT_PASSWORD
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: mysql-config
              key: MYSQL_DATABASE
        ports:
        - containerPort: 3306
        volumeMounts:
        - mountPath: /var/lib/mysql
          name: mysql-data
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: webapps
spec:
  ports:
  - port: 3306
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bankapp
  namespace: webapps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bankapp
  template:
    metadata:
      labels:
        app: bankapp
    spec:
      containers:
      - name: bankapp
        image: adijaiswal/bankapp:v6
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_DATASOURCE_URL
          value: jdbc:mysql://mysql-service:3306/bankappdb?useSSL=false&serverTimezone=UTC
        - name: SPRING_DATASOURCE_USERNAME
          value: root
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_ROOT_PASSWORD
---
apiVersion: v1
kind: Service
metadata:
  name: bankapp-service
  namespace: webapps
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: bankapp
🔍 Phase 5: Verification
Bash
# Check all resources in the namespace
kubectl get all -n webapps

# Get the external LoadBalancer URL
kubectl get svc bankapp-service -n webapps
