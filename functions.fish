function execute
    if test (count $argv) -eq 0
        return 0
    end
    if which $argv[1] > /dev/null
        eval $argv
        return $status
    else
        return 1
    end
end

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
    execute minikube version > /dev/null ^ /dev/null
    if test $status -eq 0
        set current_version (minikube version | cut -d " " -f 3)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "Minikube is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
      set target_version $argv
    end
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        curl -Lo minikube https://github.com/kubernetes/minikube/releases/download/{$target_version}/minikube-linux-amd64 ; and chmod +x minikube ; and mv minikube ~/.local/bin/
        execute minikube version > /dev/null ^ /dev/null
        if test $status -eq 0
            echo "Installed version "(minikube version | cut -d " " -f 3)
        else
            echo "Minikube could not be installed, check logs"
        end
    end
end

function minishift-update -d 'Install latest minishift release'
    execute minishift version > /dev/null ^ /dev/null
    if test $status -eq 0
        set current_version (minishift version | cut -d "+" -f 1 | cut -d " " -f 2)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "Minishift is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/minishift/minishift/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
      set target_version $argv
    end
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        curl -Lo $HOME/tmp/minishift.tgz https://github.com/minishift/minishift/releases/download/{$target_version}/minishift-{$target_version_short}-linux-amd64.tgz ; \
            and tar --directory $HOME/tmp -xf $HOME/tmp/minishift.tgz ; \
            and chmod +x $HOME/tmp/minishift-{$target_version_short}-linux-amd64/minishift
            and mv $HOME/tmp/minishift-{$target_version_short}-linux-amd64/minishift ~/.local/bin/ ; \
            and rm -rf $HOME/tmp/minishift-{$target_version_short}-linux-amd64 $HOME/tmp/minishift.tgz
        execute minishift version > /dev/null ^ /dev/null
        if test $status -eq 0
            echo "Installed version "(minishift version | cut -d "+" -f 1 | cut -d " " -f 2)
        else
            echo "minishift could not be installed, check logs"
        end
    end
end

function kubectl-update -d 'Update kubectl to latest release'
    set -l binary kubectl
    set -l binary_artifact $binary
    set -l tmpdir (mktemp -d)
    set -l binary_version_cmd $binary version --client --short
    set -l version_url https://storage.googleapis.com/kubernetes-release/release/stable.txt
    function compute_artifact_url
      set -l t_version $argv[1]
      set -l t_artifact $argv[2]
      printf "https://storage.googleapis.com/kubernetes-release/release/$t_version/bin/linux/amd64/$t_artifact"
    end
    #
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (execute $binary_version_cmd | cut -d " " -f 3)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "$binary is not installed yet"
    end
    set target_version (curl -s $version_url)
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest ($target_version)"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        echo "target_url "(compute_artifact_url $target_version $binary_artifact)
        curl -Lo $tmpdir/$binary (compute_artifact_url $target_version $binary_artifact)
        and chmod +x $tmpdir/$binary
        and mv $tmpdir/$binary ~/.local/bin/
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | cut -d " " -f 3)
        else
            echo "$binary could not be installed, check logs"
        end
    end
    rm -rf $tmpdir
end

function oc-update -d 'Update oc to latest release'
    set -l binary oc
    set -l binary_artifact {$binary}.tar.gz
    set -l tmpdir (mktemp -d)
    mkdir -p $tmpdir/untar
    set -l binary_version_cmd $binary version
    #
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (execute $binary_version_cmd | head -n 1 | cut -d " " -f 2)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "$binary is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/openshift/origin/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest ($target_version)"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set -l target_artifact_path (curl -s https://api.github.com/repos/openshift/origin/releases/latest | jq '.assets[1].name' | tr -d '"')
        set -l target_artifact_archive_dir (echo $target_artifact_path | cut -d "." -f 1-3)
        set -l target_url https://github.com/openshift/origin/releases/download/{$target_version}/{$target_artifact_path}
        echo "target_url $target_url"
        curl -Lo $tmpdir/$binary_artifact $target_url
            and tar --directory $tmpdir/untar -xf $tmpdir/$binary_artifact | true
            and chmod +x $tmpdir/untar/{$target_artifact_archive_dir}/{$binary}
            and mv $tmpdir/untar/{$target_artifact_archive_dir}/{$binary} ~/.local/bin/
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | head -n 1 | cut -d " " -f 2)
        else
            echo "$binary could not be installed, check logs"
        end
    end
    rm -rf $tmpdir
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

