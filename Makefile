PROJECT := github.com/openshift/odo
ifdef GITCOMMIT
        GITCOMMIT := $(GITCOMMIT)
else
        GITCOMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)
endif
PKGS := $(shell go list  ./... | grep -v $(PROJECT)/vendor | grep -v $(PROJECT)/tests )
COMMON_FLAGS := -X $(PROJECT)/pkg/version/version.GITCOMMIT=$(GITCOMMIT)
BUILD_FLAGS := -ldflags="-w $(COMMON_FLAGS)"
DEBUG_BUILD_FLAGS := -ldflags="$(COMMON_FLAGS)"
FILES := odo dist
TIMEOUT ?= 7200s

# Env variable TEST_EXEC_NODES is used to pass spec execution type
# (parallel or sequential) for ginkgo tests. To run the specs sequentially use
# TEST_EXEC_NODES=1, otherwise by default the specs are run in parallel on 2 ginkgo test node.
# NOTE: Any TEST_EXEC_NODES value greater than one runs the spec in parallel
# on the same number of ginkgo test nodes.
TEST_EXEC_NODES ?= 2

# Slow spec threshold for ginkgo tests. After this time (in second), ginkgo marks test as slow
SLOW_SPEC_THRESHOLD := 120

# Env variable GINKGO_VERBOSE_MODE is used to get control over enabling ginkgo
# verbose mode against each test target run. By default ginkgo verbosity is not enabled.
# To enable verbosity export or set env GINKGO_VERBOSE_MODE like "GINKGO_VERBOSE_MODE=-v"
GINKGO_VERBOSE_MODE ?=

GINKGO_FLAGS_ALL = $(GINKGO_VERBOSE_MODE) -randomizeAllSpecs -slowSpecThreshold=$(SLOW_SPEC_THRESHOLD) -timeout $(TIMEOUT)

# Flags for tests that must not be run in parallel.
GINKGO_FLAGS_SERIAL = $(GINKGO_FLAGS_ALL) -nodes=1
# Flags for tests that may be run in parallel
GINKGO_FLAGS=$(GINKGO_FLAGS_ALL) -nodes=$(TEST_EXEC_NODES)


default: bin

.PHONY: debug
debug:
	go build ${DEBUG_BUILD_FLAGS} cmd/odo/odo.go

.PHONY: bin
bin:
	go build ${BUILD_FLAGS} cmd/odo/odo.go

.PHONY: install
install:
	go install ${BUILD_FLAGS} ./cmd/odo/

# run all validation tests
.PHONY: validate
validate: gofmt check-fit check-vendor vet validate-vendor-licenses sec #lint

.PHONY: gofmt
gofmt:
	./scripts/check-gofmt.sh

.PHONY: check-vendor
check-vendor:
	./scripts/check-vendor.sh

.PHONY: check-fit
check-fit:
	./scripts/check-fit.sh

.PHONY: validate-vendor-licenses
validate-vendor-licenses:
	wwhrd check -q

.PHONY: golint
golint:
	golangci-lint run ./... --timeout 5m

# golint errors are only recommendations
.PHONY: lint
lint:
	golint $(PKGS)

.PHONY: vet
vet:
	go vet $(PKGS)

.PHONY: sec
sec:
	@which gosec 2> /dev/null >&1 || { echo "gosec must be installed to lint code";  exit 1; }
	gosec -severity medium -confidence medium -exclude G304,G204 -quiet  ./...

.PHONY: clean
clean:
	@rm -rf $(FILES)

# install tools used for building, tests and  validations
.PHONY: goget-tools
goget-tools:
	go get -u -x github.com/Masterminds/glide
	go get -u -x github.com/frapposelli/wwhrd
	go get -u -x github.com/onsi/ginkgo/ginkgo
	go get -u -x github.com/securego/gosec/cmd/gosec

# Run unit tests and collect coverage
.PHONY: test-coverage
test-coverage:
	./scripts/generate-coverage.sh

# compile for multiple platforms
.PHONY: cross
cross:
	./scripts/cross-compile.sh '$(COMMON_FLAGS)'

.PHONY: generate-cli-structure
generate-cli-structure:
	go run cmd/cli-doc/cli-doc.go structure

.PHONY: generate-cli-reference
generate-cli-reference:
	go run cmd/cli-doc/cli-doc.go reference > docs/cli-reference.adoc

# create gzipped binaries in ./dist/release/
# for uploading to GitHub release page
# run make cross before this!
.PHONY: prepare-release
prepare-release: cross
	./scripts/prepare-release.sh

.PHONY: configure-installer-tests-cluster
configure-installer-tests-cluster:
	. ./scripts/configure-installer-tests-cluster.sh

.PHONY: test
test:
	go test -race $(PKGS)

