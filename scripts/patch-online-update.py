#!/usr/bin/env python3
"""Integrate online updates into the current LuCI flash view before building."""
from pathlib import Path
import re
import sys

MARKER = '// X86-ONLINE-UPDATE-INTEGRATION-v1'

def once(text, pattern, replacement, label):
    matches = list(re.finditer(pattern, text, flags=re.MULTILINE))
    if len(matches) != 1:
        raise RuntimeError(f'{label}: expected one upstream hook, got {len(matches)}; no page written')
    m = matches[0]
    value = replacement(m) if callable(replacement) else replacement
    return text[:m.start()] + value + text[m.end():]

AUTO_ENTRY_MARKER = '// X86-ONLINE-UPDATE-AUTO-ENTRY-v1'

def patch_auto_entry(text):
    if AUTO_ENTRY_MARKER in text:
        return text
    replacement = """// X86-ONLINE-UPDATE-AUTO-ENTRY-v1
        return m.render().then(L.bind(function(node) {
            if (has_sysupgrade &&
                new URLSearchParams(window.location.search).get('online_update') === '1') {
                window.setTimeout(L.bind(function() {
                    var btn = E('button', {
                        'type': 'button',
                        'data-online-update': '1'
                    }, '检查最新版 / 在线下载');
                    this.handleOnlineFirmware(
                        storage_size, has_rootfs_data, { target: btn }
                    );
                }, this), 0);
            }
            return node;
        }, this));"""
    return once(text, r'return\s+m\.render\(\);', replacement, 'automatic online update entry')

def patch(text, resources):
    if MARKER in text:
        return patch_auto_entry(text)
    online = (resources / 'online-method.js').read_text()
    confirm = (resources / 'confirm-methods.js').read_text()
    text = once(text, r'(?P<indent>^[ \t]*)handleSysupgrade\(storage_size,\s*has_rootfs_data,\s*ev\)\s*\{',
        lambda m: m['indent'] + online + '\n' + m[0], 'online handler')
    text = once(text, r"return ui\.uploadFile\('/tmp/firmware\.bin',\s*ev\.target\.firstChild\)",
        "return (ev.onlineReply ? Promise.resolve(ev.onlineReply) : ui.uploadFile('/tmp/firmware.bin', ev.target.firstChild))", 'online upload adapter')
    text = once(text, r"btn\.firstChild\.data\s*=\s*_\('Flash image\.\.\.'\);",
        "btn.firstChild.data = btn.getAttribute('data-online-update') === '1' ? '检查最新版 / 在线下载' : _('Flash image...');", 'button reset')
    text = once(text, r'^\s*handleSysupgradeConfirm\(btn,\s*opts,\s*ev\)\s*\{[\s\S]*?(?=^\s*handleBackupList\(ev\))',
        '\n' + confirm + '\n', 'upgrade handoff')
    text = once(text, r"(?P<i>^[ \t]*)o\.onclick\s*=\s*L\.bind\(this\.handleSysupgrade,\s*this,\s*storage_size,\s*has_rootfs_data\);",
        lambda m: m[0] + '\n' + m['i'] + "o = ss.option(form.Button, 'online_sysupgrade', '在线更新');\n" + m['i'] + "o.inputstyle = 'action important';\n" + m['i'] + "o.inputtitle = '检查最新版 / 在线下载';\n" + m['i'] + 'o.onclick = L.bind(this.handleOnlineFirmware, this, storage_size, has_rootfs_data);', 'online button')
    text = once(text, r"body\.push\(E\('p',\s*\{\},\s*E\('label',\s*\{\s*'class':\s*'btn'\s*\},\s*\[\s*opts\.keep\[0\],[\s\S]*?\]\)\)\);",
        lambda m: m[0] + "\nif (ev.onlineReply) body.push(E('p', {}, '保留配置时，重启并验证实际根文件系统及内核后，自动记录已安装固件 SHA256；不保留配置则无法保留记录。'));", 'installation record note')
    return MARKER + '\n' + patch_auto_entry(text)

def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    resources = Path(__file__).resolve().parent / 'online-update'
    target = root / 'feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js'
    if not target.is_file():
        raise RuntimeError(f'LuCI flash view not found: {target}')
    result = patch(target.read_text(), resources)
    # Overlay modes must be set before image construction; GitHub web uploads lose executable bits.
    for relative in ['usr/libexec/rpcd/x86_online_update', 'usr/libexec/x86-online-update-worker', 'usr/libexec/x86-online-record', 'etc/init.d/x86-online-record', 'etc/uci-defaults/99-x86-online-update']:
        path = root / 'files' / relative
        if not path.is_file():
            raise RuntimeError(f'Online update overlay missing: {path}')
    for relative in ['usr/libexec/rpcd/x86_online_update', 'usr/libexec/x86-online-update-worker', 'usr/libexec/x86-online-record', 'etc/init.d/x86-online-record', 'etc/uci-defaults/99-x86-online-update']:
        (root / 'files' / relative).chmod(0o755)
    temp = target.with_suffix('.online-new')
    temp.write_text(result)
    temp.replace(target)
    print('LuCI online update integrated; native /tmp/firmware.bin handoff preserved')

if __name__ == '__main__':
    main()
