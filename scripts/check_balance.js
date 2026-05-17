const fs = require('fs');
const s = fs.readFileSync('client/src/App.jsx', 'utf8').split('\n');
let counts = { paren: 0, brack: 0, brace: 0 };
for (let i = 0; i < s.length; i++) {
  const line = s[i];
  for (const ch of line) {
    if (ch === '(') counts.paren++;
    if (ch === ')') counts.paren--;
    if (ch === '[') counts.brack++;
    if (ch === ']') counts.brack--;
    if (ch === '{') counts.brace++;
    if (ch === '}') counts.brace--;
  }
  if (counts.paren !== 0 || counts.brace !== 0 || counts.brack !== 0) {
    console.log(`${i+1}: ${JSON.stringify(counts)} | ${line.trim()}`);
    break;
  }
}
console.log('Done');
