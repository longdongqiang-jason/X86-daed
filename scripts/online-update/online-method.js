handleOnlineFirmware(storage_size,has_rootfs_data,ev){
ev.target.setAttribute('data-online-update','1');
const declare=function(method,params){return rpc.declare({object:'x86_online_update',method:method,params:params||[],reject:true,expect:{'':{}}});};
const check=declare('check'),download=declare('download'),poll=declare('status'),getconfig=declare('getconfig'),setconfig=declare('setconfig',['source','custom_repo']);
let closed=false,timer=null,finished=false,info=null,busy=false,metaLoading=false,comparisonNote='';
const status=E('p',{},'正在读取保存的设置…');
const fill=E('div',{'style':'width:0%'});
const progress=E('div',{'class':'cbi-progressbar',title:'0%',role:'progressbar','aria-label':'固件下载进度','aria-valuemin':'0','aria-valuemax':'100','aria-valuenow':'0'},fill);
const updateProgress=function(bytes,total){const n=total>0?Math.min(100,Math.max(0,bytes/total*100)):0;fill.style.width=n.toFixed(1)+'%';progress.title=n.toFixed(1)+'%';progress.setAttribute('aria-valuenow',n.toFixed(1));};
const close=function(){closed=true;if(timer)window.clearTimeout(timer);ui.hideModal();};
const button=E('button',{'class':'btn cbi-button-action',disabled:true},'下载、对比大小并校验');
const source=E('select',{'class':'cbi-input-select',disabled:true},[E('option',{value:'default'},'默认 · X86-daed GitHub'),E('option',{value:'custom'},'自定义 GitHub 仓库')]);
const custom=E('input',{'class':'cbi-input-text',type:'text',placeholder:'作者/仓库，或 https://github.com/作者/仓库',style:'width:100%',disabled:true});
const customRow=E('div',{style:'margin:12px 0;display:none'},[E('label',{},'自定义仓库'),custom]);
const save=E('button',{'class':'btn cbi-button-action',disabled:true},'保存选项');
const details=E('div');
const showAvailable=function(){details.style.display='';progress.style.display='';button.style.display='';};
const showLatest=function(){
 if(!info||info.comparison!=='matched')return false;
 details.style.display='none';progress.style.display='none';button.style.display='none';button.disabled=true;
 status.textContent='已经是最新版本。';
 status.title='已验证安装记录中的固件 SHA256 与当前更新源的最新固件一致。';return true;
};
const lock=function(v){busy=v;source.disabled=v;custom.disabled=v;save.disabled=v;};
const dirty=function(){if(busy)return;showAvailable();status.title='';info=null;button.disabled=true;details.textContent='';updateProgress(0,0);customRow.style.display=source.value==='custom'?'block':'none';status.textContent='点击“保存选项”以应用来源。';};
source.addEventListener('change',dirty);custom.addEventListener('input',dirty);
ui.showModal('在线更新',[E('p',{},'固件来源'),source,customRow,E('p',{},save),details,progress,status,E('div',{'class':'right'},[E('button',{'class':'btn',click:close},'关闭'),' ',button])]);
const refresh=L.bind(function(){
 if(closed||finished)return;
 return poll().then(L.bind(function(reply){
  if(closed||finished)return;
  if(reply.error){status.textContent=reply.error;lock(false);button.disabled=false;return;}
  if(reply.running){showAvailable();lock(true);button.disabled=true;const bytes=Math.max(0,Number(reply.bytes)||0),total=Number(reply.total)||(info?info.size:0);if(!total&&!info&&!metaLoading){metaLoading=true;inspect().catch(function(){}).finally(function(){metaLoading=false;});}updateProgress(bytes,total);status.textContent=(total>0&&bytes>=total?'下载完成，正在核对大小和 SHA256…':'正在下载：'+(bytes/1048576).toFixed(2)+' MiB'+(total?' / '+(total/1048576).toFixed(2)+' MiB':''))+'。关闭窗口不影响下载。';timer=window.setTimeout(refresh,1000);return;}
  lock(false);
  if(reply.idle){if(showLatest())return;status.textContent='下载后核对字节数和 SHA256，通过后进入升级确认。';button.disabled=false;return;}
  if(!Number.isFinite(reply.size)||!/^[0-9a-f]{64}$/.test(reply.sha256sum||'')){status.textContent='后台返回无效结果，已停止升级。';button.disabled=false;return;}
  updateProgress(reply.size,reply.size);finished=true;close();return this.handleSysupgrade(storage_size,has_rootfs_data,{target:ev.target,onlineReply:reply});
 },this)).catch(function(err){if(closed)return;status.textContent='读取进度失败：'+err.message+'；正在重试。';timer=window.setTimeout(refresh,4000);});
},this);
const inspect=function(){showAvailable();status.title='';lock(true);button.disabled=true;info=null;details.textContent='';status.textContent='正在读取 GitHub 最新发布…';return check().then(function(v){if(v.error)throw new Error(v.error);if(!v.tag||!v.name||!Number.isFinite(v.size)||!/^[0-9a-f]{64}$/.test(v.sha256sum||''))throw new Error('最新固件信息无效');info=v;if(closed)return;
if(v.comparison==='verifying'){
 details.style.display='none';progress.style.display='none';button.style.display='none';
 status.textContent='正在验证已安装固件，完成后自动刷新…';
 return new Promise(function(resolve){window.setTimeout(resolve,1500);}).then(function(){if(!closed)return inspect();});
}
if(showLatest())return;
comparisonNote=v.comparison==='matched'?'已安装固件 SHA256 与最新固件一致。':v.comparison==='different'?'发现不同的固件 SHA256，可查看最新固件并选择更新。':'当前固件尚无已验证 SHA256 记录；通过在线升级并保留配置，重启验证成功后自动建立。';
details.appendChild(E('p',{'style':'position:static;display:block;margin:12px 0;white-space:normal;overflow-wrap:anywhere;font-weight:600;'},comparisonNote));
if(v.installed_sha256)details.appendChild(E('p',{'style':'overflow-wrap:anywhere;word-break:break-all;'},'已安装固件 SHA256：'+v.installed_sha256));
details.appendChild(E('p',{},'最新版本：'+v.tag));details.appendChild(E('p',{},v.name));details.appendChild(E('p',{},'发布文件大小：'+v.size+' 字节（'+(v.size/1048576).toFixed(2)+' MiB）'));details.appendChild(E('p',{'style':'overflow-wrap:anywhere;word-break:break-all;'},'SHA256：'+v.sha256sum));});};
save.addEventListener('click',function(){let repo=custom.value.trim().replace(/^https:\/\/github\.com\//i,'').replace(/\/$/,'').replace(/\.git$/,'');lock(true);button.disabled=true;setconfig(source.value,repo).then(function(v){if(v.error)throw new Error(v.error);custom.value=v.custom_repo;info=null;details.textContent='';updateProgress(0,0);return inspect().then(function(){if(closed)return;lock(false);if(showLatest())return;button.disabled=false;status.textContent='选项已保存，版本信息已刷新。点击下方按钮才会下载并校验。';});}).catch(function(err){if(closed)return;status.textContent=err.message;lock(false);});});
button.addEventListener('click',function(){lock(true);button.disabled=true;inspect().then(function(){if(closed)return null;if(showLatest()){lock(false);return null;}return download();}).then(function(reply){if(!reply)return;if(reply.error)throw new Error(reply.error);return refresh();}).catch(function(err){if(closed)return;status.textContent=err.message;lock(false);button.disabled=false;});});
return getconfig().then(function(v){if(v.error)throw new Error(v.error);source.value=v.source;custom.value=v.custom_repo||'';customRow.style.display=v.source==='custom'?'block':'none';return inspect().then(function(){if(!closed)return refresh();});}).catch(function(err){if(!closed){status.textContent=err.message;lock(false);}});
},



