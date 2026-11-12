ifneq ($(shell which docker-compose 2>/dev/null),)
    DOCKER_COMPOSE := docker-compose
else
    DOCKER_COMPOSE := docker compose
endif


help: 
	@echo "================================================"
	@echo "Startr.Space by Startr.Cloud and Startr LLC "
	@echo "================================================"
	@echo ""
	@echo 'This is the default make command.' 
	@echo "This command lists available make commands."
	@echo ""
	@echo "Usage example:"
	@echo "    make it_run"
	@echo ""
	@echo "Available make commands:"
	@echo ""
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null \
		| awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$$@$$'
	@echo ""	

# Configuration variables
IMAGE_NAME_ROOT := startr
IMAGE_NAME := $(IMAGE_NAME_ROOT)/$(shell basename $(PWD) | tr '[:upper:]' '[:lower:]')
GHCR_IMAGE_NAME := ghcr.io/$(IMAGE_NAME)
GIT_TAG := $(shell git tag --sort=-v:refname | sed 's/^v//' | head -n 1)
IMAGE_TAG := $(if $(GIT_TAG),$(GIT_TAG),latest)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
ifeq ($(GIT_BRANCH),HEAD)
    GIT_BRANCH := $(shell git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
endif
SAFE_GIT_BRANCH := $(subst /,-,$(GIT_BRANCH))
SAFE_GIT_BRANCH := $(shell echo $(SAFE_GIT_BRANCH) | tr '[:upper:]' '[:lower:]')
CONTAINER_NAME := $(shell basename $(PWD) | tr '[:upper:]' '[:lower:]')
PORT_MAPPING := 8000:8000
VOLUME_DATA := $$(pwd)/data:/app/data
ENV_FILE := $$(pwd)/.env:/app/.env
FRONTEND_SRC := $$(pwd)/app/src/:/app/src/
BACKEND_SRC := $$(pwd)/app/backend/:/app/backend/

# Architectures to build for
ARCHITECTURES := amd64 arm64 # Not used at the moment

# Common docker run arguments
DOCKER_RUN_ARGS := --rm -p $(PORT_MAPPING) \
	--add-host=host.docker.internal:host-gateway \
	-v $(VOLUME_DATA) \
	-v $(ENV_FILE) \
	--name $(CONTAINER_NAME)

DEV_RUN_ARGS := --rm -p $(PORT_MAPPING) \
	--add-host=host.docker.internal:host-gateway \
	-p 5173:5173 \
	-v $(VOLUME_DATA) \
	-v $(ENV_FILE) \
	-v $(FRONTEND_SRC) \
	--name $(CONTAINER_NAME)

it_stop:
	docker rm -f $(CONTAINER_NAME)

it_clean:
	docker system prune -f
	docker builder prune --force

it_gone:
	@echo "Forcefully stopping and removing $(CONTAINER_NAME)..."
	docker stop $(CONTAINER_NAME) || true
	docker rm -f $(CONTAINER_NAME) || true
	@echo "Container $(CONTAINER_NAME) has been removed"

# Build Docker Image with Branch Name
it_build:
	@echo "Building Docker image with BuildKit enabled..."
	@export DOCKER_BUILDKIT=1 && \
	docker build --load -t $(IMAGE_NAME):$(IMAGE_TAG) \
	            -t $(IMAGE_NAME):latest \
	            -t $(IMAGE_NAME):$(IMAGE_TAG)-$(SAFE_GIT_BRANCH) \
	            -t $(IMAGE_NAME):$(SAFE_GIT_BRANCH) \
	            .
	afplay /System/Library/Sounds/Glass.aiff

# Build Docker Image without Cache and with Branch Name
it_build_no_cache:
	@echo "Building Docker image without cache and with BuildKit enabled..."
	@export DOCKER_BUILDKIT=1 && \
	docker build --no-cache --load -t $(IMAGE_NAME):$(IMAGE_TAG) \
	                     -t $(IMAGE_NAME):latest \
	                     -t $(IMAGE_NAME):$(IMAGE_TAG)-$(SAFE_GIT_BRANCH) \
	                     -t $(IMAGE_NAME):$(SAFE_GIT_BRANCH) \
	                     .
	afplay /System/Library/Sounds/Glass.aiff


build_slim:
	# Build a slim version of the image from the Dockerimage
	# Note at the moment manual use of the site is required to build the slim version
	# we need to add selenium automation to the build process to automate this
	# see https://github.com/slimtoolkit/slim
	@# slim reads DOCKER_HOST, not docker's context: Colima has no /var/run/docker.sock.
	DOCKER_HOST=$$(docker context inspect -f '{{.Endpoints.docker.Host}}') slim build --http-probe  --include-path /app/backend --include-path /app/static --continue-after=160  $(IMAGE_NAME)

it_run_slim:
	# Run the slim version of the image
	docker run $(DOCKER_RUN_ARGS) $(IMAGE_NAME).slim:latest


dev_run:
	docker run $(DEV_RUN_ARGS) $(IMAGE_NAME):$(IMAGE_TAG) bash -c "/app/backend/restore_backup_start.sh dev" 

# Run targets
it_run:
	docker run $(DOCKER_RUN_ARGS) $(IMAGE_NAME):$(IMAGE_TAG)

# Combine build and dev run targets
it_build_n_dev_run: it_build
	afplay /System/Library/Sounds/Glass.aiff
	@make dev_run

# Combined build and run targets
it_build_n_run: it_build
	@make it_run

it_build_n_run_no_cache: it_build_no_cache
	@make it_run

# Ensure builder target
ensure_builder:
	@docker buildx inspect multi-arch-builder >/dev/null 2>&1 || docker buildx create --name multi-arch-builder --use

# Multi-architecture build helpers
define build_arch
	@make it_clean
	@make ensure_builder	
	docker buildx build --platform linux/$(1) \
		-t $(2):$(1)-$(IMAGE_TAG) \
		-t $(2):$(1)-latest \
		--build-arg ARCH=$(1) \
		--load . && \
	docker push $(2):$(1)-$(IMAGE_TAG) && \
	docker push $(2):$(1)-latest
endef

# Clean old manifests
clean-manifests-dockerhub:
	docker manifest rm $(IMAGE_NAME):$(IMAGE_TAG) || true
	docker manifest rm $(IMAGE_NAME):latest || true

clean-manifests-ghcr:
	docker manifest rm $(GHCR_IMAGE_NAME):$(IMAGE_TAG) || true
	docker manifest rm $(GHCR_IMAGE_NAME):latest || true

# Build individual architectures for Docker Hub
build-amd64-dockerhub:
	@echo "Building AMD64 for Docker Hub"
	$(call build_arch,amd64,$(IMAGE_NAME))

build-arm64-dockerhub:
	@echo "Building ARM64 for Docker Hub"
	$(call build_arch,arm64,$(IMAGE_NAME))

# Build individual architectures for GHCR
build-amd64-ghcr:
	@echo "Building AMD64 for GHCR"
	$(call build_arch,amd64,$(GHCR_IMAGE_NAME))

build-arm64-ghcr:
	@echo "Building ARM64 for GHCR"
	$(call build_arch,arm64,$(GHCR_IMAGE_NAME))

# Create and push manifests for Docker Hub
create-manifest-dockerhub: build-amd64-dockerhub build-arm64-dockerhub
	@echo "Creating Docker Hub manifests for version $(IMAGE_TAG)"
	docker manifest create \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		$(IMAGE_NAME):amd64-$(IMAGE_TAG) \
		$(IMAGE_NAME):arm64-$(IMAGE_TAG)
	docker manifest push $(IMAGE_NAME):$(IMAGE_TAG)
	docker manifest create \
		$(IMAGE_NAME):latest \
		$(IMAGE_NAME):amd64-latest \
		$(IMAGE_NAME):arm64-latest
	docker manifest push $(IMAGE_NAME):latest

# Create and push manifests for GHCR
create-manifest-ghcr: build-amd64-ghcr build-arm64-ghcr
	@echo "Creating GHCR manifests for version $(IMAGE_TAG)"
	docker manifest create \
		$(GHCR_IMAGE_NAME):$(IMAGE_TAG) \
		$(GHCR_IMAGE_NAME):amd64-$(IMAGE_TAG) \
		$(GHCR_IMAGE_NAME):arm64-$(IMAGE_TAG)
	docker manifest push $(GHCR_IMAGE_NAME):$(IMAGE_TAG)
	docker manifest create \
		$(GHCR_IMAGE_NAME):latest \
		$(GHCR_IMAGE_NAME):amd64-latest \
		$(GHCR_IMAGE_NAME):arm64-latest
	docker manifest push $(GHCR_IMAGE_NAME):latest

# Main multi-arch build targets
it_build_multi_arch_push_docker_hub: clean-manifests-dockerhub create-manifest-dockerhub
	@echo "Completed Docker Hub multi-arch build and push for version $(IMAGE_TAG)"

# Builds and pushed to the GitHub Container Registry
it_build_multi_arch_push_GHCR: clean-manifests-ghcr create-manifest-ghcr
	@echo "Completed GHCR multi-arch build and push for version $(IMAGE_TAG)"

# Build both registries
it_build_multi_arch_all: it_build_multi_arch_push_docker_hub it_build_multi_arch_push_GHCR
	@echo "Completed all multi-arch builds and pushes for version $(IMAGE_TAG)"

# Utility target to show current version
show-version:
	@echo "Current version: $(IMAGE_TAG)"

.PHONY: release it_build it_build_no_cache dev_run it_run it_build_n_run it_build_n_run_no_cache \
	clean-manifests-dockerhub clean-manifests-ghcr \
	build-amd64-dockerhub build-arm64-dockerhub \
	build-amd64-ghcr build-arm64-ghcr \
	create-manifest-dockerhub create-manifest-ghcr \
	it_build_multi_arch_push_docker_hub it_build_multi_arch_push_GHCR \
	it_build_multi_arch_all show-version \
	require_gitflow_next


# Version Management with Git Flow
# --------------------------------
# These commands manage semantic versioning with Git Flow workflow.
# All version tags start with 'v' (e.g., v1.2.3) following semantic versioning principles:
# - major_release: Increments the first number (e.g., v1.2.3 -> v2.0.0)
# - minor_release: Increments the second number (e.g., v1.2.3 -> v1.3.0)
# - patch_release: Increments the third number (e.g., v1.2.3 -> v1.2.4)
# - hotfix: Adds or increments a fourth number (e.g., v1.2.3 -> v1.2.3.1)
#
# The 'v' prefix is consistently preserved in all version tags and branches.

require_gitflow_next:
	@if ! git flow version 2>/dev/null | grep -q 'git-flow-next'; then \
		echo "Error: git-flow-next required (Go rewrite). Install: brew install git-flow-next"; \
		exit 1; \
	fi

minor_release: require_gitflow_next
	# Start a minor release with incremented minor version
	git flow release start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1"."$$2+1".0"}')

