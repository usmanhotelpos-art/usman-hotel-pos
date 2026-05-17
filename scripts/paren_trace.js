const fs = require('fs');
const s = fs.readFileSync('client/src/App.jsx', 'utf8').split('\n');
let paren=0, brace=0, brack=0;
for (let i=0;i<s.length;i++){
  const line = s[i];
  for (const ch of line){ if(ch==='(') paren++; if(ch===')') paren--; if(ch==='{') brace++; if(ch==='}') brace--; if(ch==='[') brack++; if(ch===']') brack--; }
  if(i>=5400 && i<=5610) console.log(`${i+1}: paren=${paren} brace=${brace} | ${line}`);
}
console.log('final', {paren, brace, brack});
