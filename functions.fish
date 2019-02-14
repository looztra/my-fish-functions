function execute
    if test (count $argv) -eq 0
        return 0
    end
    if which $argv[1] >/dev/null
        eval $argv
        return $status
    else
        return 1
    end
end

function aws-alternate -d 'copy aws creds to alternate vars'
    set -x AWS_ACCESS_KEY $AWS_ACCESS_KEY_ID
    set -x AWS_SECRET_KEY $AWS_SECRET_ACCESS_KEY
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
#
# Usefull
#
function github_api_status -d 'Get github api status and quota'
    curl -u "$GITHUB_BASIC_AUTH" -i https://api.github.com/users/looztra
end
function gitc -d 'Clone a git repository and prefix the local directory with the owner'
    if test -z "$argv"
        echo "Waiting for params that are not provided, bye"
        return 1
    end
    set -l git_repository_url $argv[1]
    set -l target_base_dir $argv[2]
    set -l path_elements (string split / $git_repository_url)
    set -l owner_elements (string split : $path_elements[-2])
    set -l repo_elements (string split . $path_elements[-1])
    set -l owner $owner_elements[-1]
    set -l repo $repo_elements[1]
    set -l target_dir
    if test -z "$target_base_dir"
        set target_base_dir "."
    else
        if not test -d $target_base_dir
            echo "Target base [$target_base_dir] dir doesn't seem to exist, bye"
            return 1
        end
    end
    set -l target_dir "$target_base_dir/$owner--$repo"
    if test -e $target_dir
        echo "Cannot clone git repository [$git_repository_url] to directory [$target_dir] because file/directory already exist"
        return 1
    end
    echo "Cloning repo [$git_repository_url] » [$target_dir]"
    git clone $git_repository_url $target_dir
end

function gitct -d 'Clone a git repository, prefix the local dir with owner, and force target base dir'
    set -l git_repository_url $argv[1]
    set -l target_base_dir $argv[2]
    set -l workspace_base_dir ~/workspace
    if test -z $target_base_dir
        echo "No target base dir provided, falling back to 'gitc'"
        gitc $git_repository_url
    else
        gitc $git_repository_url $workspace_base_dir/$target_base_dir
    end
