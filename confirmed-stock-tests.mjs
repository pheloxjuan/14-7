import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
const code=fs.readFileSync('confirmed-stock-actions.js','utf8');
new vm.Script(code);
function setup(storage=new Map()){
  let calls=[],events=[],confirmation,resolveRpc;
  let fields={mvItem:'0',mvFrom:'ORIGEN',mvLoc:'DESTINO',mvQty:'1.25',mvDesc:'traslado',cItem:'0',cQty:'0.5',cLoc:'ORIGEN',cVehicle:'ABC123',cDesc:'consumo'};
  const context={
    supabaseSessionActive:true,currentUser:{supabaseId:'actor'},cloudStockQueue:Promise.resolve(),
    stock:[{code:'A',part:'Artículo A',loc:'ORIGEN',qty:5,_cloudArticleId:'article',_cloudLocationId:'source',_cloudVersion:3}],moves:[],
    norm:v=>String(v||'').toLowerCase(),company:'Phelox Ltda',requirePerm:()=>true,
    stockItemByValue:()=>context.stock[0],stockCloudEscape:v=>String(v),
    document:{getElementById:id=>({value:fields[id]||''}),addEventListener:()=>{}},
    window:{addEventListener:()=>{}},crypto:{randomUUID},
    modalRoot:{querySelectorAll:()=>[]},modalConfirmAction:null,
    localStorage:{getItem:key=>storage.get(key)||null,setItem:(key,v)=>storage.set(key,v),removeItem:key=>storage.delete(key)},
    stockCloudRpc:async(name,args)=>{calls.push({name,args});if(name==='stock_movement_history')return [];
      return new Promise(resolve=>{resolveRpc=resolve;});},
    loadCloudStock:async()=>{events.push('load');},loadCloudMovementRequests:async()=>{},
    cloudStockLocation:()=>({id:'destination',can_source:true}),
    stockMoves:()=>events.push('render'),stockConsumptions:()=>events.push('render'),stockEntries:()=>events.push('render'),
    stockEntryAverageData:()=>({source:context.stock[0],qty:0.25,buyPrice:10,to:'DESTINO',buyCurrency:'UYU',sameCurrency:true}),
    clearChanges:()=>events.push('clear'),success:msg=>events.push('success'),alert:msg=>events.push('error:'+msg),
    confirmStockSave:(text,action)=>{confirmation=action;},loginWithSupabase:async()=>{},logout:async()=>{},closeModal:()=>{},
  };
  vm.createContext(context);vm.runInContext(code,context);
  return {context,storage,calls,events,fields,confirm:()=>confirmation(),resolve:()=>resolveRpc('movement-id')};
}
const tick=()=>new Promise(resolve=>setImmediate(resolve));
// Pending RPC must not mutate balances, navigate, clear input, or show success.
{
 const t=setup();t.context.saveStockMove();const saving=t.confirm();await tick();
 assert.equal(t.calls[0].name,'commit_stock_action');assert.equal(t.calls[0].args.p_action.quantity,1.25);
 assert.equal(t.context.stock[0].qty,5);assert.equal(t.context.stock[0].loc,'ORIGEN');assert.equal(t.events.length,0);
 assert.equal(t.storage.size,1);t.resolve();await saving;
 assert.equal(t.storage.size,0);assert.deepEqual(t.events,['clear','load','render','success']);
}
// An interrupted response survives a fresh page context and retries with its original ID and version.
{
 const t=setup();t.context.stockCloudRpc=async(name,args)=>{t.calls.push({name,args});throw new Error('network timeout');};
 t.context.saveStockConsumption();await t.confirm();assert.equal(t.storage.size,1);assert.equal(t.context.stock[0].qty,5);
 assert(!t.events.includes('success'));const first=t.calls[0].args;
 const reopened=setup(t.storage);reopened.context.stock[0]._cloudVersion=99;
 reopened.context.saveStockConsumption();const saving=reopened.confirm();await tick();
 assert.equal(reopened.calls[0].args.p_id,first.p_id);assert.equal(reopened.calls[0].args.p_action.expected_version,3);
 reopened.resolve();await saving;assert.equal(reopened.storage.size,0);
}
// A definite database rejection retains form state, removes the retry marker, and cannot show success.
{
 const t=setup();t.context.stockCloudRpc=async()=>{throw Object.assign(new Error('Stock insuficiente'),{code:'P0001'});};
 t.context.saveStockConsumption();await t.confirm();assert.equal(t.storage.size,0);
 assert.equal(t.context.stock[0].qty,5);assert(!t.events.includes('clear'));assert(!t.events.includes('success'));
}
// Multiple confirmations while in flight issue exactly one mutation.
{
 const t=setup();t.context.saveStockConsumption();const one=t.confirm();await tick();await t.confirm();
 assert.equal(t.calls.length,1);t.resolve();await one;
}
// Decimal entry quantity is not truncated and the server computes the average.
{
 const t=setup();t.context.saveStockEntry();const saving=t.confirm();await tick();
 assert.equal(t.calls[0].args.p_action.quantity,0.25);assert.equal(t.calls[0].args.p_action.price,10);
 assert.equal(t.context.stock[0].qty,5);t.resolve();await saving;
}
// Success is not falsely reported as a failed write if the subsequent refresh fails.
{
 const t=setup();t.context.stockCloudRpc=async name=>{if(name==='stock_movement_history')throw Error('refresh failed');return 'movement-id';};
 t.context.saveStockConsumption();await t.confirm();assert.equal(t.storage.size,0);
 assert(t.events.some(e=>e.includes('quedó guardado')));assert(!t.events.includes('success'));
}
// History is restored on every stock load, replacing stale local history with stable server IDs.
{
 const t=setup();t.context.moves.push({id:'local'});
 t.context.stockCloudRpc=async()=>[{id:'persisted',code:'A',quantity:1,movement_type:'transferencia',created_at:'2026-10-12T12:00:00Z',from_name:'ORIGEN',to_name:'DESTINO',reason:'<unsafe>',client_details:{}}];
 await t.context.loadCloudStock();await t.context.loadCloudStock();assert.equal(t.context.moves.length,1);assert.equal(t.context.moves[0].id,'persisted');assert.equal(t.context.moves[0].action,'Movimiento');
}
// Offline attempts do not silently fall back to local-only writes.
{
 const t=setup();t.context.supabaseSessionActive=false;t.context.saveStockMove();assert.equal(t.calls.length,0);assert.equal(t.context.stock[0].qty,5);assert(t.events[0].startsWith('error:'));
}
// Global modal confirmation waits and ignores a second click.
{
 const t=setup();let release;let n=0;t.context.modalConfirmAction=()=>{n++;return new Promise(r=>release=r);};
 const first=t.context.runModalConfirm();await t.context.runModalConfirm();assert.equal(n,1);release();await first;
}
// Request decisions also wait for acknowledgement and avoid falsely reporting refresh errors as write failures.
{
 const source=fs.readFileSync('stock-persistence.js','utf8'),events=[];
 const context={supabaseSessionActive:true,document:{getElementById:()=>({value:'motivo'})},
   closeModal:()=>events.push('close'),success:()=>events.push('success'),alert:msg=>events.push(msg),
   loadCloudMovementRequests:async()=>{throw Error('refresh failed');},stockMovementRequestsView:()=>{},
 };
 for(const match of source.matchAll(/const\s+\w+\s*=\s*(\w+)\s*;/g))context[match[1]]=()=>{};
 vm.createContext(context);vm.runInContext(source,context);
 let release;let calls=0;context.stockCloudRpc=()=>{calls++;return new Promise(resolve=>release=resolve);};
 context.loadCloudMovementRequests=async()=>{throw Error('refresh failed');};
 const saving=context.confirmStockMovementReview('request','Aprobada');
 await context.confirmStockMovementReview('request','Aprobada');assert.equal(calls,1);assert.equal(events.length,0);
 release('aprobado');await saving;assert(events.some(e=>e.includes('quedó guardada')));assert(!events.includes('success'));
}
console.log('10 scenarios passed: server acknowledgement, retries after reopen, rejection, duplicate clicks, fractional entry, refresh failure, durable history, offline denial, async confirmation, request decisions.');
