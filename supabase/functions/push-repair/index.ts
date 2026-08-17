import { createClient } from 'npm:@supabase/supabase-js@2.95.0'
import webpush from 'npm:web-push@3.6.7'

const corsHeaders={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
  'Content-Type':'application/json'
}

function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:corsHeaders})}
function metadata(value:unknown):Record<string,any>{
  if(!value)return {}
  if(typeof value==='object')return value as Record<string,any>
  try{return JSON.parse(String(value))}catch{return {}}
}

Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  if(req.method!=='POST')return json({error:'Metodo no permitido'},405)
  try{
    const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authHeader=req.headers.get('Authorization')||''
    const userClient=createClient(url,anon,{global:{headers:{Authorization:authHeader}}})
    const authResult=await userClient.auth.getUser()
    const user=authResult.data.user
    if(authResult.error||!user)return json({error:'Sesion invalida'},401)

    const body=await req.json(),orderId=String(body?.orderId||''),event=String(body?.event||'')
    if(!orderId||!['requested','accepted','rejected'].includes(event))return json({error:'Datos incompletos'},400)

    const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}})
    const orderResult=await admin.from('maintenance_orders').select('id,title,description,priority,requested_by,assigned_to,notes').eq('id',orderId).single()
    if(orderResult.error||!orderResult.data)return json({error:'Solicitud no encontrada'},404)
    const order=orderResult.data,profileResult=await admin.from('profiles').select('role').eq('id',user.id).maybeSingle()
    const isAdmin=['superadministrador','administrador_general'].includes(String(profileResult.data?.role||''))

    let targetUserId='',title='',message=''
    const meta=metadata(order.notes),vehicle=meta.vehicleLabel||order.title||'vehiculo',requester=meta.requesterName||'Un usuario',recipient=meta.recipientName||'El responsable'
    if(event==='requested'){
      if(order.requested_by!==user.id)return json({error:'No autorizado'},403)
      targetUserId=order.assigned_to;title='Nueva solicitud de reparacion';message=`${requester} solicito reparar ${vehicle}. Prioridad ${order.priority||'normal'}.`
    }else{
      if(order.assigned_to!==user.id&&!isAdmin)return json({error:'No autorizado'},403)
      targetUserId=order.requested_by;title=event==='accepted'?'Reparacion aceptada':'Reparacion rechazada';message=`${recipient} ${event==='accepted'?'acepto':'rechazo'} la solicitud de ${vehicle}.`
    }
    if(!targetUserId)return json({sent:0,reason:'Sin destinatario'})

    const subscriptionsResult=await admin.from('push_subscriptions').select('id,endpoint,p256dh,auth').eq('user_id',targetUserId).eq('active',true)
    if(subscriptionsResult.error)throw subscriptionsResult.error
    const publicKey=Deno.env.get('VAPID_PUBLIC_KEY'),privateKey=Deno.env.get('VAPID_PRIVATE_KEY'),subject=Deno.env.get('VAPID_SUBJECT')||'https://pheloxapp.com'
    if(!publicKey||!privateKey)throw new Error('Faltan las claves VAPID')
    webpush.setVapidDetails(subject,publicKey,privateKey)

    let sent=0,expired:string[]=[],failed=0
    const payload=JSON.stringify({title,body:message,url:'https://pheloxapp.com/?open=messages',tag:`repair-${order.id}`})
    await Promise.all((subscriptionsResult.data||[]).map(async subscription=>{
      try{
        await webpush.sendNotification({endpoint:subscription.endpoint,keys:{p256dh:subscription.p256dh,auth:subscription.auth}},payload,{TTL:86400,urgency:'high',topic:`repair-${String(order.id).replace(/-/g,'').slice(0,25)}`})
        sent++
      }catch(error:any){
        if(error?.statusCode===404||error?.statusCode===410)expired.push(subscription.id);else failed++
      }
    }))
    if(expired.length)await admin.from('push_subscriptions').update({active:false,updated_at:new Date().toISOString()}).in('id',expired)
    return json({sent,failed,expired:expired.length})
  }catch(error){return json({error:error instanceof Error?error.message:String(error)},500)}
})
