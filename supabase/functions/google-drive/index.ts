// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

interface ReqPayload {
  name: string;
}

console.info("server started");

export default {
  fetch: withSupabase({ auth: ["publishable", "secret"] }, async (req, ctx) => {
    const { name }: ReqPayload = await req.json();

    // Using 'sb_secret_xyz' bypasses RLS — use for privileged operations
    if (ctx.authMode === "secret") {
      return Response.json({
        message: `Hello ${name} admin!`,
      });
    }

    return Response.json({
      message: `Hello ${name}!`,
    });
  }),
};import { createClient } from 'npm:@supabase/supabase-js@2.95.0'

const corsHeaders={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'GET, POST, OPTIONS',
  'Content-Type':'application/json'
}
const appUrl=Deno.env.get('GOOGLE_DRIVE_APP_URL')||'https://pheloxapp.com/'
const redirectUri=Deno.env.get('GOOGLE_DRIVE_REDIRECT_URI')||`${Deno.env.get('SUPABASE_URL')}/functions/v1/google-drive`
const clientId=Deno.env.get('GOOGLE_DRIVE_CLIENT_ID')||''
const clientSecret=Deno.env.get('GOOGLE_DRIVE_CLIENT_SECRET')||''
const driveScope='https://www.googleapis.com/auth/drive.file'