# Run generic integration tests
.PHONY: test-generic
test-generic:
	ginkgo $(GINKGO_FLAGS) -focus="odo generic" tests/integration/

# Run odo login and logout tests
.PHONY: test-cmd-login-logout
test-cmd-login-logout:
	ginkgo $(GINKGO_FLAGS_SERIAL) -focus="odo login and logout command tests" tests/integration/loginlogout/

# Run link and unlink command tests
.PHONY: test-cmd-link-unlink
test-cmd-link-unlink:
	ginkgo $(GINKGO_FLAGS) -focus="odo link and unlink command tests" tests/integration/

# Run odo service command tests
.PHONY: test-cmd-service
test-cmd-service:
	ginkgo $(GINKGO_FLAGS) -focus="odo service command tests" tests/integration/servicecatalog/

# Run odo project command tests
.PHONY: test-cmd-project
test-cmd-project:
	ginkgo $(GINKGO_FLAGS_SERIAL) -focus="odo project command tests" tests/integration/project/

# Run odo app command tests
.PHONY: test-cmd-app
test-cmd-app:
	ginkgo $(GINKGO_FLAGS) -focus="odo app command tests" tests/integration/

# Run odo component command tests
.PHONY: test-cmd-cmp
test-cmd-cmp:
	ginkgo $(GINKGO_FLAGS) -focus="odo component command tests" tests/integration/

# Run odo component subcommands tests
.PHONY: test-cmd-cmp-sub
test-cmd-cmp-sub:
	ginkgo $(GINKGO_FLAGS) -focus="odo sub component command tests" tests/integration/

# Run odo preference and config command tests
.PHONY: test-cmd-pref-config
test-cmd-pref-config:
	ginkgo $(GINKGO_FLAGS) -focus="odo preference and config command tests" tests/integration/

# Run odo push command tests
.PHONY: test-cmd-push
test-cmd-push:
	ginkgo $(GINKGO_FLAGS) -focus="odo push command tests" tests/integration/

# Run odo storage command tests
.PHONY: test-cmd-storage
test-cmd-storage:
	ginkgo $(GINKGO_FLAGS) -focus="odo storage command tests" tests/integration/

# Run odo url command tests
.PHONY: test-cmd-url
test-cmd-url:
	ginkgo $(GINKGO_FLAGS) -focus="odo url command tests" tests/integration/

# Run odo watch command tests
.PHONY: test-cmd-watch
test-cmd-watch:
	ginkgo $(GINKGO_FLAGS) -focus="odo watch command tests" tests/integration/

# Run odo debug command tests
test-cmd-debug:
	ginkgo $(GINKGO_FLAGS) -focus="odo debug command tests" tests/integration/

# Run command's integration tests irrespective of service catalog status in the cluster.
# Service, link and login/logout command tests are not the part of this test run
.PHONY: test-integration
test-integration:
	ginkgo $(GINKGO_FLAGS) tests/integration/

# Run command's integration tests which are depend on service catalog enabled cluster.
# Only service and link command tests are the part of this test run
.PHONY: test-integration-service-catalog
test-integration-service-catalog:
	ginkgo $(GINKGO_FLAGS) tests/integration/servicecatalog/

# Run core beta flow e2e tests
.PHONY: test-e2e-beta
test-e2e-beta:
	ginkgo $(GINKGO_FLAGS) -focus="odo core beta flow" tests/e2escenarios/

# Run java e2e tests
.PHONY: test-e2e-java
test-e2e-java:
	ginkgo $(GINKGO_FLAGS) -focus="odo java e2e tests" tests/e2escenarios/

# Run source e2e tests
.PHONY: test-e2e-source
test-e2e-source:
	ginkgo $(GINKGO_FLAGS) -focus="odo source e2e tests" tests/e2escenarios/

# Run all e2e test scenarios
.PHONY: test-e2e-all
test-e2e-all:
	ginkgo $(GINKGO_FLAGS) tests/e2escenarios/

# this test shouldn't be in paralel -  it will effect the results
.PHONY: test-benchmark
test-benchmark:
	ginkgo $(GINKGO_FLAGS_SERIAL) tests/benchmark/

# create deb and rpm packages using fpm in ./dist/pkgs/
# run make cross before this!
.PHONY: packages
packages:
	./scripts/create-packages.sh

# upload packages greated by 'make packages' to bintray repositories
# run 'make cross' and 'make packages' before this!
.PHONY: upload-packages
upload-packages:
	./scripts/upload-packages.sh

# Update vendoring
.PHONY: vendor-update
vendor-update:
	glide update --strip-vendor

.PHONY: openshiftci-presubmit-unittests
openshiftci-presubmit-unittests:
	./scripts/openshiftci-presubmit-unittests.sh