function bat-update -d 'Install latest bat release'
    # https://github.com/sharkdp/bat/releases/download/v0.6.1/bat-v0.6.1-x86_64-unknown-linux-gnu.tar.gz
    set -l binary bat
    set -l binary_artifact {$binary}.tar.gz
    set -l binary_version_cmd $binary --version
    set github_coordinates sharkdp/bat
    set -l tmpdir (mktemp -d)
    mkdir -p $tmpdir/untar
    execute $binary_version_cmd > /dev/null ^ /dev/null
    if test $status -eq 0
        set current_version v(execute $binary_version_cmd | cut -d " " -f 2)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "bat is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
      set target_version $argv
    end
    set -l target_artifact {$binary}-{$target_version}-x86_64-unknown-linux-gnu.tar.gz
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        curl -Lo $tmpdir/{$binary_artifact} https://github.com/{$github_coordinates}/releases/download/{$target_version}/bat-{$target_version}-x86_64-unknown-linux-gnu.tar.gz ; \
            and tar --directory $tmpdir/untar -xf $tmpdir/{$binary_artifact} ; \
            and mv $tmpdir/untar/bat-{$target_version}-x86_64-unknown-linux-gnu/{$binary} ~/.local/bin/ ; \
            and rm -rf $tmpdir
        execute $binary_version_cmd > /dev/null ^ /dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | cut -d " " -f 2)
        else
            echo "bat could not be installed, check logs"
        end
    end
end

function stern-update -d 'Install latest stern release'
    # https://github.com/wercker/stern/releases/download/1.8.0/stern_linux_amd64
    set -l binary stern
    set -l binary_artifact $binary
    set -l binary_version_cmd $binary --version
    set github_coordinates wercker/stern
    set -l tmpdir (mktemp -d)
    execute $binary_version_cmd > /dev/null ^ /dev/null
    if test $status -eq 0
        set current_version (execute $binary_version_cmd | cut -d " " -f 3)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
      set target_version $argv
    end
    set -l target_artifact {$binary}_linux_amd64
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary_artifact} $target_url; \
            and chmod +x $tmpdir/{$binary} ; \
            and mv $tmpdir/{$binary} ~/.local/bin/ ; \
            and rm -rf $tmpdir
        execute $binary_version_cmd > /dev/null ^ /dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | cut -d " " -f 3)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function rke-update -d 'Install latest rke release'
    # https://github.com/rancher/rke/releases/download/v0.1.9/rke_linux-amd64
    set -l binary rke
    set -l binary_artifact $binary
    set -l binary_version_cmd $binary --version
    set github_coordinates rancher/rke
    set -l tmpdir (mktemp -d)
    execute $binary_version_cmd > /dev/null ^ /dev/null
    if test $status -eq 0
        set current_version (execute $binary_version_cmd | cut -d " " -f 3)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
      set target_version $argv
    end
    set -l target_artifact {$binary}_linux-amd64
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary_artifact} $target_url; \
            and chmod +x $tmpdir/{$binary} ; \
            and mv $tmpdir/{$binary} ~/.local/bin/ ; \
            and rm -rf $tmpdir
        execute $binary_version_cmd > /dev/null ^ /dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | cut -d " " -f 3)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function clean-packagekit-cache -d 'Clean effing PackageKit cache'
    echo "Consommation cache AVANT"
    sudo du -khs /var/cache/PackageKit/
    echo "Détail"
    sudo du -khs /var/cache/PackageKit/*
    echo "Nettoyage..."
    sudo pkcon refresh force -c -1
    echo "Consommation cache APRES"
    sudo du -khs /var/cache/PackageKit/
    echo "Détail"
    sudo du -khs /var/cache/PackageKit/*
end
