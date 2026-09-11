const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
test('theme changes retain UI and unrelated body classes',()=>{
 const body={className:'dark-theme redesign-ui watch-test'};
 body.classList={remove(...names){body.className=body.className.split(' ').filter(x=>!names.includes(x)).join(' ');},add(name){body.className+=' '+name;}};
 const toggle={href:'',children:[{}],addEventListener(){}};
 const ctx={document:{body,getElementById:()=>toggle,querySelectorAll:()=>[]},addEventListener(){}};
 vm.createContext(ctx);vm.runInContext(fs.readFileSync('assets/js/themes.js','utf8'),ctx);
 for(const mode of ['light','dark','']){
  ctx.setTheme(mode);const classes=body.className.split(' ');
  assert.ok(classes.includes('redesign-ui'));assert.ok(classes.includes('watch-test'));
  assert.equal(classes.filter(x=>['light-theme','dark-theme','no-theme'].includes(x)).length,1);
  assert.ok(classes.includes((mode||'no')+'-theme'));
 }
});

test('explicit theme choices set a mode instead of toggling it',()=>{
 const choices=['light','dark'].map(theme=>({dataset:{theme},attrs:{},addEventListener(name,fn){this.click=fn},setAttribute(k,v){this.attrs[k]=v},removeAttribute(k){delete this.attrs[k]}}));
 const requests=[];const stored={};const body={classList:{remove(){},add(){}}};
 const ctx={document:{body,getElementById:()=>null,querySelectorAll:()=>choices},helpers:{storage:{set(k,v){stored[k]=v}},xhr(method,url){requests.push(url)}},addEventListener(){}};
 vm.createContext(ctx);vm.runInContext(fs.readFileSync('assets/js/themes.js','utf8'),ctx);
 choices[0].click({preventDefault(){}});choices[0].click({preventDefault(){}});
 assert.equal(stored.dark_mode,'light');assert.deepEqual(requests,['/toggle_theme?redirect=false&mode=light','/toggle_theme?redirect=false&mode=light']);assert.equal(choices[0].attrs['aria-current'],'true');
 choices[1].click({preventDefault(){}});assert.equal(stored.dark_mode,'dark');assert.equal(choices[0].attrs['aria-current'],undefined);assert.equal(choices[1].attrs['aria-current'],'true');
});
