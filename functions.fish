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
function compute_latest_version -d "rely on latest"
    set -l github_coordinates $argv[1]
    printf (curl -u $GITHUB_BASIC_AUTH -s https://api.github.com/repos/$github_coordinates/releases/latest | jq -r '.tag_name')
end
function compute_latest_version_from_latest -d "rely on latest"
    set -l github_coordinates $argv[1]
    printf (curl -u $GITHUB_BASIC_AUTH -s https://api.github.com/repos/$github_coordinates/releases/latest | jq -r '.tag_name')
end

function compute_latest_version_from_tags -d "rely on tags"
    set -l github_coordinates $argv[1]
    printf (curl -u $GITHUB_BASIC_AUTH -s https://api.github.com/repos/$github_coordinates/tags | jq -rc '.[0] | .name')
end
function _use_compute_latest_version_from_latest
    if type -q compute_latest_version
        functions --erase compute_latest_version
    end
    functions --copy compute_latest_version_from_latest compute_latest_version
end
function _use_compute_latest_version_from_tags
    if type -q compute_latest_version
        functions --erase compute_latest_version
    end
    functions --copy compute_latest_version_from_tags compute_latest_version
end
function _reset_compute_latest_version
    _use_compute_latest_version_from_latest
end
function compute_target_url_github -d "github style compute_target_url"
    set -l github_coordinates $argv[1]
    set -l target_version $argv[2]
    set -l target_version_short $argv[3]
    set -l target_artifact $argv[4]
    set -l binary $argv[5]
    printf https://github.com/$github_coordinates/releases/download/$target_version/$target_artifact
end
function create_temp_dir -d "create tmp download dir according to pattern"
    set -l l_pattern $argv[1]
    set -l l_base_dir /tmp/awesome-updater
    mkdir -p $l_base_dir
    printf (mktemp -d $l_base_dir/$l_pattern.XXXXXXXXX)
end

function download_and_install_binary
    set -l target_url $argv[1]
    set -l tmpdir $argv[2]
    set -l binary $argv[3]
    set -l no_auth $argv[4]

    echo "Downloading from $target_url"
    if test -n "$no_auth"
        curl -Lo $tmpdir/{$binary} $target_url
    else
        curl -u $GITHUB_BASIC_AUTH -Lo $tmpdir/{$binary} $target_url
    end
    chmod +x $tmpdir/{$binary}
    mv $tmpdir/{$binary} ~/.local/bin/
    rm -rf $tmpdir

end

function download_and_untar_and_install
    set -l target_url $argv[1]
    set -l tmpdir $argv[2]
    set -l binary $argv[3]
    set -l no_auth $argv[4]
    set -l untar_binary_ext $argv[5]
    set -l untar_dir $argv[6]
    set -l binary_prefix $argv[7]
    if test -n "$no_auth"
        curl -Lo $tmpdir/{$binary}.tgz $target_url
    else
        curl -u $GITHUB_BASIC_AUTH -Lo $tmpdir/{$binary}.tgz $target_url
    end

    and tar --directory $tmpdir -xf $tmpdir/$binary.tgz
    and mv $tmpdir/{$binary}{$untar_binary_ext} ~/.local/bin/{$binary_prefix}{$binary}
    and chmod +x ~/.local/bin/{$binary_prefix}{$binary}
end
function _use_download_and_install_binary
    if type -q download_and_install
        functions --erase download_and_install
    end
    functions --copy download_and_install_binary download_and_install
end
function _use_compute_target_url_github
    if type -q compute_target_url
        functions --erase compute_target_url
    end
    functions --copy compute_target_url_github compute_target_url
end
function _generic_update -d 'Generic updater'
    set -l binary $argv[1]
    set -l github_coordinates $argv[2]
    set -l binary_version_cmd $argv[3..-1]
    #
    printf "binary             : [$binary]\ngithub_coordinates : [$github_coordinates]\nbinary_version_cmd : [$binary_version_cmd]\n"
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
        set -l target_artifact (compute_target_artifact $binary $target_version $target_version_short)
        echo "Found target_artifact [$target_artifact]"
        echo "Current version is not target/latest ($target_version), downloading..."
        set -l target_url (compute_target_url $github_coordinates $target_version $target_version_short $target_artifact $binary)
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

function krew-update -d 'Install latest krew release'
    # https://storage.googleapis.com/krew/v0.2.1/krew.tar.gz
    set -l binary krew
    set -l binary_version_cmd kubectl-{$binary} version
    set -l github_coordinates GoogleContainerTools/krew

    function compute_version
        kubectl-krew version | grep GitTag | cut -d "v" -f2
    end
    function compute_target_artifact
        set -l binary $argv[1]
        set -l target_version $argv[2]
        set -l target_version_short $argv[3]
        printf $binary".tar.gz"
    end
    function compute_target_url -d "google style compute_target_url"
        set -l github_coordinates $argv[1]
        set -l target_version $argv[2]
        set -l target_version_short $argv[3]
        set -l target_artifact $argv[4]
        set -l binary $argv[5]
        printf https://storage.googleapis.com/{$binary}/{$target_version}/{$target_artifact}
    end
    function download_and_install
        set -l target_url $argv[1]
        set -l tmpdir $argv[2]
        set -l binary $argv[3]
        set -l no_auth NO_AUTH_BECAUSE_GOOGLE_STORAGE
        set -l untar_binary_ext "-linux_amd64"
        set -l untar_dir ""
        set -l binary_prefix "kubectl-"
        download_and_untar_and_install $target_url $tmpdir $binary $no_auth $untar_binary_ext $untar_dir $binary_prefix
    end
    #
    # Nothing more to customize down here (crossing fingers)
    #
    _generic_update $binary $github_coordinates $binary_version_cmd
end

function ytt-update -d 'Install latest ytt release'
    # https://github.com/get-ytt/ytt/releases/download/v0.1.0/ytt-linux-amd64
    set -l binary ytt
    set -l binary_version_cmd $binary version
    set -l github_coordinates get-ytt/ytt

    function compute_version
        ytt version | cut -d " " -f2
    end
    function compute_target_artifact
        set -l binary $argv[1]
        set -l target_version $argv[2]
        set -l target_version_short $argv[3]
        printf "%s-linux-amd64" $binary
    end

    _use_download_and_install_binary
    _use_compute_target_url_github
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
