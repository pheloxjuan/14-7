/* PHELOX stock persistence candidate. Load after the existing application. */
let cloudMovementCatalog={companies:[],locations:[]},cloudMovementTimer=null,cloudMovementLoading=false;
const cloudMovementStatus={pendiente:'Pendiente',aprobado:'Aprobada',rechazado:'Rechazada',enviado:'Despachada',recibido:'Recibida',preparando:'Preparando'};
function stockCloudEscape(value){return String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
async function stockCloudRpc(name,args){
  if(!supabaseSessionActive)throw new Error('Ingresá nuevamente para guardar en Supabase.');
  let client=await ensureSupabaseClient(),result=await client.rpc(name,args);
  if(result.error)throw result.error;
  return result.data;
}
async function loadCloudMovementRequests(){
  if(!supabaseSessionActive||cloudMovementLoading)return;
  cloudMovementLoading=true;
  try{
    let data=await stockCloudRpc('stock_request_snapshot',{});
    cloudMovementCatalog={companies:data.companies||[],locations:data.locations||[]};
    stockMovementRequests=(data.requests||[]).map(r=>({...r,status:cloudMovementStatus[r.status]||r.status,_cloud:true}));
    let readById=new Map(appMessages.filter(m=>m._cloudMovement).map(m=>[m.id,m.read]));
    appMessages=appMessages.filter(m=>!m._cloudMovement);
    (data.notifications||[]).forEach(n=>appMessages.push({id:n.id,toUser:currentUser?.id,toName:activeUserName(),
      from:'Stock',type:'Solicitud movimiento',title:n.title,body:n.body,date:new Date(n.created_at).toLocaleString(),
      status:'Pendiente',read:!!n.read_at||readById.get(n.id)||false,movementRequestId:n.entity_id,_cloudMovement:true}));
    if(typeof renderUserMessageBadge==='function')renderUserMessageBadge();
  }finally{cloudMovementLoading=false}
}
loadCloudStock=async function(){
  if(!supabaseSessionActive)return;
  if(cloudStockLoading)throw new Error('El stock se está actualizando. Esperá y volvé a intentar.');
  cloudStockLoading=true;
  try{
    let snapshot=(await stockCloudRpc('stock_request_snapshot',{})).stock;
    if(!snapshot)throw new Error('La versión de Supabase no incluye la corrección de stock.');
    let articles=new Map(snapshot.articles.map(a=>[a.id,a])),locationsById=new Map(snapshot.locations.map(l=>[l.id,l])),
      companiesById=new Map(snapshot.companies.map(c=>[c.id,localCompanySystemKey(c)]));
    let rows=snapshot.balances.map(b=>{
      let a=articles.get(b.article_id),l=locationsById.get(b.location_id);if(!a||!l)return null;
      let positions=b.warehouse_positions||[],owners=snapshot.article_companies.filter(link=>link.article_id===a.id).map(link=>companiesById.get(link.company_id)).filter(Boolean),data=a.client_details||{};
      return {...data,code:a.code,part:a.name,type:a.article_type||'Artículo',brand:a.brand||'',model:a.model||'',
        min:Number(a.minimum_stock),ideal:Number(a.ideal_stock),loc:l.name,qty:Number(b.quantity),price:Number(b.average_cost),currency:b.currency,
        stockCompany:owners.length>1?'Ambas empresas':owners[0]||companiesById.get(b.company_id),
        warehousePositionDetails:positions,warehousePositions:positions.map(p=>typeof p==='string'?p:p.code),warehousePosition:positions.map(p=>typeof p==='string'?p:p.code).join(' / '),
        _cloudArticleId:a.id,_cloudLocationId:l.id,_cloudCompanyId:b.company_id,_cloudVersion:Number(b.version)};
    }).filter(Boolean);
    stock.splice(0,stock.length,...rows);
    cloudStockBaseline=new Map(rows.map(item=>[cloudStockKey(item),JSON.stringify({qty:item.qty,price:item.price,currency:item.currency,positions:cloudWarehousePositions(item),version:item._cloudVersion})]));
    cloudStockReady=true;saveLocalDataWithoutStock();
  }finally{cloudStockLoading=false;}
};
function cloudStockCompanyId(name){return cloudMovementCatalog.companies.find(c=>norm(localCompanySystemKey(c))===norm(name))?.id}
function cloudStockLocation(name,companyName){
  let companyId=cloudStockCompanyId(companyName);
  let own=cloudMovementCatalog.locations.find(l=>l.company_id===companyId&&norm(l.name)===norm(name));
  if(own)return own;
  // VILLA is the existing shared physical store; other cross-company names are rejected.
  if(norm(name)==='villa'&&norm(companyName)==='transportes el avion')return cloudMovementCatalog.locations.find(l=>
    norm(l.name)==='villa'&&l.can_source&&norm(l.company_name)==='phelox ltda');
}
const saveNewStockItemBeforePersistenceFix=saveNewStockItem;
saveNewStockItem=async function(){
  if(!supabaseSessionActive)return saveNewStockItemBeforePersistenceFix();
  const input=id=>document.getElementById(id)?.value||'';
  let code=input('nCode').trim().toUpperCase(),part=input('nPart').trim(),type=input('nType'),
    qty=Number(input('nQty')),price=Number(input('nPrice')),ideal=Number(input('nIdeal')),min=Number(input('nMin')),
    brand=input('nBrand').trim(),model=input('nModel').trim(),yearFrom=Number(input('nYearFrom')),yearTo=Number(input('nYearTo'));
  if(type==='__new')return alert('Escribí el nombre del nuevo tipo de artículo.');
  let tireSize=input('nTireSize').trim(),tireBrand=input('nTireBrand').trim(),tireModel=input('nTireModel').trim();
  if(type==='Cubierta'){
    if(!tireSize||!tireBrand)return alert('Completá medida y marca de cubierta.');
    part=part||`Cubierta ${tireSize} ${tireBrand} ${tireModel}`.trim();brand=tireBrand;model=tireSize;
  }
  if(!code||!part||![qty,price,ideal,min,yearFrom,yearTo].every(Number.isFinite)||qty<0||price<=0||ideal<0||min<0||
    (yearFrom&&yearTo&&yearFrom>yearTo))return alert('Revisá código, nombre, precio, cantidades y años.');
  try{
    await loadCloudMovementRequests();
    let location=cloudStockLocation(input('nLoc'),company);
    if(!location?.can_source)throw new Error('Sin acceso a la ubicación seleccionada.');
    let scopeName=input('nStockCompany')||company,scope=scopeName==='Ambas empresas'
      ? ['Phelox Ltda','Transportes El Avion'].map(cloudStockCompanyId):[cloudStockCompanyId(scopeName)];
    if(scope.some(id=>!id)||!scope.includes(location.company_id))throw new Error('La empresa propietaria debe incluir la ubicación física y estar autorizada.');
    let photos=await stockPhotoValues(['nPhotoCam','nPhoto'],[]),positions=warehousePositionValues({warehousePosition:input('nWarehousePosition').trim().toUpperCase()});
    let item={code,part,type,brand,model,qty,ideal,min,price,currency:input('nCurrency')||'UYU',yearFrom,yearTo,tireSize,tireBrand,tireModel,
      photos,photo:photos[0]||'',productNote:input('nDesc').trim(),
      compatibleArticleCodes:[...document.querySelectorAll('#nCompatibilityArticles input:checked')].map(e=>e.value),
      warehousePositionDetails:positions.map(code=>({code,quantity:null}))};
    let busy=false;
    return confirmStockSave(`¿Crear <b>${stockCloudEscape(code)} · ${stockCloudEscape(part)}</b> en Supabase?`,async()=>{
      if(busy)return;busy=true;
      try{
        await stockCloudRpc('create_stock_article',{p_company:location.company_id,p_location:location.id,p_scope:scope,p_item:item});
        clearChanges();
        try{await loadCloudStock();stockArticles();success('Artículo guardado en Supabase.');}
        catch(error){alert('El artículo quedó guardado. No se pudo recargar la lista: '+error.message);}
      }catch(error){alert('No se confirmó el alta en Supabase. Revisá la lista antes de reintentar: '+error.message);}
      finally{busy=false;}
    });
  }catch(error){alert('No se pudo preparar el alta: '+error.message);}
};
const stockMovementRequestFormBeforePersistenceFix=stockMovementRequestForm;
stockMovementRequestForm=async function(){
  if(!supabaseSessionActive)return stockMovementRequestFormBeforePersistenceFix();
  try{
    await loadCloudMovementRequests();
    stockViewBox.innerHTML=`<div class="panel"><h2>Solicitud de movimiento</h2><div class="form"><label>Empresa<select id="smrCompany" onchange="renderStockMovementRequestFields()">${cloudMovementCatalog.companies.map(c=>`<option value="${stockCloudEscape(localCompanySystemKey(c))}" ${norm(localCompanySystemKey(c))===norm(company)?'selected':''}>${stockCloudEscape(c.name)}</option>`).join('')}</select></label><div id="smrFields" class="wide"></div><label>Cantidad<input id="smrQty" type="number" min="0.001" step="0.001" value="1"></label><textarea id="smrReason" class="wide" placeholder="Motivo del envío"></textarea><button class="primary" onclick="saveStockMovementRequest()">Enviar al encargado de stock</button><button class="ghost" onclick="stockMovementRequestsView()">Ver solicitudes</button></div></div>`;
    renderStockMovementRequestFields();trackChanges();
  }catch(error){alert('No se pudieron cargar las ubicaciones: '+error.message);}
};
const renderStockMovementRequestFieldsBeforePersistenceFix=renderStockMovementRequestFields;
renderStockMovementRequestFields=function(){
  if(!supabaseSessionActive)return renderStockMovementRequestFieldsBeforePersistenceFix();
  let c=document.getElementById('smrCompany')?.value,id=cloudStockCompanyId(c),box=document.getElementById('smrFields');
  if(!box)return;
  let own=cloudMovementCatalog.locations.filter(l=>l.can_source&&(l.company_id===id||
    (norm(c)==='transportes el avion'&&norm(l.name)==='villa'&&norm(l.company_name)==='phelox ltda')));
  let targets=cloudMovementCatalog.locations.filter(l=>l.company_id===id);
  box.innerHTML=`<div class="form"><label>Origen<select id="smrFrom" onchange="renderStockMovementRequestItems()">${own.map(l=>`<option value="${l.id}">${stockCloudEscape(l.name)}</option>`).join('')}</select></label><label>Destino<select id="smrTo">${targets.map(l=>`<option value="${l.id}">${stockCloudEscape(l.name)}</option>`).join('')}</select></label><label>Artículo<select id="smrItem"></select></label></div>`;
  renderStockMovementRequestItems();
};
const renderStockMovementRequestItemsBeforePersistenceFix=renderStockMovementRequestItems;
renderStockMovementRequestItems=function(){
  if(!supabaseSessionActive)return renderStockMovementRequestItemsBeforePersistenceFix();
  let source=document.getElementById('smrFrom')?.value,select=document.getElementById('smrItem');
  if(select)select.innerHTML=stock.filter(i=>i._cloudLocationId===source&&i.qty>0).map(i=>
    `<option value="${stock.indexOf(i)}">${stockCloudEscape(i.code)} · ${stockCloudEscape(i.part)} · Stock ${i.qty}</option>`).join('')||'<option value="">Sin artículos disponibles</option>';
};
const saveStockMovementRequestBeforePersistenceFix=saveStockMovementRequest;
saveStockMovementRequest=async function(){
  if(!supabaseSessionActive)return saveStockMovementRequestBeforePersistenceFix();
  let c=document.getElementById('smrCompany')?.value,from=document.getElementById('smrFrom')?.value,
    to=document.getElementById('smrTo')?.value,itemValue=document.getElementById('smrItem')?.value,
    item=itemValue===''?null:stockItemByValue(itemValue),qty=Number(document.getElementById('smrQty')?.value),
    reason=(document.getElementById('smrReason')?.value||'').trim();
  if(!from||!to||from===to||!item?._cloudArticleId||item._cloudLocationId!==from||!Number.isFinite(qty)||qty<=0||qty>item.qty||!reason)
    return alert('Revisá origen, destino, artículo, cantidad disponible y motivo.');
  let form=document.getElementById('smrReason');
  let fingerprint=JSON.stringify([c,from,to,item._cloudArticleId,qty,reason]);
  if(form.dataset.cloudDraft!==fingerprint){form.dataset.cloudDraft=fingerprint;form.dataset.cloudRequestId=crypto.randomUUID();}
  let requestId=form.dataset.cloudRequestId,busy=false;
  return confirmStockSave(`¿Enviar ${qty} de <b>${stockCloudEscape(item.code)}</b> al encargado de stock?`,async()=>{
    if(busy)return;busy=true;
    try{
      await stockCloudRpc('create_stock_request',{p_id:requestId,p_company:cloudStockCompanyId(c),p_from:from,p_to:to,p_article:item._cloudArticleId,p_quantity:qty,p_reason:reason});
      clearChanges();
      try{await loadCloudMovementRequests();stockMovementRequestsView();success('Solicitud guardada en Supabase y disponible para el encargado de stock.');}
      catch(error){alert('La solicitud quedó guardada. No se pudo actualizar la lista: '+error.message);}
    }catch(error){alert('No se confirmó la solicitud: '+error.message);}
    finally{busy=false;}
  });
};
const stockMovementRequestsViewBeforePersistenceFix=stockMovementRequestsView;
stockMovementRequestsView=function(){
  if(!supabaseSessionActive)return stockMovementRequestsViewBeforePersistenceFix();
  stockViewBox.dataset.cloudMovements='true';
  stockViewBox.innerHTML=`<div class="panel"><div class="top"><h2>Solicitudes de movimiento (${pendingStockMovementCount()})</h2><button class="ghost" onclick="refreshCloudMovementScreen()">Actualizar</button></div><p class="muted">La aprobación no mueve existencias. El solicitante confirma el despacho.</p><div class="tableScroll"><table><thead><tr><th>Solicita</th><th>Artículo</th><th>Origen</th><th>Destino</th><th>Cantidad</th><th>Estado</th><th>Acciones</th></tr></thead><tbody>${stockMovementRequests.map(r=>`<tr><td>${stockCloudEscape(r.userName)}</td><td>${stockCloudEscape(r.code)} · ${stockCloudEscape(r.part)}</td><td>${stockCloudEscape(r.fromLoc)}</td><td>${stockCloudEscape(r.toLoc)}</td><td>${r.qty}</td><td>${stockMovementStatusBadge(r.status)}</td><td>${r.can_manage&&r.status==='Pendiente'?`<button class="primary" onclick="reviewStockMovementRequest('${r.id}','Aprobada')">Aprobar</button><button class="red" onclick="reviewStockMovementRequest('${r.id}','Rechazada')">Rechazar</button>`:''}${r.userId===(currentUser?.supabaseId||currentUser?.id)&&r.status==='Aprobada'?`<button class="gold" onclick="dispatchStockMovementRequest('${r.id}')">Marcar despachado</button>`:''}<button class="ghost" onclick="openStockMovementRequest('${r.id}')">Ver</button></td></tr>`).join('')||'<tr><td colspan="7">No hay solicitudes visibles.</td></tr>'}</tbody></table></div></div>`;
  clearChanges();
};
async function refreshCloudMovementScreen(){
  try{await loadCloudMovementRequests();stockMovementRequestsView();}
  catch(error){alert('No se pudo actualizar: '+error.message);}
}
const reviewStockMovementRequestBeforePersistenceFix=reviewStockMovementRequest;
reviewStockMovementRequest=function(id,status){
  if(!supabaseSessionActive)return reviewStockMovementRequestBeforePersistenceFix(id,status);
  let r=stockMovementRequests.find(r=>r.id===id);
  if(!r?.can_manage||r.status!=='Pendiente')return alert('No podés resolver esta solicitud.');
  if(status==='Rechazada')return reviewStockMovementRequestBeforePersistenceFix(id,status);
  return confirmStockSave('¿Aprobar esta solicitud? El stock se moverá cuando el solicitante confirme el despacho.',()=>confirmStockMovementReview(id,status));
};
const confirmStockMovementReviewBeforePersistenceFix=confirmStockMovementReview;
confirmStockMovementReview=async function(id,status){
  if(!supabaseSessionActive)return confirmStockMovementReviewBeforePersistenceFix(id,status);
  try{
    await stockCloudRpc('decide_stock_request',{p_id:id,p_status:status==='Aprobada'?'aprobado':'rechazado',p_note:document.getElementById('smrResponse')?.value||status});
    closeModal();await refreshCloudMovementScreen();success('Respuesta guardada en Supabase.');
  }catch(error){alert('No se confirmó la respuesta: '+error.message);}
};
const dispatchStockMovementRequestBeforePersistenceFix=dispatchStockMovementRequest;
dispatchStockMovementRequest=function(id){
  if(!supabaseSessionActive)return dispatchStockMovementRequestBeforePersistenceFix(id);
  let r=stockMovementRequests.find(r=>r.id===id),busy=false;
  if(!r||r.userId!==(currentUser?.supabaseId||currentUser?.id)||r.status!=='Aprobada')return alert('Solo el solicitante puede despachar una solicitud aprobada.');
  return confirmStockSave('¿Confirmás el despacho? Se actualizarán origen y destino en una sola operación.',async()=>{
    if(busy)return;busy=true;
    try{
      await cloudStockQueue;
      await stockCloudRpc('decide_stock_request',{p_id:id,p_status:'enviado',p_note:'Despacho confirmado'});
      try{await loadCloudStock();await refreshCloudMovementScreen();success('Despacho guardado y stock actualizado.');}
      catch(error){alert('El despacho quedó guardado. No se pudo actualizar la pantalla: '+error.message);}
    }catch(error){alert('No se confirmó el despacho: '+error.message);}
    finally{busy=false;}
  });
};
const loginWithSupabaseBeforeStockPersistence=loginWithSupabase;
loginWithSupabase=async function(){
  await loginWithSupabaseBeforeStockPersistence();
  if(!supabaseSessionActive)return;
  stockMovementRequests=[];
  try{await loadCloudMovementRequests();}
  catch(error){alert('No se pudieron cargar las solicitudes de movimiento: '+error.message);}
  clearInterval(cloudMovementTimer);
  cloudMovementTimer=setInterval(async()=>{
    if(!supabaseSessionActive||document.hidden)return;
    try{await loadCloudMovementRequests();
      if(document.getElementById('stockViewBox')?.dataset.cloudMovements==='true'&&document.querySelector('#stockViewBox h2')?.textContent?.startsWith('Solicitudes de movimiento'))stockMovementRequestsView();
    }catch(error){console.warn('No se pudo consultar solicitudes de movimiento',error);}
  },15000);
};
const logoutBeforeStockPersistence=logout;
logout=async function(){clearInterval(cloudMovementTimer);cloudMovementTimer=null;stockMovementRequests=[];cloudMovementCatalog={companies:[],locations:[]};return logoutBeforeStockPersistence();};