patch_release: require_gitflow_next
	# Start a patch release with incremented patch version
	git flow release start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1"."$$2"."$$3+1}')

major_release: require_gitflow_next
	# Start a major release with incremented major version
	git flow release start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1+1".0.0"}')

hotfix: require_gitflow_next
	# Start a hotfix with incremented patch.patch version (fourth component)
	git flow hotfix start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{if (NF < 4) print $$1"."$$2"."$$3".1"; else print $$1"."$$2"."$$3"."$$4+1}')

release_finish: require_gitflow_next
	git flow release finish && git push origin develop && git push origin master && git push --tags && git checkout develop

hotfix_finish: require_gitflow_next
	git flow hotfix finish && git push origin develop && git push origin master && git push --tags && git checkout develop

things_clean:
	git clean --exclude=!.env -Xdf

it_deploy:
	caprover deploy --default

# ---------------------------------------------------------------------------
# Interactive release: git-release from the sage-is/apps tap
# ---------------------------------------------------------------------------
release:
	@command -v git-release >/dev/null || { echo "Needs git-release: brew tap sage-is/apps && brew trust --tap sage-is/apps && brew install git-release"; exit 1; }
	@git-release

## >>> startr worktree block v1 (startr.sh/Makefile, 2026-11-12) >>>
## One checkout per repo. A worktree is for one parallel task, and it goes
## the day its branch lands; a landed branch goes too. wt_check fails while
## either lingers, so the rule is a gate, not a memory.
## To update a repo, replace everything between the two marker lines.
## Guide: https://startr.sh/docs/makefile-worktrees/
##   make wt NAME=quick-note       feature/quick-note from WT_BASE, in ../<repo>-wt/quick-note
##   make wt NAME=fix/typo         a name with a slash is the branch; the folder is fix-typo
##   make wt_list                  each worktree and spare branch: ahead/behind, changes, age
##   make wt_done NAME=quick-note  clean and landed only: removes the worktree and its branch
##   make wt_tidy                  wt_done for every clean, landed worktree and branch
##   make wt_check                 fails on a landed worktree or branch, or one over WT_DAYS
## "Landed" means merging the branch into WT_BASE changes nothing: merged,
## squashed or rebased in. The remote branch is never touched.
WT_BASE ?= $(shell for b in develop main master; do git rev-parse -q --verify "refs/heads/$$b" >/dev/null && { echo $$b; break; }; done)
WT_MAX ?= 3
WT_DAYS ?= 3
WT_KEEP ?= develop main master gh-pages

