handleSysupgradeConfirm(btn,opts,ev){
if(btn.getAttribute('data-online-update')!=='1'||!opts.keep[0].checked)return this.handleSysupgradeFlashNow(btn,opts,ev);
const start=rpc.declare({object:'x86_online_update',method:'prepare',reject:true,expect:{'':{}}});
const status=rpc.declare({object:'x86_online_update',method:'prepare_status',reject:true,expect:{'':{}}});
ui.showModal('准备固件安装记录',[E('p',{'class':'spinning'},'正在校验固件文件并提取只读根文件系统指纹。完成后开始刷机，请勿同时上传或下载其他固件。')]);
const wait=function(){return status().then(function(r){if(r.error)throw new Error(r.error);if(r.running)return new Promise(function(resolve){window.setTimeout(resolve,1000);}).then(wait);if(!r.ready)throw new Error('准备结果无效，已停止升级');return r;});};
return start().then(function(r){if(r.error)throw new Error(r.error);return wait();}).then(L.bind(function(){this._onlineVerifiedOpts=opts;return this.handleSysupgradeFlashNow(btn,opts,ev);},this)).catch(function(err){ui.showModal('尚未开始刷机',[E('p',{},err.message),E('div',{'class':'right'},E('button',{'class':'btn',click:ui.hideModal},'关闭'))]);});
},handleSysupgradeFlashNow(btn,opts,ev){btn.firstChild.data=_('Flashing…');ui.showModal(_('Flashing…'),[E('p',{'class':'spinning'},_('The system is flashing now.<br /> DO NOT POWER OFF THE DEVICE!<br /> Wait a few minutes before you try to reconnect. It might be necessary to renew the address of your computer to reach the device again, depending on your settings.'))]);const args=[];for(let key in opts)
if(opts[key][0].checked==opts[key][1])
args.push(opts[key][2]);args.push('/tmp/firmware.bin');return fs.exec('/sbin/sysupgrade',args).then(function(reply){
if(reply&&reply.code!==0){ui.showModal('升级命令失败',[E('p',{},'sysupgrade 返回代码：'+reply.code),E('pre',{'style':'white-space:pre-wrap;overflow-wrap:anywhere;'},(reply.stderr||'')+'\n'+(reply.stdout||'')),E('div',{'class':'right'},E('button',{'class':'btn',click:ui.hideModal},'关闭'))]);return;}
if(opts.keep[0].checked)ui.awaitReconnect(window.location.host);else ui.awaitReconnect('192.168.1.1','immortalwrt.lan');
}).catch(function(err){ui.showModal('未收到升级命令结果',[E('p',{},err.message),E('p',{},'若设备已断开连接，可能正在升级，请等待恢复，勿重复刷机；若设备一直在线，请保留此错误信息。'),E('div',{'class':'right'},E('button',{'class':'btn',click:ui.hideModal},'关闭'))]);});},