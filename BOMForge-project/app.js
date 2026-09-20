const bomRows = [
  {name:'Helios Fab Expansion',code:'PRJ-HELIOS-001',type:'Project',qty:'—',unit:'—',extended:'$48,620,000',lead:'—',status:'Active',level:0},
  {name:'Cleanroom & process systems',code:'ASM-CR-100',type:'Assembly',qty:'1',unit:'$18,240,000',extended:'$18,240,000',lead:'—',status:'Active',level:1},
  {name:'HVAC controls package',code:'ASM-HVAC-204',type:'Assembly',qty:'4',unit:'$624,800',extended:'$2,499,200',lead:'—',status:'Active',level:2},
  {name:'Control board, 7-axis',code:'PCB-CTRL-7A',type:'VLSI',qty:'12',unit:'$4,821',extended:'$57,852',lead:'238 days',status:'Critical',level:3},
  {name:'Clock conditioner',code:'LMK04828B',type:'VLSI',qty:'48',unit:'$82.40',extended:'$3,955',lead:'161 days',status:'Watch',level:4},
  {name:'Analog switch array',code:'ADG5412FBRUZ',type:'VLSI',qty:'96',unit:'$12.84',extended:'$1,232',lead:'184 days',status:'Watch',level:4},
  {name:'Process metrology rack',code:'ASM-MET-310',type:'Equipment',qty:'8',unit:'$242,000',extended:'$1,936,000',lead:'72 days',status:'Ready',level:2},
  {name:'FPGA test interface',code:'XC7A200T-2FBG676I',type:'VLSI',qty:'24',unit:'$189.10',extended:'$4,538',lead:'42 days',status:'Ready',level:3},
];

const qs = (selector) => document.querySelector(selector);
const qsa = (selector) => [...document.querySelectorAll(selector)];
const toast = (message) => { const node=qs('#toast'); node.textContent=message; node.classList.add('show'); window.clearTimeout(window.__toast); window.__toast=window.setTimeout(()=>node.classList.remove('show'),2600); };

function renderRows(rows=bomRows) {
  const body=qs('#bom-table tbody');
  body.innerHTML=rows.map(row=>`<tr data-type="${row.type.toLowerCase()}" data-risk="${['Critical','Watch'].includes(row.status)}"><td><div class="node-cell">${row.level ? `<span class="indent" style="margin-left:${Math.min(row.level*9,36)}px"></span>` : ''}<span>${row.name}<span class="node-code">${row.code}</span></span></div></td><td><span class="row-type">${row.type}</span></td><td>${row.qty}</td><td>${row.unit}</td><td>${row.extended}</td><td class="${row.status==='Critical'?'danger':''}">${row.lead}</td><td><span class="status-pill ${row.status==='Critical'?'critical':row.status==='Watch'?'watch':'ok'}">${row.status}</span></td></tr>`).join('');
  qs('#row-count').textContent=rows.length;
}

qsa('.nav-item').forEach(button=>button.addEventListener('click',()=>{ qsa('.nav-item').forEach(item=>item.classList.remove('active')); button.classList.add('active'); const view=button.dataset.view; qsa('.view-panel').forEach(panel=>panel.classList.toggle('hidden',panel.dataset.panel!==view)); qs('#page-title').textContent=view==='overview'?'Helios Fab Expansion':view==='bom'?'BOM Explorer':view==='scenarios'?'Scenario lab':'Supplier watch'; }));
qsa('.filter-button').forEach(button=>button.addEventListener('click',()=>{qsa('.filter-button').forEach(item=>item.classList.remove('active-filter'));button.classList.add('active-filter');let rows=bomRows;if(button.dataset.filter==='risk')rows=bomRows.filter(row=>['Critical','Watch'].includes(row.status));if(button.dataset.filter==='vlsi')rows=bomRows.filter(row=>row.type==='VLSI');renderRows(rows);}));
qs('#bom-search').addEventListener('input',(event)=>{const query=event.target.value.toLowerCase();renderRows(bomRows.filter(row=>`${row.name} ${row.code} ${row.type}`.toLowerCase().includes(query)));});
qs('#add-node-btn').addEventListener('click',()=>{toast('BOM node creation is ready for the next estimate revision.');});
qs('#compare-btn').addEventListener('click',()=>toast('Snapshot compare opened: Design freeze 03 vs. current estimate.'));
qs('#view-risk-btn').addEventListener('click',()=>{qsa('.nav-item').find(item=>item.dataset.view==='bom').click();qsa('.filter-button').find(item=>item.dataset.filter==='risk').click();});
qs('#expand-btn').addEventListener('click',(event)=>{event.target.textContent=event.target.textContent==='Expand all'?'Collapse all':'Expand all';toast(event.target.textContent==='Collapse all'?'All hierarchy levels expanded.':'Hierarchy collapsed to top-level assemblies.');});
qs('#export-btn').addEventListener('click',()=>{const csv=['Node,Code,Type,Qty,Unit cost,Extended,Lead time,Status',...bomRows.map(r=>[r.name,r.code,r.type,r.qty,r.unit,r.extended,r.lead,r.status].join(','))].join('\n');const blob=new Blob([csv],{type:'text/csv'});const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download='bomforge-helios-bom.csv';link.click();URL.revokeObjectURL(url);toast('CSV export downloaded.');});
qs('#sync-btn').addEventListener('click',()=>toast('Supplier sync queued. 412 VLSI records will refresh.'));
const modal=qs('#modal');qs('#schema-btn').addEventListener('click',()=>modal.classList.remove('hidden'));qs('#modal-close').addEventListener('click',()=>modal.classList.add('hidden'));qs('#modal-action').addEventListener('click',()=>{modal.classList.add('hidden');toast('Schema file is included beside this prototype.');});modal.addEventListener('click',(event)=>{if(event.target===modal)modal.classList.add('hidden');});
renderRows();
