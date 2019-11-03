#!/usr/bin/make -f

SHELL := /bin/sh
.SHELLFLAGS := -eu -c

DOCKER := $(shell command -v docker 2>/dev/null)
GIT := $(shell command -v git 2>/dev/null)

DISTDIR := ./dist
VERSION_FILE = ./VERSION
DOCKERFILE := ./Dockerfile

IMAGE_REGISTRY := docker.io
IMAGE_NAMESPACE := hectormolinero
IMAGE_PROJECT := qemu-user-static
IMAGE_NAME := $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_PROJECT)

IMAGE_VERSION := v0
ifneq ($(wildcard $(VERSION_FILE)),)
	IMAGE_VERSION := $(shell cat '$(VERSION_FILE)')
endif

IMAGE_NATIVE_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).txz
IMAGE_AMD64_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).amd64.txz
IMAGE_ARM64V8_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm64v8.txz
IMAGE_ARM32V7_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm32v7.txz
IMAGE_S390X_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).s390x.txz

##################################################
## "all" target
##################################################

.PHONY: all
all: save-native-image

##################################################
## "build-*" targets
##################################################

.PHONY: build-native-image
build-native-image:
	'$(DOCKER)' build \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)' \
		--tag '$(IMAGE_NAME):latest' \
		--file '$(DOCKERFILE)' ./

.PHONY: build-cross-images
build-cross-images: build-amd64-image build-arm64v8-image build-arm32v7-image build-s390x-image

.PHONY: build-amd64-image
build-amd64-image:
	'$(DOCKER)' build \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-amd64' \
		--tag '$(IMAGE_NAME):latest-amd64' \
		--build-arg CROSS_PREFIX=x86_64-linux-gnu- \
		--build-arg DPKG_ARCH=amd64 \
		--file '$(DOCKERFILE)' ./

.PHONY: build-arm64v8-image
build-arm64v8-image:
	'$(DOCKER)' build \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8' \
		--tag '$(IMAGE_NAME):latest-arm64v8' \
		--build-arg CROSS_PREFIX=aarch64-linux-gnu- \
		--build-arg DPKG_ARCH=arm64 \
		--file '$(DOCKERFILE)' ./

.PHONY: build-arm32v7-image
build-arm32v7-image:
	'$(DOCKER)' build \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7' \
		--tag '$(IMAGE_NAME):latest-arm32v7' \
		--build-arg CROSS_PREFIX=arm-linux-gnueabihf- \
		--build-arg DPKG_ARCH=armhf \
		--file '$(DOCKERFILE)' ./

.PHONY: build-s390x-image
build-s390x-image:
	'$(DOCKER)' build \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-s390x' \
		--tag '$(IMAGE_NAME):latest-s390x' \
		--build-arg CROSS_PREFIX=s390x-linux-gnu- \
		--build-arg DPKG_ARCH=s390x \
		--file '$(DOCKERFILE)' ./

##################################################
## "save-*" targets
##################################################

define save_image
	'$(DOCKER)' save '$(1)' | xz -T0 > '$(2)'
endef

.PHONY: save-native-image
save-native-image: $(IMAGE_NATIVE_TARBALL)

$(IMAGE_NATIVE_TARBALL): build-native-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION),$@)

.PHONY: save-cross-images
save-cross-images: save-amd64-image save-arm64v8-image save-arm32v7-image save-s390x-image

.PHONY: save-amd64-image
save-amd64-image: $(IMAGE_AMD64_TARBALL)

$(IMAGE_AMD64_TARBALL): build-amd64-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$@)

.PHONY: save-arm64v8-image
save-arm64v8-image: $(IMAGE_ARM64V8_TARBALL)

$(IMAGE_ARM64V8_TARBALL): build-arm64v8-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$@)

.PHONY: save-arm32v7-image
save-arm32v7-image: $(IMAGE_ARM32V7_TARBALL)

$(IMAGE_ARM32V7_TARBALL): build-arm32v7-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7,$@)

.PHONY: save-s390x-image
save-s390x-image: $(IMAGE_S390X_TARBALL)

$(IMAGE_S390X_TARBALL): build-s390x-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-s390x,$@)

##################################################
## "load-*" targets
##################################################

define load_image
	'$(DOCKER)' load -i '$(1)'
endef

define tag_image
	'$(DOCKER)' tag '$(1)' '$(2)'
endef

