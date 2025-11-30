param(
    [ValidateSet("dev","dev-dood","dind")]
    [string]$Command = "dev"
)

$IMAGE="devbox:latest"
$HOME_VOL="devbox-home"

# Формируем опцию для ssh-agent только если переменная есть
$sshAgentMount = ""
if ($env:SSH_AUTH_SOCK) {
    $sshAgentMount = "-e SSH_AUTH_SOCK=/ssh-agent -v ${env:SSH_AUTH_SOCK}:/ssh-agent"
}

# Прокидываем .gitconfig для git коммитов и пушей из контейнера
$gitConfigMount = ""
$gitConfigPath = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitConfigPath) {
    $gitConfigMount = "-v ${gitConfigPath}:/home/dev/.gitconfig:ro"
}

switch ($Command)
{
    "dev" {
        docker run --rm -it `
          -e UID=1000 -e GID=1000 `
          $sshAgentMount `
          $gitConfigMount `
          -v ${PWD}:/work `
          -v ${HOME_VOL}:/home/dev `
          --add-host host.docker.internal:host-gateway `
          --name devbox `
          $IMAGE
    }
    "dev-dood" {
        docker run --rm -it `
          -e UID=1000 -e GID=1000 `
          $sshAgentMount `
          $gitConfigMount `
          -v /var/run/docker.sock:/var/run/docker.sock `
          -v ${PWD}:/work `
          -v ${HOME_VOL}:/home/dev `
          --add-host host.docker.internal:host-gateway `
          --name devbox `
          $IMAGE
    }
    "dind" {
        docker rm -f devbox-dind 2> $null
        docker run -d --privileged --name devbox-dind `
          -p 2375:2375 -e DOCKER_TLS_CERTDIR= -v devbox-dind-storage:/var/lib/docker docker:26-dind
        Write-Output "DinD up. Use inside dev container: export DOCKER_HOST=tcp://host.docker.internal:2375"
    }
}