function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:corsHeaders})}
function safeMessage(error:unknown){return error instanceof Error?error.message:String(error)}
function redirect(status:string,detail=''){
  const target=new URL(appUrl)
  target.searchParams.set('drive',status)
  if(detail)target.searchParams.set('drive_message',detail.slice(0,180))
  return Response.redirect(target.toString(),302)
}
function adminClient(){
  return createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}})
}
async function requireSuperAdmin(req:Request,admin:ReturnType<typeof adminClient>){
  const authHeader=req.headers.get('Authorization')||''
  if(!authHeader.startsWith('Bearer '))throw new Error('Sesion invalida')
  const caller=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false,autoRefreshToken:false}})
  const authResult=await caller.auth.getUser()
  const user=authResult.data.user
  if(authResult.error||!user)throw new Error('Sesion invalida')
  const profile=await admin.from('profiles').select('role,active').eq('id',user.id).maybeSingle()
  if(profile.error)throw profile.error
  if(profile.data?.active===false||profile.data?.role!=='superadministrador')throw new Error('Solo el superadministrador puede configurar Google Drive')
  return user
}
async function tokenFromRefresh(refreshToken:string){
  if(!clientId||!clientSecret)throw new Error('Falta completar la configuracion OAuth de Google Drive')
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:clientId,client_secret:clientSecret,refresh_token:refreshToken,grant_type:'refresh_token'})})
  const data=await response.json()
  if(!response.ok||!data.access_token)throw new Error(data.error_description||data.error||'Google no pudo renovar la autorizacion')
  return String(data.access_token)
}
async function driveJson(url:string,accessToken:string,options:RequestInit={}){
  const headers=new Headers(options.headers||{})
  headers.set('Authorization',`Bearer ${accessToken}`)
  const response=await fetch(url,{...options,headers})
  let data:any=null
  if(response.status!==204){try{data=await response.json()}catch{/* respuesta sin JSON */}}
  if(!response.ok)throw new Error(data?.error?.message||`Google Drive respondio ${response.status}`)
  return data
}
function decodeBase64(value:string){
  const binary=atob(value),bytes=new Uint8Array(binary.length)
  for(let index=0;index<binary.length;index++)bytes[index]=binary.charCodeAt(index)
  return bytes
}
function multipartBody(metadata:Record<string,unknown>,bytes:Uint8Array,mime:string){
  const boundary=`gestion_phelox_${crypto.randomUUID().replaceAll('-','')}`
  const encoder=new TextEncoder()
  const head=encoder.encode(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n--${boundary}\r\nContent-Type: ${mime}\r\n\r\n`)
  const tail=encoder.encode(`\r\n--${boundary}--`)
  const body=new Uint8Array(head.length+bytes.length+tail.length)
  body.set(head,0);body.set(bytes,head.length);body.set(tail,head.length+bytes.length)
  return {boundary,body}
}
async function uploadFile(accessToken:string,metadata:Record<string,unknown>,bytes:Uint8Array,mime:string){
  const multipart=multipartBody(metadata,bytes,mime)
  return driveJson('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,createdTime,webViewLink',accessToken,{method:'POST',headers:{'Content-Type':`multipart/related; boundary=${multipart.boundary}`},body:multipart.body})
}
async function ensureFolder(accessToken:string,connection:any){
  if(connection.folder_id){
    try{
      const current=await driveJson(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(connection.folder_id)}?fields=id,trashed`,accessToken)
      if(current&&!current.trashed)return current.id
    }catch{/* buscar o crear nuevamente */}
  }
  const q=encodeURIComponent("trashed=false and mimeType='application/vnd.google-apps.folder' and appProperties has { key='gestionPhelox' and value='backupFolder' }")
  const found=await driveJson(`https://www.googleapis.com/drive/v3/files?q=${q}&fields=files(id,name)&spaces=drive`,accessToken)
  if(found?.files?.length)return found.files[0].id
  const created=await driveJson('https://www.googleapis.com/drive/v3/files?fields=id,name',accessToken,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:connection.folder_name||'Respaldos Gestion Phelox',mimeType:'application/vnd.google-apps.folder',appProperties:{gestionPhelox:'backupFolder'}})})
  return created.id
}
async function trimBackups(accessToken:string,folderId:string,kind:string,retention:number){
  const q=encodeURIComponent(`'${folderId}' in parents and trashed=false and appProperties has { key='gestionPhelox' and value='${kind}' }`)
  const result=await driveJson(`https://www.googleapis.com/drive/v3/files?q=${q}&orderBy=createdTime%20desc&pageSize=1000&fields=files(id,name,createdTime)&spaces=drive`,accessToken)
  for(const file of (result?.files||[]).slice(retention))await driveJson(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(file.id)}`,accessToken,{method:'DELETE'})
}

Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  const admin=adminClient()
  if(req.method==='GET'){
    const requestUrl=new URL(req.url),code=requestUrl.searchParams.get('code')||'',state=requestUrl.searchParams.get('state')||'',oauthError=requestUrl.searchParams.get('error')||''
    if(oauthError)return redirect('error',oauthError)
    if(!code||!state)return redirect('error','Respuesta incompleta de Google')
    try{
      const stateResult=await admin.from('google_drive_oauth_states').select('state,user_id,expires_at').eq('state',state).maybeSingle()
      if(stateResult.error)throw stateResult.error
      if(!stateResult.data||new Date(stateResult.data.expires_at).getTime()<Date.now())throw new Error('La autorizacion vencio. Inicia la conexion nuevamente')
      await admin.from('google_drive_oauth_states').delete().eq('state',state)
      if(!clientId||!clientSecret)throw new Error('Falta completar la configuracion OAuth')
      const tokenResponse=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:clientId,client_secret:clientSecret,code,grant_type:'authorization_code',redirect_uri:redirectUri})})
      const tokenData=await tokenResponse.json()
      if(!tokenResponse.ok)throw new Error(tokenData.error_description||tokenData.error||'Google no entrego la autorizacion')
      const existing=await admin.from('google_drive_connections').select('refresh_token,folder_id,folder_name,retention').eq('id','primary').maybeSingle()
      const refreshToken=String(tokenData.refresh_token||existing.data?.refresh_token||'')
      if(!refreshToken)throw new Error('Google no entrego una autorizacion permanente. Intenta conectar nuevamente')
      const saved=await admin.from('google_drive_connections').upsert({id:'primary',refresh_token:refreshToken,scope:String(tokenData.scope||driveScope),folder_id:existing.data?.folder_id||null,folder_name:existing.data?.folder_name||'Respaldos Gestion Phelox',retention:existing.data?.retention||10,connected_by:stateResult.data.user_id,connected_at:new Date().toISOString(),last_status:'Google Drive conectado de forma permanente',updated_at:new Date().toISOString()},{onConflict:'id'})
      if(saved.error)throw saved.error
      return redirect('connected')
    }catch(error){return redirect('error',safeMessage(error))}
  }
  if(req.method!=='POST')return json({error:'Metodo no permitido'},405)
  try{
    const user=await requireSuperAdmin(req,admin)
    const body=await req.json(),action=String(body?.action||'status')
    if(action==='status'){
      const result=await admin.from('google_drive_connections').select('folder_id,folder_name,retention,connected_at,last_backup_at,last_file_name,last_status').eq('id','primary').maybeSingle()
      if(result.error)throw result.error
      return json({connected:!!result.data,...(result.data||{})})
    }
    if(action==='authorize'){
      if(!clientId||!clientSecret)throw new Error('Falta completar la configuracion OAuth de Google Drive')
      const state=crypto.randomUUID()+crypto.randomUUID().replaceAll('-','')
      await admin.from('google_drive_oauth_states').delete().lt('expires_at',new Date().toISOString())
      const saved=await admin.from('google_drive_oauth_states').insert({state,user_id:user.id,expires_at:new Date(Date.now()+10*60*1000).toISOString()})
      if(saved.error)throw saved.error
      const params=new URLSearchParams({client_id:clientId,redirect_uri:redirectUri,response_type:'code',scope:driveScope,access_type:'offline',prompt:'consent',include_granted_scopes:'true',state})
      return json({authorizationUrl:`https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`})
    }
    if(action==='settings'){
      const retention=Math.max(1,Math.min(365,Number(body?.retention)||10))
      const result=await admin.from('google_drive_connections').update({retention,updated_at:new Date().toISOString()}).eq('id','primary').select('retention').maybeSingle()
      if(result.error)throw result.error
      return json({saved:!!result.data,retention})
    }
    if(action==='disconnect'){
      const connection=await admin.from('google_drive_connections').select('refresh_token').eq('id','primary').maybeSingle()
      if(connection.data?.refresh_token)await fetch(`https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(connection.data.refresh_token)}`,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'}}).catch(()=>null)
      const removed=await admin.from('google_drive_connections').delete().eq('id','primary')
      if(removed.error)throw removed.error
      return json({disconnected:true})
    }
    if(action==='backup'){
      const connectionResult=await admin.from('google_drive_connections').select('*').eq('id','primary').maybeSingle()
      if(connectionResult.error)throw connectionResult.error
      const connection=connectionResult.data
      if(!connection)throw new Error('Google Drive no esta conectado')
      const jsonText=String(body?.jsonText||''),excelBase64=String(body?.excelBase64||'')
      if(!jsonText||!excelBase64)throw new Error('El respaldo JSON o Excel esta vacio')
      const accessToken=await tokenFromRefresh(connection.refresh_token),folderId=await ensureFolder(accessToken,connection)
      const reason=String(body?.reason||'Respaldo manual'),jsonName=String(body?.jsonName||`respaldo-${Date.now()}.json`),excelName=String(body?.excelName||jsonName.replace(/\.json$/i,'.xlsx'))
      const jsonMetadata={name:jsonName,parents:[folderId],mimeType:'application/json',description:reason,appProperties:{gestionPhelox:'backup',backupFormat:'gestion-flota-completo'}}
      const excelMime='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      const excelMetadata={name:excelName,parents:[folderId],mimeType:excelMime,description:reason,appProperties:{gestionPhelox:'backupExcel',backupFormat:'gestion-flota-excel'}}
      const jsonUploaded=await uploadFile(accessToken,jsonMetadata,new TextEncoder().encode(jsonText),'application/json')
      const excelUploaded=await uploadFile(accessToken,excelMetadata,decodeBase64(excelBase64),excelMime)
      const retention=Math.max(1,Math.min(365,Number(connection.retention)||10))
      await Promise.all([trimBackups(accessToken,folderId,'backup',retention),trimBackups(accessToken,folderId,'backupExcel',retention)])
      const completedAt=new Date().toISOString(),fileName=`${jsonUploaded.name} + ${excelUploaded.name}`
      const updated=await admin.from('google_drive_connections').update({folder_id:folderId,last_backup_at:completedAt,last_file_name:fileName,last_status:'JSON y Excel guardados correctamente',updated_at:completedAt}).eq('id','primary')
      if(updated.error)throw updated.error
      return json({saved:true,folderId,lastBackup:completedAt,fileName,jsonFile:jsonUploaded,excelFile:excelUploaded})
    }
    return json({error:'Accion desconocida'},400)
  }catch(error){
    const message=safeMessage(error),status=/Sesion invalida/.test(message)?401:/Solo el superadministrador/.test(message)?403:400
    return json({error:message},status)
  }
})
