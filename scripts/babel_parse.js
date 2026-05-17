const fs = require('fs');
const parser = require('@babel/parser');
const code = fs.readFileSync('client/src/App.jsx','utf8');
try{
  parser.parse(code, {sourceType: 'module', plugins:['jsx','classProperties','optionalChaining']});
  console.log('Parsed OK');
}catch(e){
  console.error('Parse error:', e.message);
  console.error(e.loc);
}
