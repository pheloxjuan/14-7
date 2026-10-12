/* Direct movements, entries and consumptions: no optimistic stock mutations. */
let confirmedStockBusy=false;
const confirmedStockPendingKey=()=>`phelox_pending_stock_action:${currentUser?.supabaseId||''}`;
function confirmedStockFingerprint(action){let copy={...action};delete copy.expected_version;return JSON.stringify(copy)}
function confirmedStockDraft(action){
  const key=confirmedStockPendingKey(),raw=localStorage.getItem(key);
  if(raw){
    const pending=JSON.parse(raw);
    if(confirmedStockFingerprint(pending.action)!==confirmedStockFingerprint(action))
      throw new Error('Hay un guardado pendiente de confirmación. Usá “Reintentar guardado pendiente” antes de iniciar otro movimiento.');
    return pending;
  }
  const pending={id:crypto.randomUUID(),action};
  localStorage.setItem(key,JSON.stringify(pending));
  return pending;
}
async function executeConfirmedStockAction(action,render){
  if(confirmedStockBusy)return;
  confirmedStockBusy=true;
  let committed=false;
  try{
    if(!supabaseSessionActive||!currentUser?.supabaseId)throw new Error('Ingresá para guardar en Supabase.');
    await cloudStockQueue;
    const pending=confirmedStockDraft(action);
    const id=await stockCloudRpc('commit_stock_action',{p_id:pending.id,p_action:pending.action});
    if(typeof id!=='string'||!id)throw new Error('El servidor no confirmó el movimiento.');
    committed=true;localStorage.removeItem(confirmedStockPendingKey());clearChanges();
    await loadCloudStock();
    render();success('Guardado confirmado en Supabase.');
  }catch(error){
    // A database rejection rolls the transaction back; network failures remain retryable with the same ID.
    if(error.code&&(/^(22|23|28|42|P0)/.test(error.code)))localStorage.removeItem(confirmedStockPendingKey());
    alert(committed?'El movimiento quedó guardado en Supabase. No se pudo actualizar la pantalla: '+error.message:
      'No se confirmó el guardado: '+error.message);
    if(!committed&&localStorage.getItem(confirmedStockPendingKey()))
      modalRoot.querySelector?.('.modalActions')?.insertAdjacentHTML('afterbegin','<button class="primary" onclick="retryPendingStockAction()">Reintentar guardado pendiente</button>');
  }finally{confirmedStockBusy=false;}
}
async function retryPendingStockAction(){
  const raw=localStorage.getItem(confirmedStockPendingKey());
  if(!raw)return alert('No hay un guardado pendiente.');
  const pending=JSON.parse(raw);
  return executeConfirmedStockAction(pending.action,stockMoves);
}
function confirmedStockInput(id){return document.getElementById(id)?.value||''}
function requireConfirmedStockSession(permission){
  if(!supabaseSessionActive||!currentUser?.supabaseId){alert('Ingresá para guardar esta acción en Supabase.');return false;}
  return requirePerm(permission,'guardar en Supabase');
}
saveStockMove=function(){
  if(!requireConfirmedStockSession('stockMove'))return;
  const item=stockItemByValue(confirmedStockInput('mvItem')),from=confirmedStockInput('mvFrom')||item?.loc,
    to=confirmedStockInput('mvLoc'),quantity=Number(confirmedStockInput('mvQty')),
    reason=confirmedStockInput('mvDesc')||`Movimiento de ubicación: ${from} > ${to}`;
  if(!item?._cloudArticleId||norm(from)!==norm(item.loc)||!to||norm(from)===norm(to)||!Number.isFinite(quantity)||quantity<=0||quantity>item.qty)
    return alert('Revisá artículo, origen, destino y cantidad disponible.');
  return confirmStockSave(`¿Mover ${quantity} de <b>${stockCloudEscape(item.part)}</b> hacia <b>${stockCloudEscape(to)}</b>?`,async()=>{
    try{
      await loadCloudMovementRequests();const destination=cloudStockLocation(to,company);
      if(!destination?.can_source)throw new Error('Sin acceso al destino seleccionado.');
      await executeConfirmedStockAction({article:item._cloudArticleId,from:item._cloudLocationId,to:destination.id,
        quantity,expected_version:item._cloudVersion,reason},stockMoves);
    }catch(error){alert(error.message);}
  });
};
saveStockConsumption=function(){
  if(!requireConfirmedStockSession('stockConsume'))return;
  const item=stockItemByValue(confirmedStockInput('cItem')),quantity=Number(confirmedStockInput('cQty')),
    location=confirmedStockInput('cLoc'),vehicle=confirmedStockInput('cVehicle'),reason=confirmedStockInput('cDesc')||'Consumo de stock';
  if(!item?._cloudArticleId||norm(item.loc)!==norm(location)||!Number.isFinite(quantity)||quantity<=0||quantity>item.qty)
    return alert('Revisá artículo, ubicación y cantidad disponible.');
  return confirmStockSave(`¿Consumir ${quantity} de <b>${stockCloudEscape(item.part)}</b>?`,()=>
    executeConfirmedStockAction({article:item._cloudArticleId,from:item._cloudLocationId,to:null,quantity,
      expected_version:item._cloudVersion,vehicle,reason},stockConsumptions));
};
saveStockEntry=function(){
  if(!requireConfirmedStockSession('stockEntry'))return;
  const data=stockEntryAverageData(),item=data.source,quantity=data.qty,price=data.buyPrice,to=data.to,
    currency=data.buyCurrency,reason=confirmedStockInput('eDesc')||'Ingreso de stock';
  if(!item?._cloudArticleId||!to||![quantity,price].every(Number.isFinite)||quantity<=0||price<=0||!data.sameCurrency)
    return alert('Revisá artículo, destino, cantidad, precio y moneda.');
  return confirmStockSave(`¿Ingresar ${quantity} de <b>${stockCloudEscape(item.part)}</b>? El costo promedio se calculará con el stock actual del servidor.`,async()=>{
    try{
      await loadCloudMovementRequests();const destination=cloudStockLocation(to,company);
      if(!destination?.can_source)throw new Error('Sin acceso al destino seleccionado.');
      await executeConfirmedStockAction({article:item._cloudArticleId,from:null,to:destination.id,quantity,price,currency,reason},stockEntries);
    }catch(error){alert(error.message);}
  });
};
const loadCloudStockBeforeConfirmedHistory=loadCloudStock;
loadCloudStock=async function(){
  if(!supabaseSessionActive)return;
  const rows=await stockCloudRpc('stock_movement_history',{});
  if(!Array.isArray(rows))throw new Error('No se pudo leer el historial de movimientos.');
  await loadCloudStockBeforeConfirmedHistory();
  const actions={ingreso:'Ingreso',consumo:'Consumo',transferencia:'Movimiento'};
  const restored=rows.map(row=>({id:row.id,code:row.code,date:new Date(row.created_at).toLocaleString(),
    user:stockCloudEscape(row.actor_name||row.client_details?.user||'Usuario'),action:actions[row.movement_type]||row.movement_type,
    vehicle:stockCloudEscape(row.client_details?.vehicle||'-'),qty:Number(row.quantity),price:Number(row.unit_cost),currency:row.currency,
    purchasePrice:Number(row.unit_cost),previousQty:Number(row.previous_quantity),previousAverage:Number(row.client_details?.previousAverage||0),
    newAverage:Number(row.client_details?.newAverage||0),fromLoc:row.from_name||'',loc:row.to_name||row.from_name||'',
    desc:stockCloudEscape(row.reason||''),_cloud:true}));
  moves.splice(0,moves.length,...restored);
};
const loginBeforePendingStockAction=loginWithSupabase;
loginWithSupabase=async function(){
  moves.splice(0,moves.length);
  await loginBeforePendingStockAction();
  if(supabaseSessionActive&&localStorage.getItem(confirmedStockPendingKey())){
    modalRoot.innerHTML='<div class="modalBackdrop"><div class="modalBox"><div class="modalTitle">Guardado pendiente de confirmar</div><p>La conexión se interrumpió durante un guardado. Podés reintentarlo con el mismo identificador para evitar duplicados.</p><button class="primary" onclick="retryPendingStockAction()">Reintentar guardado pendiente</button><button class="ghost" onclick="closeModal()">Cerrar</button></div></div>';
  }
};
const logoutBeforeConfirmedHistory=logout;
logout=async function(){moves.splice(0,moves.length);return logoutBeforeConfirmedHistory();};
let confirmedModalBusy=false;
runModalConfirm=async function(){
  if(confirmedModalBusy)return;
  const action=modalConfirmAction;if(!action)return;
  confirmedModalBusy=true;modalConfirmAction=null;
  const buttons=[...modalRoot.querySelectorAll('button')];buttons.forEach(button=>button.disabled=true);
  try{await action();}
  catch(error){alert('No se confirmó la acción: '+error.message);}
  finally{
    confirmedModalBusy=false;
    // Only close the original confirmation if the action did not replace it with its result.
    if(buttons.length&&buttons.every(button=>button.isConnected)){closeModal();}
  }
};
window.addEventListener('beforeunload',event=>{if(confirmedStockBusy||confirmedModalBusy){event.preventDefault();event.returnValue='';}});
document.addEventListener('click',event=>{
  if(confirmedStockBusy||confirmedModalBusy){event.preventDefault();event.stopImmediatePropagation();}
},true);
