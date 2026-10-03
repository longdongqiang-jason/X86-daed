#!/bin/bash
#
# Copyright (c) 2019-2025 huajiaoshu520
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/huajiaoshu520/X86
# File name: diy-docker.sh
# Description: OpenWrt DIY script docker (After Update feeds)
#

# dockerman
sed -i 's/+cgroupfs-mount //g' feeds/luci/applications/luci-app-dockerman/Makefile
#sed -i '42i sed -i "/^# the system init finished. By default this file does nothing./a \/etc\/init.d\/cgroupfs-mount disable" \/etc\/rc.local' package/lean/default-settings/files/zzz-default-settings
#rm -rf ./feeds/luci/applications/luci-app-dockerman
#git clone https://github.com/Jason6111/luci-app-dockerman ./feeds/luci/applications/luci-app-dockerman
#rm -rf ./feeds/packages/utils/dockerd
#git clone https://github.com/Jason6111/dockerd ./feeds/packages/utils/dockerd && chmod -R 777 ./feeds/packages/utils/dockerd

# dockerd
# wget https://codeload.github.com/moby/moby/tar.gz/docker-v29.7.2
# sha256sum docker-v29.7.2
sed -i -e 's/29.6.1/29.8.2/g' \
       -e 's/a97bd870c4b072b7d9cc053b2a806ca3d920f192f9dc6a662e17c1b69f56f2e1/5ed520023fe6600579e5c910733814a5ddb7100db41bc3672682a5b50146f6bd/g' \
       -e 's/8ec5ab3/8af9fe3/g' ./feeds/packages/utils/dockerd/Makefile
       
#containerd       
wget -O ./feeds/packages/utils/containerd/Makefile \
  https://raw.githubusercontent.com/huajiaoshu520/X86-daed/refs/heads/main/patches/containerd/Makefile
  
#runc  
wget -O ./feeds/packages/utils/runc/Makefile \
  https://raw.githubusercontent.com/huajiaoshu520/X86-daed/refs/heads/main/patches/runc/Makefile
  
#适配docker29.8.0
#wget -O ./feeds/packages/utils/docker/Makefile \
#  https://raw.githubusercontent.com/huajiaoshu520/X86-daed/refs/heads/main/patches/docker/test
sed -i '/^[[:space:]]*cli\/compose\/schema\/data[[:space:]]*\\$/a\
\tvendor/github.com/santhosh-tekuri/jsonschema/v6/metaschemas \\' ./feeds/packages/utils/docker/Makefile

# docker
# wget https://codeload.github.com/docker/cli/tar.gz/v29.7.2
sed -i -e 's/29.6.1/29.8.2/g' \
       -e 's/74d14dd212b07cd3328989dc6a029dde2ebbe6a878199eaaafad54916f456194/12990af6e98ecc545914820c2c835bdb3303c71439ee3ad0f27ab5341f97f37c/g' \
       -e 's/8900f1d/7fc2dff/g' ./feeds/packages/utils/docker/Makefile

# 禁用
#sed -i -e '\|$(call EnsureVendoredVersion,containerd)|{s/^/# /}' \
#       -e '\|$(call EnsureVendoredVersion,runc)|{s/^/# /}' \
#       ./feeds/packages/utils/dockerd/Makefile
  
# 补丁      
#mkdir -p ./feeds/packages/utils/dockerd/patches
#wget -O ./feeds/packages/utils/dockerd/patches/001-skip-copy-nested-binaries.patch \
#  https://raw.githubusercontent.com/huajiaoshu520/X86-daed/refs/heads/main/patches/dockerd/patches/001-skip-copy-nested-binaries.patch

# docker buildx
#BUILDX_VERSION="0.37.1"

#mkdir -p package/base-files/files/usr/libexec/docker/cli-plugins

#wget -O package/base-files/files/usr/libexec/docker/cli-plugins/docker-buildx \
#  "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64"

#chmod +x package/base-files/files/usr/libexec/docker/cli-plugins/docker-buildx

# fw4 docker
mkdir -p package/base-files/files/etc/docker

cat > package/base-files/files/etc/docker/daemon.json <<'EOF'
{
    "data-root": "/mnt/nvme0n1p1/docker",
    "log-level": "warn",
    "iptables": false,
    "firewall-backend": "nftables",
    "hosts": [
        "unix:///var/run/docker.sock"
    ]
}
EOF

mkdir -p package/base-files/files/etc/config

cat > package/base-files/files/etc/config/dockerd <<'EOF'
config globals 'globals'
        option log_level 'warn'
        option iptables '0'
        option alt_config_file '/etc/docker/daemon.json'
        option data_root '/mnt/nvme0n1p1/docker'
        list hosts 'unix:///var/run/docker.sock'
        option _luci_lan 'lan'

config firewall 'firewall'
        option device 'docker0'
        list blocked_interfaces 'wan'
EOF
