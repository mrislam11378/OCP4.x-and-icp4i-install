while true; 
  do
    kubectl -n default port-forward svc/docker-registry 5000:5000;
  done


