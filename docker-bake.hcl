# Build everything:  docker buildx bake          (or: make build)
# One image:         docker buildx bake java
# Base is built first because the derived targets take it as a named context.

variable "TAG" {
  default = "latest"
}

variable "CLAUDE_CODE_VERSION" {
  default = "latest"
}

group "default" {
  targets = ["base", "flutter", "java"]
}

target "base" {
  context    = "."
  dockerfile = "Dockerfile"
  args       = { CLAUDE_CODE_VERSION = CLAUDE_CODE_VERSION }
  tags      = ["devbox-base:${TAG}"]
}

target "flutter" {
  context    = "."
  dockerfile = "docker/flutter.Dockerfile"
  contexts   = { devbox-base = "target:base" }
  args       = { BASE_IMAGE = "devbox-base" }
  tags       = ["devbox-flutter:${TAG}"]
}

target "java" {
  context    = "."
  dockerfile = "docker/java.Dockerfile"
  contexts   = { devbox-base = "target:base" }
  args       = { BASE_IMAGE = "devbox-base" }
  tags       = ["devbox-java:${TAG}"]
}
