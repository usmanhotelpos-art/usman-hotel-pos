import { router } from "./routes.js";
const layer = router.stack.find(l => l.route && l.route.path === "/pos/products" && l.route.methods.get);
const handle = layer.route.stack[0].handle;
const req = { method: 'GET', url: '/pos/products', headers:{} };
const res = { send: (body) => { console.log('BODY', body); return res; }, status: (code) => { console.log('STATUS', code); return res; }, json: (body) => { console.log('JSON', body); return res; } };
const next = (err) => { if (err) console.error('ERR', err); else console.log('NEXT'); };
await handle(req,res,next);
