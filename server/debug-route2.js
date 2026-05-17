import { router } from "./routes.js";
router.stack.forEach((layer, index) => {
  if (layer.route && layer.route.path.includes('/pos/products')) {
    const methods = Object.keys(layer.route.methods).join(',');
    console.log(index, layer.route.path, methods, layer.route.stack[0].handle.name || '<anon>');
  }
});