end
#
# Installers / Updaters shared functions
function compute_latest_version -d "github style compute_latest_version"
    set -l l_github_coordinates $argv[1]
    printf (curl -u $GITHUB_BASIC_AUTH -s https://api.github.com/repos/$l_github_coordinates/releases/latest | jq -r '.tag_name')
end
function compute_target_url -d "github style compute_target_url"
    set -l l_github_coordinates $argv[1]
    set -l l_target_version $argv[2]
    set -l l_target_version_short $argv[3]
    set -l l_target_artifact $argv[4]
    printf https://github.com/$l_github_coordinates/releases/download/$l_target_version/$l_target_artifact
end
function create_temp_dir -d "create tmp download dir according to pattern"
    set -l l_pattern $argv[1]
    set -l l_base_dir /tmp/awesome-updater
    mkdir -p $l_base_dir
    printf (mktemp -d $l_base_dir/$l_pattern.XXXXXXXXX)
end
function download_and_install
    set -l target_url $argv[1]
    set -l tmpdir $argv[2]
    set -l binary $argv[3]
    echo "Nothing here for now"
end

function download_and_untar_and_install
    set -l target_url $argv[1]
    set -l tmpdir $argv[2]
    set -l binary $argv[3]
    echo "Downloading from $target_url"
    curl -u $GITHUB_BASIC_AUTH -Lo $tmpdir/{$binary}.tgz $target_url
    and tar --directory $tmpdir -xf $tmpdir/$binary.tgz
    and mv $tmpdir/{$binary} ~/.local/bin/{$binary}
    and chmod +x ~/.local/bin/{$binary}
end

function _generic_update -d 'Generic updater'
    set -l binary $argv[1]
    set -l github_coordinates $argv[2]
    set -l binary_version_cmd $argv[3..-1]
    #
    printf "binary : [$binary]\ngithub_coordinates : [$github_coordinates]\nbinary_version_cmd : [$binary_version_cmd]\n"
    #
    set -l tmpdir (create_temp_dir $binary)
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (compute_version)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (compute_latest_version $github_coordinates)
    set target_version_short (echo $target_version | tr -d "v")
    printf "Found target_version [$target_version]\nFound target_version_short [$target_version_short]\n"
    if [ $target_version_short = $current_version ]
        echo "Current version is already target/latest"
    else
        set -l target_artifact (compute_target_artifact $binary)
        echo "Found target_artifact [$target_artifact]"
        echo "Current version is not target/latest ($target_version), downloading..."
        set -l target_url (compute_target_url $github_coordinates $target_version $target_version_short $target_artifact)
        #
        download_and_install $target_url $tmpdir $binary
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(compute_version)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end
#
# Installers / Updaters
#
function minikube-update -d 'Install latest minikube release'
    execute minikube version >/dev/null ^/dev/null
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
        curl -Lo minikube https://github.com/kubernetes/minikube/releases/download/{$target_version}/minikube-linux-amd64
        and chmod +x minikube
        and mv minikube ~/.local/bin/
        execute minikube version >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(minikube version | cut -d " " -f 3)
        else
            echo "Minikube could not be installed, check logs"
        end
    end
end

function minishift-update -d 'Install latest minishift release'
    execute minishift version >/dev/null ^/dev/null
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
        curl -Lo $HOME/tmp/minishift.tgz https://github.com/minishift/minishift/releases/download/{$target_version}/minishift-{$target_version_short}-linux-amd64.tgz
        and tar --directory $HOME/tmp -xf $HOME/tmp/minishift.tgz
        and chmod +x $HOME/tmp/minishift-{$target_version_short}-linux-amd64/minishift
        and mv $HOME/tmp/minishift-{$target_version_short}-linux-amd64/minishift ~/.local/bin/
        and rm -rf $HOME/tmp/minishift-{$target_version_short}-linux-amd64 $HOME/tmp/minishift.tgz
        execute minishift version >/dev/null ^/dev/null
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
    set -l tmpdir (mktemp -d)
    if not test -z "$argv"
        set compose_version $argv
    end
    echo "Retreiving docker-compose version $compose_version"
    echo "gna"
    curl -Lo {$tmpdir}/docker-compose https://github.com/docker/compose/releases/download/$compose_version/docker-compose-Linux-x86_64
    chmod +x {$tmpdir}/docker-compose
    and mv {$tmpdir}/docker-compose ~/.local/bin/
    which docker-compose
    docker-compose version
    rm -rf $tmpdir
end

function machine-update -d 'Update docker-machine to version provided in param or latest release if no param provided'
    set machine_version (curl -s https://api.github.com/repos/docker/machine/releases/latest | jq .tag_name | tr -d '"')
    set -l tmpdir (mktemp -d)
    set version_type default
    if not test -z "$argv"
        set version_type forced
        set machine_version $argv
    end
    echo "Retreiving docker-machine version $machine_version ($version_type)"
    curl -Lo {$tmpdir}/docker-machine https://github.com/docker/machine/releases/download/$machine_version/docker-machine-Linux-x86_64
    chmod +x {$tmpdir}/docker-machine
    and mv {$tmpdir}/docker-machine ~/.local/bin/
    which docker-machine
    docker-machine version
    rm -rf $tmpdir
end

function terraform-update -d 'Update terraform to latest release'
    set -l tmpdir (mktemp -d ~/tmp/tmp.terraform-XXXXXXXX)
    file $tmpdir
    set tf_version (curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq .tag_name | tr -d '"' | tr -d 'v')
    curl -Lo $tmpdir/terraform.latest.zip https://releases.hashicorp.com/terraform/{$tf_version}/terraform_{$tf_version}_linux_amd64.zip
    unzip -o $tmpdir/terraform.latest.zip -d $tmpdir/
    chmod +x $tmpdir/terraform
    and mv $tmpdir/terraform ~/.local/bin
    and rm -rf $tmpdir
    terraform version
end

function packer-update -d 'Update packer to latest release'
    set -l tmpdir (mktemp -d ~/tmp/tmp.packer-XXXXXXXX)
    file $tmpdir
    set -l target_version (curl -s https://api.github.com/repos/hashicorp/packer/tags | jq -rc '.[0] | .name' | tr -d 'v')
    set -l target_url https://releases.hashicorp.com/packer/{$target_version}/packer_{$target_version}_linux_amd64.zip
    echo "Target url : $target_url"
    curl -Lo $tmpdir/packer.latest.zip $target_url
    file $tmpdir/packer.latest.zip
    unzip -o $tmpdir/packer.latest.zip -d $tmpdir/
    chmod +x $tmpdir/packer
    and mv $tmpdir/packer ~/.local/bin
    and rm -rf $tmpdir
    packer version
end

function bat-update -d 'Install latest bat release'
    # https://github.com/sharkdp/bat/releases/download/v0.6.1/bat-v0.6.1-x86_64-unknown-linux-gnu.tar.gz
    set -l binary bat
    set -l binary_artifact {$binary}.tar.gz
    set -l binary_version_cmd $binary --version
    set github_coordinates sharkdp/bat
    set -l tmpdir (mktemp -d)
    mkdir -p $tmpdir/untar
    execute $binary_version_cmd >/dev/null ^/dev/null
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
        curl -Lo $tmpdir/{$binary_artifact} https://github.com/{$github_coordinates}/releases/download/{$target_version}/bat-{$target_version}-x86_64-unknown-linux-gnu.tar.gz
        and tar --directory $tmpdir/untar -xf $tmpdir/{$binary_artifact}
        and mv $tmpdir/untar/bat-{$target_version}-x86_64-unknown-linux-gnu/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
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
    execute $binary_version_cmd >/dev/null ^/dev/null
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
        curl -Lo $tmpdir/{$binary_artifact} $target_url
        and chmod +x $tmpdir/{$binary}
        and mv $tmpdir/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
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
    execute $binary_version_cmd >/dev/null ^/dev/null
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
        curl -Lo $tmpdir/{$binary_artifact} $target_url
        and chmod +x $tmpdir/{$binary}
        and mv $tmpdir/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | cut -d " " -f 3)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function helm-update -d 'Install latest helm release'
    # https://github.com/helm/helm/releases/latest
    # https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz
    set -l binary helm
    set -l binary_artifact {$binary}.tgz
    set -l binary_version_cmd $binary version --client --template '"{{.Client.SemVer}}"'
    set github_coordinates helm/helm
    set -l tmpdir (mktemp -d /tmp/tmp.{$binary}-XXXXXXXX)
    execute $binary_version_cmd >/dev/null ^/dev/null
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
    set -l target_artifact {$binary}-{$target_version}-linux-amd64.tar.gz
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        set target_url https://storage.googleapis.com/kubernetes-helm/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary_artifact} $target_url
        and tar --directory $tmpdir -xf $tmpdir/{$binary_artifact}
        and mv $tmpdir/linux-amd64/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd | cut -d " " -f 3)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function bats-update -d 'Update bat to latest release'
    set -l binary bats
    set -l binary_version_cmd $binary --version
    set -l github_coordinates sstephenson/bats
    set -l tmpdir (mktemp -d ~/tmp/tmp.{$binary}-XXXXXXXX)
    file $tmpdir
    set -l target_version (curl -s https://api.github.com/repos/{$github_coordinates}/tags | jq -rc '.[0] | .name')
    set -l target_version_short (echo $target_version | tr -d 'v')
    set -l target_url https://github.com/{$github_coordinates}/archive/{$target_version}.zip
    echo "Target url : $target_url"
    curl -Lo $tmpdir/{$binary}.latest.zip $target_url
    file $tmpdir/{$binary}.latest.zip
    unzip -o $tmpdir/{$binary}.latest.zip -d $tmpdir
    execute {$tmpdir}/{$binary}-{$target_version_short}/install.sh ~/.local
    rm -rf $tmpdir
    execute $binary_version_cmd
end

function kubespy-update -d 'Install latest kubespy release'
    # https://github.com/helm/helm/releases/latest
    # https://github.com/pulumi/kubespy/releases/download/v0.4.0/kubespy-linux-amd64.tar.gz
    set -l binary kubespy
    set -l binary_artifact {$binary}.tgz
    set -l binary_version_cmd $binary version
    set github_coordinates pulumi/kubespy
    set -l tmpdir (mktemp -d /tmp/tmp.{$binary}-XXXXXXXX)
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (execute $binary_version_cmd)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
        set target_version $argv
    end
    set -l target_artifact {$binary}-linux-amd64.tar.gz
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary_artifact} $target_url
        and tar --directory $tmpdir -xf $tmpdir/{$binary_artifact}
        and mv $tmpdir/releases/kubespy-linux-amd64/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(execute $binary_version_cmd)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function dep-update -d 'Install latest dep release'
    # https://github.com/golang/dep/releases/download/v0.5.0/dep-linux-amd64
    set -l binary dep
    set -l binary_version_cmd $binary version
    set -l github_coordinates golang/dep
    set -l target_artifact {$binary}-linux-amd64
    set -l tmpdir (mktemp -d)

    function compute_version
        dep version | grep version | grep -v "go" | sed "s/  *//g" | cut -d ":" -f2
    end
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (compute_version)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq .tag_name | tr -d '"')
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary} $target_url
        and chmod +x $tmpdir/{$binary}
        and mv $tmpdir/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(compute_version)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function terraform-docs-update -d 'Install latest terraform-docs release'
    # https://github.com/segmentio/terraform-docs/releases/download/v0.6.0/terraform-docs-v0.6.0-linux-amd64
    set -l binary terraform-docs
    set -l binary_version_cmd $binary --version
    set -l github_coordinates segmentio/terraform-docs
    set -l tmpdir (mktemp -d /tmp/tmp.$binary.XXXXXXXX)

    function compute_version
        terraform-docs --version
    end
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version "v"(compute_version)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq -r .tag_name)
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version = $current_version ]
        echo "Current version is already target/latest"
    else
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_version_short (echo $target_version | tr -d "v")
        set -l target_artifact {$binary}-{$target_version}-linux-amd64
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary} $target_url
        and chmod +x $tmpdir/{$binary}
        and mv $tmpdir/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version v"(compute_version)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function vault-update -d 'Update vault to latest release'
    set -l tmpdir (mktemp -d ~/tmp/tmp.vault-XXXXXXXX)
    file $tmpdir
    set -l target_version (curl -s https://api.github.com/repos/hashicorp/vault/tags | jq -rc '.[0] | .name' | tr -d 'v')
    set -l target_url https://releases.hashicorp.com/vault/{$target_version}/vault_{$target_version}_linux_amd64.zip
    echo "Target url : $target_url"
    curl -Lo $tmpdir/vault.latest.zip $target_url
    file $tmpdir/vault.latest.zip
    unzip -o $tmpdir/vault.latest.zip -d $tmpdir/
    chmod +x $tmpdir/vault
    and mv $tmpdir/vault ~/.local/bin
    and rm -rf $tmpdir
    vault version
end

function k9s-update -d 'Update k9s to latest release'
    # https://github.com/derailed/k9s/releases/download/0.1.2/k9s_0.1.2_Linux_x86_64.tar.gz
    set -l tmpdir (mktemp -d ~/tmp/tmp.k9s-XXXXXXXX)
    set -l github_coordinates derailed/k9s
    set -l binary k9s
    file $tmpdir
    set -l target_version (curl -s https://api.github.com/repos/{$github_coordinates}/tags | jq -rc '.[0] | .name')
    set -l target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$binary}_{$target_version}_Linux_x86_64.tar.gz
    echo "Target url : $target_url"
    curl -Lo $tmpdir/$binary.tgz $target_url
    file $tmpdir/$binary.tgz
    tar --directory $tmpdir -xf $tmpdir/$binary.tgz
    chmod +x $tmpdir/{$binary}
    mv $tmpdir/{$binary} ~/.local/bin/
    rm -rf $tmpdir
    k9s version
end

function rbac-lookup-update -d 'Install latest rbac-lookup release'
    # https://github.com/reactiveops/rbac-lookup/releases/download/v0.2.1/rbac-lookup_0.2.1_Linux_x86_64.tar.gz
    set -l binary rbac-lookup
    set -l binary_version_cmd $binary version
    set -l github_coordinates reactiveops/rbac-lookup
    set -l tmpdir (mktemp -d)

    function compute_version
        rbac-lookup version | cut -d " " -f 3
    end
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (compute_version)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq -r '.tag_name')
    set target_version_short (echo $target_version | tr -d "v")
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version_short = $current_version ]
        echo "Current version is already target/latest"
    else
        set -l target_artifact {$binary}_{$target_version_short}_Linux_x86_64.tar.gz
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary}.tgz $target_url
        and tar --directory $tmpdir -xf $tmpdir/$binary.tgz
        and chmod +x $tmpdir/{$binary}
        and mv $tmpdir/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(compute_version)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function kustomize-update -d 'Install latest kustomize release'
    # https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.1/kustomize_2.0.1_linux_amd64
    set -l binary kustomize
    set -l binary_version_cmd $binary version
    set -l github_coordinates kubernetes-sigs/kustomize
    set -l tmpdir (mktemp -d)

    function compute_version
        kustomize version | cut -d ":" -f3 | cut -d " " -f1
    end
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (compute_version)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq -r '.tag_name')
    set target_version_short (echo $target_version | tr -d "v")
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version_short = $current_version ]
        echo "Current version is already target/latest"
    else
        set -l target_artifact {$binary}_{$target_version_short}_linux_amd64
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_url https://github.com/{$github_coordinates}/releases/download/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary} $target_url
        and chmod +x $tmpdir/{$binary}
        and mv $tmpdir/{$binary} ~/.local/bin/
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(compute_version)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function krew-update -d 'Install latest krew release'
    # https://storage.googleapis.com/krew/v0.2.1/krew.tar.gz
    set -l binary krew
    set -l binary_version_cmd kubectl-{$binary} version
    set -l github_coordinates GoogleContainerTools/krew
    set -l tmpdir (mktemp -d)

    function compute_version
        kubectl-krew version | grep GitTag | cut -d "v" -f2
    end
    execute $binary_version_cmd >/dev/null ^/dev/null
    if test $status -eq 0
        set current_version (compute_version)
        echo "Current version $current_version"
    else
        set current_version ""
        echo "[$binary] is not installed yet"
    end
    set target_version (curl -s https://api.github.com/repos/{$github_coordinates}/releases/latest | jq -r '.tag_name')
    set target_version_short (echo $target_version | tr -d "v")
    if not test -z "$argv"
        set target_version $argv
    end
    if [ $target_version_short = $current_version ]
        echo "Current version is already target/latest"
    else
        set -l target_artifact {$binary}.tar.gz
        echo "Current version is not target/latest ($target_version), downloading..."
        set target_url https://storage.googleapis.com/{$binary}/{$target_version}/{$target_artifact}
        echo "Downloading from $target_url"
        curl -Lo $tmpdir/{$binary}.tgz $target_url
        and tar --directory $tmpdir -xf $tmpdir/$binary.tgz
        and mv $tmpdir/{$binary}-linux_amd64 ~/.local/bin/kubectl-{$binary}
        and rm -rf $tmpdir
        execute $binary_version_cmd >/dev/null ^/dev/null
        if test $status -eq 0
            echo "Installed version "(compute_version)
        else
            echo "[$binary] could not be installed, check logs"
        end
    end
end

function kubeval-update -d 'Install latest kubeval release'
    # https://github.com/garethr/kubeval/releases/download/0.7.3/kubeval-linux-amd64.tar.gz
    set -l binary kubeval
    set -l github_coordinates garethr/$binary
    set -l binary_version_cmd $binary --version

    function compute_version
        kubeval --version | grep Version | cut -d ":" -f2 | tr -d " "
    end
    function compute_target_artifact
        set -l l_binary $argv[1]
        set -l l_target_version $argv[2]
        set -l l_target_version_short $argv[3]
        printf $l_binary"-linux-amd64.tar.gz"
    end
    function download_and_install
        set -l target_url $argv[1]
        set -l tmpdir $argv[2]
        set -l binary $argv[3]
        download_and_untar_and_install $target_url $tmpdir $binary
    end
    #
    # Nothing more to customize down here (crossing fingers)
    #
    _generic_update $binary $github_coordinates $binary_version_cmd
end

function list-updaters -d 'List available installers/updaters'
  for candidate in (functions -n)
    if string match -q -- '*-update' $candidate
      printf "$candidate\n"
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
