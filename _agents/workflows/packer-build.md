---
description: Build VM images using Packer
---

This workflow describes how to build VM images locally (Vagrant) or in GCP.

### Prerequisites
1. [Packer](https://www.packer.io/downloads) installed.
2. [Vagrant](https://www.vagrantup.com/downloads) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (for local builds).
3. [GCP SDK](https://cloud.google.com/sdk/docs/install) (for cloud builds).

### Steps

1. **Initialize Packer**
// turbo
```bash
make packer-init
```

2. **Build Local Image (Vagrant/VirtualBox)**
// turbo
```bash
make packer-build-local
```

3. **Build GCP Cloud Image**
// turbo
```bash
make packer-build-gcp
```

### Configuration
Variables can be customized in `packer/variables.pkr.hcl` or by passing `-var` flags to the packer command.
