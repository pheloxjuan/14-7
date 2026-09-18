import fs from 'node:fs'; import vm from 'node:vm'; import assert from 'node:assert/strict';
const html=fs.readFileSync('index.html','utf8');
let count=0;for(const match of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)){if(match[1].trim()){new vm.Script(match[1]);count++;}}
const start=html.indexOf('confirmPasswordRecovery=async function(id,status){');
const code=html.slice(start,html.indexOf('\n};',start)+3);
let calls=[],checked=false,alerts=[];
const context={appMessages:[{id:'request',cloudPasswordRequestId:'cloud-id'}],isSuperAdmin:()=>true,document:{getElementById:()=>({checked})},alert:m=>alerts.push(m),invokeSupabaseAsCurrentUser:async(name,body)=>{calls.push(body);return {}},ensureSupabaseClient:async()=>({}),loadCloudPasswordRecoveryRequests:async()=>{},closeModal:()=>{},success:()=>{},showUserMessages:()=>{}};
vm.createContext(context);vm.runInContext(code,context);
await (async()=>{await context.confirmPasswordRecovery('request','Aprobada');assert.equal(calls.length,0);assert.equal(alerts.length,1);checked=true;await context.confirmPasswordRecovery('request','Aprobada');assert.equal(calls[0].action,'complete-password-request');assert(!('password' in calls[0]));await context.confirmPasswordRecovery('request','Rechazada');assert.equal(calls[1].decision,'rejected');const backend=fs.readFileSync('supabase/functions/import-users/index.ts','utf8');const completion=backend.split('if (body.action === "complete-password-request")')[1].split('const rows =')[0];assert(!completion.includes('updateUserById'));assert(completion.includes('resetRequest.status !== "pendiente"'));console.log(`${count} scripts válidos; confirmación de envío, rechazo y ausencia de cambio de contraseña verificados.`);})().catch(e=>{console.error(e);process.exitCode=1});

import worker from './password-notifications.mjs';
const sent=[];
const token='test-only-not-a-real-secret-0123456789';
const env={NOTIFY_TOKEN:token,EMAIL:{send:async m=>sent.push(m)}};
const event={type:'INSERT',schema:'public',table:'password_reset_requests',record:{id:'test-request',username:'usuario-prueba',status:'pendiente',phone_last4:'1234',notes:'DO NOT EMAIL THIS'}};
const request=(body,auth=token)=>new Request('https://example.test/',{method:'POST',headers:{Authorization:'Bearer '+auth,'Content-Type':'application/json'},body:JSON.stringify(body)});
assert.equal((await worker.fetch(new Request('https://example.test/'),env)).status,405);
assert.equal((await worker.fetch(request(event),{})).status,503);
assert.equal((await worker.fetch(request(event,'wrong'),env)).status,401);
assert.equal(sent.length,0);
assert.equal((await worker.fetch(request({...event,type:'UPDATE'}),env)).status,200);
assert.equal(sent.length,0);
assert.equal((await worker.fetch(request(event),env)).status,200);
assert.equal(sent.length,1);
assert.equal(sent[0].to,'juancruz19@hotmail.com');
assert(!sent[0].text.includes('1234'));
assert(!sent[0].text.includes('DO NOT EMAIL'));
assert.equal((await worker.fetch(request(event),{...env,EMAIL:{send:async()=>{throw Error('private details')}}})).status,502);
console.log('Notificaciones: autenticación, destinatario fijo, filtros y errores verificados. No se enviaron correos reales.');