.PHONY: wt wt_list wt_done wt_tidy wt_check

## Shell functions the five targets share. Every worktree but the main
## checkout prints as "path<TAB>branch" ("-" when detached).
define wt_sh
tab=$$(printf '\t'); now=$$(date +%s); base="$(WT_BASE)"; \
main=$$(cd "$$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd); \
root="$$main-wt"; \
git worktree prune; \
worktrees() { git worktree list --porcelain | awk '/^worktree /{n++; p=substr($$0,10)} n>1 && /^branch /{print p "\t" substr($$0,19)} n>1 && /^detached/{print p "\t-"}'; }; \
spare_branches() { held=$$(git worktree list --porcelain | sed -n 's|^branch refs/heads/||p'); \
	git for-each-ref --format='%(refname:short)' refs/heads | while read -r b; do \
	case " $(WT_KEEP) $$base " in *" $$b "*) continue;; esac; \
	printf '%s\n' "$$held" | grep -qxF "$$b" || echo "$$b"; done; }; \
contained() { git merge-base --is-ancestor "$$1" "$$base" && return 0; \
	t=$$(git merge-tree --write-tree "$$base" "$$1" 2>/dev/null) && [ "$$t" = "$$(git rev-parse "$$base^{tree}")" ]; }; \
worked() { [ "$$(git reflog show "refs/heads/$$1" 2>/dev/null | wc -l | tr -d ' ')" -gt 1 ]; }; \
age() { c=$$(git reflog show --date=unix --format=%gd "refs/heads/$$1" 2>/dev/null | tail -1 | sed -n 's/.*@{\([0-9]*\)}$$/\1/p'); \
	[ -n "$$c" ] && echo $$(( (now - c) / 86400 )) || echo 0; }; \
changes() { git -C "$$1" status --porcelain | wc -l | tr -d ' '; }; \
remove_one() { if [ -n "$$1" ]; then git worktree remove "$$1" || return 1; echo "Removed $$1"; fi; \
	if [ "$$2" != "-" ]; then git branch -D "$$2" >/dev/null && echo "Deleted $$2 (its work is in $$base)"; \
	git rev-parse -q --verify "refs/remotes/origin/$$2" >/dev/null && echo "  origin still has it: git push origin --delete $$2"; fi; \
	rmdir "$$root" 2>/dev/null; true; }
endef

## The bodies of wt_list and wt_check, shared with wt and wt_tidy. They are
## defines, not recursive $(MAKE) calls, so `make -n wt` runs nothing.
define wt_list_sh
echo "base: $${base:-none}"; \
worktrees | while IFS="$$tab" read -r p b; do \
	n=$$(changes "$$p"); line="$$p  $$b  $$n changed"; \
	if [ "$$b" != "-" ] && [ -n "$$base" ]; then \
		line="$$line  +$$(git rev-list --count "$$base..$$b")/-$$(git rev-list --count "$$b..$$base")  $$(age "$$b")d"; \
		[ "$$n" = 0 ] && worked "$$b" && contained "$$b" && line="$$line  LANDED: make wt_done"; \
	fi; echo "$$line"; done; \
[ -n "$$base" ] && spare_branches | while read -r b; do \
	line="branch $$b  +$$(git rev-list --count "$$base..$$b")/-$$(git rev-list --count "$$b..$$base")  $$(age "$$b")d"; \
	contained "$$b" && line="$$line  LANDED: make wt_done NAME=$$b"; echo "$$line"; done; true
endef

define wt_check_sh
[ -n "$$base" ] || { echo "wt_check: no develop, main or master branch here; skipped"; exit 0; }; \
bad=$$( worktrees | while IFS="$$tab" read -r p b; do \
	[ "$$b" = "-" ] && continue; \
	[ "$$(changes "$$p")" = 0 ] && worked "$$b" && contained "$$b" && { echo "  landed worktree: $$p ($$b)"; continue; }; \
	[ "$$(age "$$b")" -le $(WT_DAYS) ] || echo "  $$(age "$$b") days old: $$p ($$b); land it or make wt_done"; done; \
	spare_branches | while read -r b; do contained "$$b" && echo "  landed branch: $$b"; done ); \
[ -z "$$bad" ] || { echo "wt_check failed (WT_DAYS=$(WT_DAYS)):"; echo "$$bad"; echo "make wt_tidy clears what landed; land or drop the rest."; exit 1; }
endef

wt:
	@[ "$(origin NAME)" = "command line" ] || { echo "Usage: make wt NAME=quick-note"; exit 1; }; \
	$(wt_sh); [ -n "$$base" ] || { echo "No develop, main or master branch: set WT_BASE"; exit 1; }; \
	case "$(NAME)" in */*) b="$(NAME)";; *) b="feature/$(NAME)";; esac; \
	dir="$$root/$$(echo "$(NAME)" | tr / -)"; \
	open=$$(worktrees | wc -l | tr -d ' '); \
	[ "$$open" -lt $(WT_MAX) ] || { echo "$$open worktrees open, and WT_MAX is $(WT_MAX). Land one, then make wt_done."; worktrees; exit 1; }; \
	( $(wt_check_sh) ) || { echo "Clear those before a new worktree."; exit 1; }; \
	! git rev-parse -q --verify "refs/heads/$$b" >/dev/null || { echo "$$b already exists"; exit 1; }; \
	git worktree add -q -b "$$b" "$$dir" "$$base" && \
	echo "Ready: cd $$dir ($$b from $$base). When it lands: make wt_done NAME=$(NAME)"

wt_list:
	@$(wt_sh); $(wt_list_sh)

wt_done:
	@[ "$(origin NAME)" = "command line" ] || { echo "Usage: make wt_done NAME=quick-note"; exit 1; }; \
	$(wt_sh); [ -n "$$base" ] || { echo "No develop, main or master branch: set WT_BASE"; exit 1; }; \
	case "$(NAME)" in */*) want="$(NAME)";; *) want="feature/$(NAME)";; esac; \
	dir="$$root/$$(echo "$(NAME)" | tr / -)"; \
	hit=$$(worktrees | awk -F"$$tab" -v d="$$dir" -v b="$$want" '$$1==d || $$2==b {print; exit}'); \
	if [ -n "$$hit" ]; then p=$${hit%%"$$tab"*}; b=$${hit#*"$$tab"}; \
	elif git rev-parse -q --verify "refs/heads/$$want" >/dev/null; then p=; b="$$want"; \
	else echo "No worktree at $$dir and no branch $$want"; exit 1; fi; \
	if [ -n "$$p" ]; then \
		case "$$(pwd -P)/" in "$$(cd "$$p" && pwd -P)/"*) echo "Run it from $$main, not from inside the worktree"; exit 1;; esac; \
		n=$$(changes "$$p"); [ "$$n" = 0 ] || { echo "$$p has $$n uncommitted changes:"; git -C "$$p" status --short; exit 1; }; \
	fi; \
	[ "$$b" = "-" ] || contained "$$b" || { echo "$$b is not in $$base yet: $$(git rev-list --count "$$base..$$b") commits to land"; exit 1; }; \
	remove_one "$$p" "$$b"

wt_tidy:
	@$(wt_sh); [ -n "$$base" ] || { echo "No develop, main or master branch: set WT_BASE"; exit 1; }; \
	worktrees | while IFS="$$tab" read -r p b; do \
		[ "$$b" != "-" ] && [ "$$(changes "$$p")" = 0 ] && worked "$$b" && contained "$$b" && remove_one "$$p" "$$b"; done; \
	spare_branches | while read -r b; do contained "$$b" && remove_one "" "$$b"; done; \
	$(wt_list_sh)

wt_check:
	@$(wt_sh); $(wt_check_sh)
## <<< startr worktree block v1 <<<
