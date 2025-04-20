kubectl get pod -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.podIP}{'\t'}{.metadata.labels.role}{'\t'}{.spec.nodeName}{'\n'}" | \
grep -v "control-plane" | \
while read line; do
  # Ignore les lignes vides
  if [ -z "$line" ]; then
    continue
  fi
  
  pod_name=$(echo $line | awk '{print $1}')
  pod_ip=$(echo $line | awk '{print $2}')
  pod_role=$(echo $line | awk '{print $3}')
  node_name=$(echo $line | awk '{print $4}')

  # Vérifier si le nœud est en cours d'exécution
  pod_status=$(kubectl get pods $pod_name | awk 'NR == 2 {print $3}')

  # Récupérer le statut du nœud
  node_status=$(kubectl get nodes $node_name | awk 'NR == 2 {print $2}')
  
  # Affichage des informations du pod et du nœud
  echo -e "$pod_name\t$pod_status\t\t$pod_ip\t$pod_role\t\t$node_name\t$node_status"
done
