##@ Build

build: fmt vet ## Build manager binary.
	go build -o bin/sort main.go

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

run: fmt vet ## Run a controller from your host.
	go run ./main.go --release=1.2.1 --repository=quay.io/trevorbox/pipeline-test-go
