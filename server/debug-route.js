import { router } from "./routes.js";
const layer = router.stack.find(l => l.route && l.route.path === "/pos/products");
console.log(layer.route.stack[0].handle.toString());
