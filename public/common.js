(() => {
'use strict';
const topics=['사회 변화의 특징과 원인','저출산','고령화','인공지능과 지능정보화','세계화','풍습과 세시 풍속의 의미','두레와 품앗이','일생 동안의 풍습','옛날과 오늘날의 결혼 풍습','명절과 세시 풍속','세시 풍속의 변화'];
const counts=[4,6,6,8,6,4,4,6,4,10,2];
const plants=['해바라기','장미','튤립','데이지','라벤더','벚꽃','사과나무','마법 버섯'];
const stages=['씨앗','새싹','어린잎','마법 꽃','완성된 마법 식물'];
const kinds={choice:'개념 맞히기',picture:'그림 보고 맞히기',ox:'OX 퀴즈',situation:'상황 판단하기',image:'설명 보고 그림 고르기'};
const $=s=>document.querySelector(s);
const el=(tag,cls,text)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined&&text!==null)e.textContent=String(text);return e};
const append=(parent,...items)=>{for(const item of items.flat(Infinity))if(item!=null)parent.append(item);return parent};
const btn=(text,fn,cls='',disabled=false)=>{const b=el('button',cls,text);b.type='button';b.disabled=disabled;b.addEventListener('click',fn);return b};
const panel=(...children)=>append(el('section','panel stack'),...children);
const row=(...children)=>append(el('div','row'),...children);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const stage=n=>n>=30?4:n>=20?3:n>=10?2:n>=5?1:0;
const theme=ts=>ts.some(x=>x<5)&&ts.some(x=>x>=5)?'mixed':ts.some(x=>x<5)?'future':'traditional';
const themeNames={future:'미래의 정원',traditional:'전통의 정원',mixed:'시간을 잇는 마법의 정원'};
const num=n=>el('span','number',n);
const formatTime=sec=>`${Math.floor(Math.max(0,sec)/60).toString().padStart(2,'0')}:${(Math.max(0,sec)%60).toString().padStart(2,'0')}`;
const config=window.MG_CONFIG||{};
const configured=()=>/^https:\/\//.test(config.url||'')&&!!config.key&&!config.key.startsWith('sb_secret_');
let client=null;
function supa(){if(!client&&configured()&&window.supabase?.createClient)client=window.supabase.createClient(config.url,config.key,{auth:{persistSession:false,autoRefreshToken:false}});return client;}
async function rpc(action,args={}){
 if(window.MG_DEMO_RPC)return window.MG_DEMO_RPC(action,args);
 if(!configured())throw Error('Supabase 연결 정보가 없습니다. README.md의 설치 순서에 따라 public/config.js를 설정하세요.');
 let res;try{res=await fetch(config.url.replace(/\/$/,'')+'/rest/v1/rpc/magic_game',{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json',...(config.key.startsWith('eyJ')?{Authorization:'Bearer '+config.key}:{})},body:JSON.stringify({action,args}),signal:AbortSignal.timeout(10000)});}catch(e){throw Error('서버 연결이 원활하지 않습니다. 인터넷과 Supabase 설정을 확인하세요.');}
 let data;try{data=await res.json()}catch{throw Error('서버 응답을 확인할 수 없습니다.');}if(!res.ok)throw Error(data.message||'서버 요청 실패');return data;
}
function signal(id,role,callback,status){const c=supa();if(!c){status?.('주기적 동기화');return()=>{}};const table=role==='teacher'?'room_signals':'room_status_signals';const ch=c.channel(`mg-${role}-${id}-${Math.random().toString(36).slice(2)}`).on('postgres_changes',{event:'UPDATE',schema:'public',table,filter:'id=eq.'+id},callback).subscribe(s=>status?.(s==='SUBSCRIBED'?'실시간 연결':'주기적 동기화'));return()=>c.removeChannel(ch);}
function saved(key,local=false){try{return JSON.parse((local?localStorage:sessionStorage).getItem(key)||'null')}catch{return null}}
function save(key,value,local=false){try{const st=local?localStorage:sessionStorage;if(value==null)st.removeItem(key);else st.setItem(key,JSON.stringify(value));}catch{}}
function toast(text,error=true){const e=$('#toast');if(!e)return;e.className=text?'alert'+(error?' error':''):'';e.textContent=text||'';}
function setupWarning(){if(configured()||window.MG_DEMO_RPC)return null;return el('div','alert','아직 Supabase가 연결되지 않았어요. README.md에 따라 config.js를 설정하면 실시간 게임을 시작할 수 있습니다.');}
function plantSVG(type=0,level=0){
 const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');svg.setAttribute('viewBox','0 0 120 112');svg.setAttribute('class','plant-svg');svg.setAttribute('aria-hidden','true');
 const S=(tag,a)=>{const e=document.createElementNS(ns,tag);for(const [k,v] of Object.entries(a))e.setAttribute(k,String(v));svg.append(e);return e};
 const E=(cx,cy,rx,ry,fill,rotate=0)=>S('ellipse',{cx,cy,rx,ry,fill,transform:`rotate(${rotate} ${cx} ${cy})`});
 const C=(cx,cy,r,fill)=>S('circle',{cx,cy,r,fill});const P=(d,fill,stroke='none',sw=0)=>S('path',{d,fill,stroke,'stroke-width':sw,'stroke-linecap':'round','stroke-linejoin':'round'});
 E(60,103,40,6,'#d7e4ca');P('M35 82 H85 L78 103 H42 Z','#d69a75');P('M40 86 H80 L77 99 H43 Z','#e6b38f');S('rect',{x:31,y:77,width:58,height:10,rx:4,fill:'#bd805e'});E(60,78,24,4,'#8c6342');
 if(level===0){E(60,74,10,5,'#aa7741',-26);return svg;}
 const height=level===1?54:level===2?36:30;P(`M60 78 Q57 54 60 ${height}`,'none','#438957',4);E(48,65,15,6,'#6db267',33);E(71,57,15,6,'#85c576',-34);
 if(level>=2){E(44,46,17,7,'#65aa64',28);E(76,42,17,7,'#83bd70',-33);}
 if(level>=3){
  const palette=['#f4cc58','#d86b89','#e7a1c5','#fffdf1','#aa90d0','#f3b5c5','#a7d477','#e97770'];
  if(type===6){P('M60 77 V35 M60 52 L43 33 M60 50 L77 31','none','#8a6242',7);C(45,31,18,'#7ab872');C(76,32,18,'#83c67a');C(60,21,20,'#60a85f');for(const [x,y] of [[42,25],[64,18],[78,37],[58,42]])C(x,y,5,'#dd6c64');}
  else if(type===7){P('M54 77 Q48 46 55 35 H66 Q72 58 67 77 Z','#fff4d9');P('M27 44 Q29 10 60 10 Q91 10 93 44 Q60 55 27 44 Z','#d96b65');for(const [x,y,r] of [[41,32,4],[60,18,5],[77,32,4],[59,39,3]])C(x,y,r,'#fff0dc');}
  else if(type===2){P('M38 20 L48 31 L60 16 L73 31 L84 20 Q88 54 60 54 Q34 54 38 20 Z',palette[type]);P('M48 31 Q60 22 73 31 Q69 49 60 53 Q52 48 48 31 Z','#ce77a4');}
  else if(type===4){for(let k=0;k<6;k++){const y=13+k*7;E(55,y,9,4,'#a58bd0',-35);E(66,y+2,9,4,'#c2ace8',35);}}
  else{const n=type===0?10:type===1?7:type===3?9:5;for(let k=0;k<n;k++){const a=k*2*Math.PI/n;E(60+Math.cos(a)*16,29+Math.sin(a)*16,11,6,palette[type],a*180/Math.PI);}C(60,29,type===0?12:9,type===0?'#8d6534':'#e9b85b');}
 }
 if(level>=4){for(const [x,y] of [[14,25],[103,17],[95,59]])P(`M${x} ${y-6} l2 4 4 2 -4 2 -2 4 -2 -4 -4 -2 4 -2 Z`,'#e9b94d');E(27,66,9,5,'#98c981',-35);E(93,68,9,5,'#98c981',35);}
 return svg;
}
function plantCard(p,{rank=false,score=true}={}){const c=el('div','plant-card');if(rank)c.append(el('small','number',`${p.rank}위`));append(c,plantSVG(p.plant,p.stage??stage(p.energy||0)),el('strong','',p.nickname),score&&p.energy!=null?el('small','number',`✦ ${p.energy}`):null);return c;}
function rankList(players,limit=12){const list=el('div','stack');const max=Math.max(1,...players.map(p=>p.energy||0));for(const p of players.slice(0,limit)){const b=el('div','rankbar');const fill=el('i');fill.style.width=`${p.energy/max*100}%`;b.append(fill);list.append(append(el('div','rank'),num(p.rank),el('span','',p.nickname),b,num(p.energy)));}return list;}
function resultsList(players){const list=el('div','result-list');for(const p of players){const name=append(el('div'),el('strong','',p.nickname),el('div','muted',`정답 ${p.correct} · 보너스 +${p.bonus}`));list.append(append(el('div','result-row'),num(p.rank+'위'),name,num('✦ '+p.energy)));}return list;}
function timerNode(ring=false){if(ring){const e=el('div','timer-ring');e.dataset.timer='ring';e.append(num('--:--'));return e;}const e=el('div','progress time');e.dataset.timer='bar';e.append(el('i'));return e;}
function updateClock(data,offset){const r=data?.room;if(!r||r.state!=='running')return null;const seconds=Math.max(0,Math.ceil((Date.parse(r.ends_at)-(Date.now()+offset))/1000));const pct=Math.max(0,Math.min(100,seconds/r.duration*100));document.querySelectorAll('[data-timer]').forEach(e=>{e.style.setProperty('--pct',pct+'%');if(e.dataset.timer==='ring')e.querySelector('.number').textContent=formatTime(seconds);});document.querySelectorAll('[data-time-text]').forEach(e=>e.textContent=formatTime(seconds));return seconds;}
function top(label){return append(el('header','top'),Object.assign(el('a','brand','🌿 마법의 정원'),{href:'index.html'}),el('span','pill',label));}
window.MG={topics,counts,plants,stages,kinds,$,el,append,btn,panel,row,sleep,stage,theme,themeNames,num,formatTime,rpc,signal,saved,save,toast,setupWarning,plantSVG,plantCard,rankList,resultsList,timerNode,updateClock,top,configured};
})();
