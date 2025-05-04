#!/bin/bash

BACKUP_DIR=~/k8s-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml"
kubectl get crd -o yaml > "$BACKUP_DIR/crds.yaml"

kubectl get pods --all-namespaces -o jsonpath="{..image}" | \
tr -s '[[:space:]]' '\n' | sort | uniq > "$BACKUP_DIR/image-list.txt"

mkdir -p "$BACKUP_DIR/images"
while read img; do
  fname=$(echo "$img" | sed 's|[/:]|_|g')
  docker pull "$img"
  docker save -o "$BACKUP_DIR/images/${fname}.tar" "$img"
done < "$BACKUP_DIR/image-list.txt"

tar czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
echo "[✅] 백업 완료: $BACKUP_DIR.tar.gz"
