#!/bin/bash

# ===[ 설정 ]===
BACKUP_DIR=~/k8s-backup-$(date +%Y%m%d-%H%M%S)
IMAGE_LIST_FILE="$BACKUP_DIR/k8s-images.txt"

mkdir -p "$BACKUP_DIR/images"
echo "[INFO] 백업 디렉토리 생성: $BACKUP_DIR"

# ===[ 1. K8s 리소스 백업 ]===
echo "[INFO] 쿠버네티스 리소스 백업 중..."

kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml"
kubectl get crd -o yaml > "$BACKUP_DIR/crds.yaml"
kubectl get nodes -o yaml > "$BACKUP_DIR/nodes.yaml"
kubectl get storageclass -o yaml > "$BACKUP_DIR/storageclasses.yaml"
kubectl get clusterrolebindings,clusterroles -o yaml > "$BACKUP_DIR/cluster_roles.yaml"

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  mkdir -p "$BACKUP_DIR/namespaces/$ns"
  kubectl get all --namespace="$ns" -o yaml > "$BACKUP_DIR/namespaces/$ns/all.yaml"
  kubectl get configmap,secret,pvc,ingress,deployment,statefulset,daemonset,job,cronjob \
    --namespace="$ns" -o yaml > "$BACKUP_DIR/namespaces/$ns/extended.yaml"
done

# ===[ 2. 사용 중인 Docker 이미지 목록 추출 ]===
echo "[INFO] 사용 중인 Docker 이미지 목록 추출 중..."

kubectl get pods --all-namespaces -o jsonpath="{..image}" | \
  tr -s '[[:space:]]' '\n' | sort | uniq > "$IMAGE_LIST_FILE"

echo "[INFO] 추출된 이미지 목록:"
cat "$IMAGE_LIST_FILE"

# ===[ 3. 이미지 tar로 저장 ]===
echo "[INFO] Docker 이미지 tar 백업 중..."

while read img; do
  safe_name=$(echo "$img" | sed 's|[/:]|_|g')
  echo "  → $img → $safe_name.tar"
  docker pull "$img"
  docker save -o "$BACKUP_DIR/images/${safe_name}.tar" "$img"
done < "$IMAGE_LIST_FILE"

# ===[ 4. 최종 압축 ]===
cd "$(dirname "$BACKUP_DIR")"
tar -czf "$(basename "$BACKUP_DIR").tar.gz" "$(basename "$BACKUP_DIR")"

echo "[✅ 완료] 전체 백업 압축 파일: $(basename "$BACKUP_DIR").tar.gz"
