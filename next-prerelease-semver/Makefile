##@ Build

build: fmt vet ## Build manager binary.
	go build -o bin/next-prerelease-semver main.go

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

run: fmt vet ## Run a controller from your host.
	go run ./main.go --release=1.2.1 --repository=docker.io/trevorbox/go-app --authfile=./auth.json
