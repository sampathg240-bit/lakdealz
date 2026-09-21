(function(){
  const base='https://hdnyzxlbowobbteozvlu.supabase.co';
  const key='sb_publishable__l5i73Qd8ac7jO4Y1sIcYw_5POlmbmA';
  const token=()=>localStorage.getItem('lak_access_token');
  const headers=(json=true)=>({apikey:key,Authorization:'Bearer '+(token()||key),...(json?{'Content-Type':'application/json'}:{})});
  function friendlyError(data,status){
    const code=data?.error_code||data?.code||'';
    const raw=data?.msg||data?.message||data?.error_description||data?.error||data?.hint||'';
    if(code==='user_already_exists'||/already registered|already exists/i.test(raw))return 'This email already has an account. Please use Sign in.';
    if(code==='weak_password')return raw||'Password is too weak. Use at least 8 characters.';
    if(code==='email_address_invalid'||/invalid email/i.test(raw))return 'Enter a valid email address.';
    if(/invalid login credentials/i.test(raw))return 'Email or password is incorrect.';
    if(/email not confirmed/i.test(raw))return 'Confirm your email first, then sign in.';
    if(/database error|saving new user/i.test(raw))return 'Account database setup is incomplete. Please contact the administrator.';
    if(status===429)return 'Too many attempts. Please wait a moment and try again.';
    return raw||('Request failed ('+status+'). Please try again.');
  }
  async function request(path,options={}){let res;try{res=await fetch(base+path,{...options,headers:{...headers(options.json!==false),...(options.headers||{})}})}catch{throw new Error('Could not connect to the account server. Check your internet connection.')}let data=null;try{data=await res.json()}catch{}if(!res.ok)throw new Error(friendlyError(data,res.status));return data}
  async function signUp(email,password,name,phone){const redirect=encodeURIComponent(location.origin+'/account/');const data=await request('/auth/v1/signup?redirect_to='+redirect,{method:'POST',body:JSON.stringify({email,password,data:{name,phone}})});if(data.access_token){localStorage.setItem('lak_access_token',data.access_token);localStorage.setItem('lak_refresh_token',data.refresh_token)}return data}
  async function signIn(email,password){const data=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})});localStorage.setItem('lak_access_token',data.access_token);localStorage.setItem('lak_refresh_token',data.refresh_token);return data}
  async function signOut(){try{await request('/auth/v1/logout',{method:'POST'})}catch{}localStorage.removeItem('lak_access_token');localStorage.removeItem('lak_refresh_token')}
  async function user(){if(!token())return null;try{return await request('/auth/v1/user')}catch{localStorage.removeItem('lak_access_token');return null}}
  async function listAds(userId){let filter=userId?'&or=(status.eq.approved,user_id.eq.'+encodeURIComponent(userId)+')':'&status=eq.approved';return request('/rest/v1/ads?select=*'+filter+'&order=created_at.desc')}
  async function createAd(ad){const r=await fetch(base+'/rest/v1/ads',{method:'POST',headers:{...headers(),Prefer:'return=representation'},body:JSON.stringify(ad)});const d=await r.json();if(!r.ok)throw new Error(d.message||'Could not publish ad');return d[0]}
  async function watermarkPhoto(file){
    if(!file?.type?.startsWith('image/'))throw new Error('Select a valid JPG, PNG or WebP photo.');
    if(file.size>12*1024*1024)throw new Error('Each original photo must be under 12 MB.');
    const bitmap=await createImageBitmap(file),max=2048,scale=Math.min(1,max/Math.max(bitmap.width,bitmap.height));
    const width=Math.max(1,Math.round(bitmap.width*scale)),height=Math.max(1,Math.round(bitmap.height*scale));
    const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;
    const ctx=canvas.getContext('2d',{alpha:false});ctx.drawImage(bitmap,0,0,width,height);bitmap.close?.();
    const short=Math.min(width,height),pad=Math.max(14,Math.round(short*.025)),fontSize=Math.max(18,Math.min(54,Math.round(short*.047)));
    ctx.save();ctx.globalAlpha=.32;ctx.font='800 '+fontSize+'px Manrope, Arial, sans-serif';ctx.textBaseline='middle';
    const label='LD  LAKDEALZ',metrics=ctx.measureText(label),boxW=Math.ceil(metrics.width+pad*2),boxH=Math.ceil(fontSize*1.75),x=Math.max(pad,width-boxW-pad),y=Math.max(pad,height-boxH-pad);
    ctx.fillStyle='#04182d';ctx.beginPath();if(ctx.roundRect)ctx.roundRect(x,y,boxW,boxH,Math.round(boxH*.25));else ctx.rect(x,y,boxW,boxH);ctx.fill();
    ctx.globalAlpha=.72;ctx.fillStyle='#f2b84b';ctx.fillText('LD',x+pad,y+boxH/2);ctx.fillStyle='#ffffff';ctx.fillText('LAKDEALZ',x+pad+ctx.measureText('LD  ').width,y+boxH/2);ctx.restore();
    const blob=await new Promise((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('Photo processing failed.')),'image/webp',.86));
    return new File([blob],(file.name.replace(/\.[^.]+$/,'')||'lakdealz-photo')+'.webp',{type:'image/webp'});
  }
  async function uploadPhoto(file,userId){const ready=await watermarkPhoto(file);const safe=Date.now()+'-'+Math.random().toString(36).slice(2)+'.webp';const path=userId+'/'+safe;const r=await fetch(base+'/storage/v1/object/ad-photos/'+path,{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token(),'Content-Type':'image/webp','x-upsert':'false','cache-control':'31536000'},body:ready});if(!r.ok){let d=await r.json();throw new Error(d.message||'Photo upload failed')}return base+'/storage/v1/object/public/ad-photos/'+path}
  async function createReport(report){return request('/rest/v1/reports',{method:'POST',headers:{Prefer:'return=minimal'},body:JSON.stringify(report)})}
  function captureSession(){const p=new URLSearchParams(location.hash.slice(1)),access=p.get('access_token'),refresh=p.get('refresh_token');if(!access)return false;localStorage.setItem('lak_access_token',access);if(refresh)localStorage.setItem('lak_refresh_token',refresh);history.replaceState(null,'',location.pathname+location.search);return true}
  window.LakDB={signUp,signIn,signOut,user,listAds,createAd,uploadPhoto,watermarkPhoto,createReport,captureSession,base};
})();
