#!/bin/bash
#
# Copyright (c) 2019-2025 longdongqiang-jason
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/longdongqiang-jason/X86
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Modify default IP
sed -i 's/192.168.1.1/192.168.31.66/g' package/base-files/files/bin/config_generate
# 日期
sed -i 's/os.date(/&"%Y-%m-%d %H:%M:%S"/' ./package/lean/autocore/files/x86/index.htm
# 关闭串口跑码
sed -i 's/console=tty0//g' ./target/linux/x86/image/Makefile
sed -i 's/%V, %C/[Year] | by Jason /g' ./package/base-files/files/etc/banner
sed -i "s/Year/$(TZ=':Asia/Shanghai' date '+%Y')/g" ./package/base-files/files/etc/banner
sed -i '/logins./a\                                          by Jason' ./package/base-files/files/etc/profile
# Modify default passwd
sed -i '/$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF./ d' ./package/lean/default-settings/files/zzz-default-settings
# ID
sed -i "s/DISTRIB_REVISION='R.*.*.[0-9]/& Compiled by Jason/" ./package/lean/default-settings/files/zzz-default-settings
sed -i 's/^BUILD_ID=".*"/BUILD_ID="%R Compiled by Jason"/' ./package/base-files/files/usr/lib/os-release
#rm -rf feeds/packages/net/shadowsocks-libev
#./scripts/feeds update -a
#./scripts/feeds install -a
# 主题背景
mkdir -p ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/background/ && curl -o ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/background/Network.mp4 https://raw.githubusercontent.com/longdongqiang-jason/X86/main/other/argon/video/default/Network.mp4
# 临时
sed -i 's/6.12/6.18/g' ./target/linux/x86/Makefile
# lucky
sed -i 's|/etc/lucky|/etc/config/lucky2|g' ./feeds/luci/applications/luci-app-lucky/root/etc/config/lucky
sed -i 's/PKG_VERSION:=2.17.8/PKG_VERSION:=2.27.2/g' ./feeds/packages/net/lucky/Makefile
# 禁用固件更新后跑分
sed -i '/^echo "0 4 \* \* \* \/etc\/coremark.sh" >> \/etc\/crontabs\/root$/d' ./feeds/packages/utils/coremark/coremark
sed -i '/^\[ -n "\$\${IPKG_INSTROOT}" \] \|\| echo "0 4 \* \* \* \/etc\/coremark.sh" >> \/etc\/crontabs\/root$/d' ./feeds/packages/utils/coremark/Makefile
# 同步lede-xray
#cp ./feeds/helloworld/xray-core/Makefile ./feeds/packages/net/xray-core/Makefile
# 自动挂载
# NVMe 自动挂载
mkdir -p files/etc/config
cat > files/etc/config/fstab <<'EOF'
config global
    option anon_swap '0'
    option anon_mount '0'
    option auto_swap '1'
    option auto_mount '1'
    option delay_root '5'
    option check_fs '0'
config mount
    option target '/mnt/nvme0n1p1'
    option uuid 'b3b41f9e-49d4-41d8-b517-965af8d385e6'
    option enabled '1'
EOF
# 网络参数
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/zz-network-optimize.conf <<'EOF'
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.netfilter.nf_conntrack_max=262144
EOF
# ============================================================
# Linux 6.18.58 Shortcut-FE 补丁兼容性修复
# 修复 include/linux/skbuff.h Hunk FAILED
# 保留 CONFIG_SHORTCUT_FE 网络加速功能
# ============================================================
echo "===== 检查 Linux 6.18 Shortcut-FE 补丁 ====="
python3 - <<'PY'
from pathlib import Path
import re
import sys
patch = Path(
    "target/linux/generic/hack-6.18/"
    "953-net-patch-linux-kernel-to-support-shortcut-fe.patch"
)
if not patch.is_file():
    print(f"[ERROR] 找不到补丁文件: {patch}")
    sys.exit(1)
content = patch.read_text()
old_block = (
    " \t__u8\t\t\tunreadable:1;\n"
    "+#ifdef CONFIG_SHORTCUT_FE\n"
    "+\t__u8\t\t\tfast_forwarded:1;\n"
    "+#endif\n"
    " #if defined(CONFIG_NET_SCHED) || defined(CONFIG_NET_XGRESS)"
)
new_block = (
    " \t__u8\t\t\tunreadable:1;\n"
    " \t__u8\t\t\ttc_depth:2;\n"
    "+#ifdef CONFIG_SHORTCUT_FE\n"
    "+\t__u8\t\t\tfast_forwarded:1;\n"
    "+#endif\n"
    " #if defined(CONFIG_NET_SCHED) || defined(CONFIG_NET_XGRESS)"
)
old_header = "@@ -1030,6 +1030,9 @@"
new_header = "@@ -1030,7 +1030,10 @@"
# 已经修复则跳过
if new_block in content and new_header in content:
    print("[OK] Shortcut-FE 补丁已经适配，跳过")
    sys.exit(0)
# 检查原始内容
if content.count(old_block) != 1:
    print("[ERROR] 补丁上下文发生变化，停止修改")
    sys.exit(1)
# 定位 skbuff.h 补丁段
start = content.find("--- a/include/linux/skbuff.h")
if start == -1:
    print("[ERROR] 找不到 skbuff.h 补丁段")
    sys.exit(1)
end = content.find("\n--- a/", start + 1)
if end == -1:
    end = len(content)
section = content[start:end]
if section.count(old_header) != 1:
    print("[ERROR] skbuff.h Hunk 头不匹配")
    sys.exit(1)
# 修改补丁上下文
section = section.replace(old_block, new_block, 1)
# 增加一行上下文，调整 Hunk 行数
section = section.replace(old_header, new_header, 1)
# 合并补丁
content = content[:start] + section + content[end:]
# 验证修改结果
if content.count(new_block) != 1:
    print("[ERROR] 补丁修改验证失败")
    sys.exit(1)
if content.count(new_header) != 1:
    print("[ERROR] Hunk 头验证失败")
    sys.exit(1)
# 写入补丁
patch.write_text(content)
print("[OK] Linux 6.18.58 Shortcut-FE 补丁修复完成")
print("[OK] 已添加 tc_depth:2 上下文")
print("[OK] 已更新 Hunk 行数")
print("[OK] 已保留 CONFIG_SHORTCUT_FE")
PY
if [ $? -ne 0 ]; then
    echo "[ERROR] Shortcut-FE 补丁修复失败"
    exit 1
fi
echo "===== DIY Part 2 执行完成 ====="
