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
  async function signUp(email,password,name,phone){const data=await request('/auth/v1/signup',{method:'POST',body:JSON.stringify({email,password,data:{name,phone}})});if(data.access_token){localStorage.setItem('lak_access_token',data.access_token);localStorage.setItem('lak_refresh_token',data.refresh_token)}return data}
  async function signIn(email,password){const data=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})});localStorage.setItem('lak_access_token',data.access_token);localStorage.setItem('lak_refresh_token',data.refresh_token);return data}
  async function signOut(){try{await request('/auth/v1/logout',{method:'POST'})}catch{}localStorage.removeItem('lak_access_token');localStorage.removeItem('lak_refresh_token')}
  async function user(){if(!token())return null;try{return await request('/auth/v1/user')}catch{localStorage.removeItem('lak_access_token');return null}}
  async function listAds(userId){let filter=userId?'&or=(status.eq.approved,user_id.eq.'+encodeURIComponent(userId)+')':'&status=eq.approved';return request('/rest/v1/ads?select=*'+filter+'&order=created_at.desc')}
  async function createAd(ad){const r=await fetch(base+'/rest/v1/ads',{method:'POST',headers:{...headers(),Prefer:'return=representation'},body:JSON.stringify(ad)});const d=await r.json();if(!r.ok)throw new Error(d.message||'Could not publish ad');return d[0]}
  async function uploadPhoto(file,userId){const safe=Date.now()+'-'+Math.random().toString(36).slice(2)+'.'+(file.name.split('.').pop()||'jpg');const path=userId+'/'+safe;const r=await fetch(base+'/storage/v1/object/ad-photos/'+path,{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token(),'Content-Type':file.type||'image/jpeg','x-upsert':'false'},body:file});if(!r.ok){let d=await r.json();throw new Error(d.message||'Photo upload failed')}return base+'/storage/v1/object/public/ad-photos/'+path}
  async function createReport(report){return request('/rest/v1/reports',{method:'POST',headers:{Prefer:'return=minimal'},body:JSON.stringify(report)})}
  window.LakDB={signUp,signIn,signOut,user,listAds,createAd,uploadPhoto,createReport,base};
})();
