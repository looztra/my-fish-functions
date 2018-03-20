function aws-ops -d 'switch to zenika-ops aws env vars'
    set -x AWS_ACCESS_KEY $AWS_OPS_ACCESS_KEY_ID
    set -x AWS_SECRET_KEY $AWS_OPS_SECRET_ACCESS_KEY
end

function aws-training -d 'switch to zenika-training aws env vars'
    set -x AWS_ACCESS_KEY $AWS_TRAINING_ACCESS_KEY_ID
    set -x AWS_SECRET_KEY $AWS_TRAINING_SECRET_ACCESS_KEY
end

function docker-images-tree -d 'Print docker images in a tree representation'
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock nate/dockviz images -t
end

function docker-clean-volumes-dry-run -d 'Print volumes that could be removed'
    docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes --dry-run
end

function docker-clean-volumes -d 'Remove volumes that could be removed'
    docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes
end

function docker-clean-old-containers -d 'Remove old stopped containers'
    docker ps -a | grep Exited | grep 'days ago' | awk '{print $1}' | xargs --no-run-if-empty docker rm -v
end

function docker-clean-dangling-images -d 'Remove dangling images'
    docker rmi (docker images --filter dangling=true --quiet)
end

function minikube-update -d 'Install latest minikube release'
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 ; and chmod +x minikube ; and mv minikube ~/.local/bin/
end

function kubectl-update -d 'Update kubectl to latest release'
    curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl ; and chmod +x kubectl ; and mv kubectl ~/.local/bin/
end

function compose-update -d 'Update docker-compose to version provided in param or latest release if no param provided'
    set compose_version (curl -s https://api.github.com/repos/docker/compose/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
      set compose_version $argv
    end
    echo "Retreiving docker-compose version $compose_version"
    echo "gna"
    curl -Lo ~/tmp/docker-compose https://github.com/docker/compose/releases/download/$compose_version/docker-compose-Linux-x86_64
    chmod +x ~/tmp/docker-compose ; and mv ~/tmp/docker-compose ~/.local/bin/
    which docker-compose
    docker-compose version
end

function machine-update -d 'Update docker-machine to version provided in param or latest release if no param provided'
    set machine_version (curl -s https://api.github.com/repos/docker/machine/releases/latest | jq .tag_name | tr -d '"')
    set version_type default
    if not test -z "$argv"
      set version_type forced
      set machine_version $argv
    end
    echo "Retreiving docker-machine version $machine_version ($version_type)"
    rm -f ~/tmp/docker-machine
    curl -Lo ~/tmp/docker-machine https://github.com/docker/machine/releases/download/$machine_version/docker-machine-Linux-x86_64
    chmod +x ~/tmp/docker-machine ; and mv ~/tmp/docker-machine ~/.local/bin/
    which docker-machine
    docker-machine version
end

function terraform-update -d 'Update terraform to latest release'
    set tf_version (curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq .tag_name | tr -d '"' | tr -d 'v')
    curl -Lo ~/tmp/terraform.latest.zip https://releases.hashicorp.com/terraform/{$tf_version}/terraform_{$tf_version}_linux_amd64.zip
    cd ~/tmp
    unzip ~/tmp/terraform.latest.zip
    chmod +x ~/tmp/terraform; and mv ~/tmp/terraform ~/.local/bin
    terraform version
end