.PHONY: load-native-image
load-native-image:
	$(call load_image,$(IMAGE_NATIVE_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):latest)

.PHONY: load-cross-images
load-cross-images: load-amd64-image load-arm64v8-image load-arm32v7-image load-s390x-image

.PHONY: load-amd64-image
load-amd64-image:
	$(call load_image,$(IMAGE_AMD64_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$(IMAGE_NAME):latest-amd64)

.PHONY: load-arm64v8-image
load-arm64v8-image:
	$(call load_image,$(IMAGE_ARM64V8_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$(IMAGE_NAME):latest-arm64v8)

.PHONY: load-arm32v7-image
load-arm32v7-image:
	$(call load_image,$(IMAGE_ARM32V7_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7,$(IMAGE_NAME):latest-arm32v7)

.PHONY: load-s390x-image
load-s390x-image:
	$(call load_image,$(IMAGE_S390X_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-s390x,$(IMAGE_NAME):latest-s390x)

##################################################
## "push-*" targets
##################################################

define push_image
	'$(DOCKER)' push '$(1)'
endef

define push_cross_manifest
	'$(DOCKER)' manifest create --amend '$(1)' '$(2)-amd64' '$(2)-arm64v8' '$(2)-arm32v7' '$(2)-s390x'
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-amd64' --os linux --arch amd64
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm64v8' --os linux --arch arm64 --variant v8
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm32v7' --os linux --arch arm --variant v7
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-s390x' --os linux --arch s390x
	'$(DOCKER)' manifest push --purge '$(1)'
endef

.PHONY: push-native-image
push-native-image:
	@printf '%s\n' 'Unimplemented'

.PHONY: push-cross-images
push-cross-images: push-amd64-image push-arm64v8-image push-arm32v7-image push-s390x-image

.PHONY: push-amd64-image
push-amd64-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64)
	$(call push_image,$(IMAGE_NAME):latest-amd64)

.PHONY: push-arm64v8-image
push-arm64v8-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8)
	$(call push_image,$(IMAGE_NAME):latest-arm64v8)

.PHONY: push-arm32v7-image
push-arm32v7-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7)
	$(call push_image,$(IMAGE_NAME):latest-arm32v7)

.PHONY: push-s390x-image
push-s390x-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-s390x)
	$(call push_image,$(IMAGE_NAME):latest-s390x)

push-cross-manifest:
	$(call push_cross_manifest,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):$(IMAGE_VERSION))
	$(call push_cross_manifest,$(IMAGE_NAME):latest,$(IMAGE_NAME):latest)

##################################################
## "binfmt-*" targets
##################################################

.PHONY: binfmt-register
binfmt-register:
	'$(DOCKER)' run --rm --privileged docker.io/multiarch/qemu-user-static:register

.PHONY: binfmt-reset
binfmt-reset:
	'$(DOCKER)' run --rm --privileged docker.io/multiarch/qemu-user-static:register --reset

##################################################
## "version" target
##################################################

.PHONY: version
version:
	@if printf -- '%s' '$(IMAGE_VERSION)' | grep -q '^v[0-9]\{1,\}$$'; then \
		NEW_IMAGE_VERSION=$$(awk -v 'v=$(IMAGE_VERSION)' 'BEGIN {printf "v%.0f", substr(v,2)+1}'); \
		printf -- '%s\n' "$${NEW_IMAGE_VERSION:?}" > '$(VERSION_FILE)'; \
		'$(GIT)' add '$(VERSION_FILE)'; '$(GIT)' commit -m "$${NEW_IMAGE_VERSION:?}"; \
		'$(GIT)' tag -a "$${NEW_IMAGE_VERSION:?}" -m "$${NEW_IMAGE_VERSION:?}"; \
	else \
		>&2 printf -- 'Malformed version string: %s\n' '$(IMAGE_VERSION)'; \
		exit 1; \
	fi

##################################################
## "clean" target
##################################################

.PHONY: clean
clean:
	rm -f '$(IMAGE_NATIVE_TARBALL)' '$(IMAGE_AMD64_TARBALL)' '$(IMAGE_ARM64V8_TARBALL)' '$(IMAGE_ARM32V7_TARBALL)' '$(IMAGE_S390X_TARBALL)'
	if [ -d '$(DISTDIR)' ] && [ -z "$$(ls -A '$(DISTDIR)')" ]; then rmdir '$(DISTDIR)'; fi
