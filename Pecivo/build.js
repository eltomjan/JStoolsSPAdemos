const fs = require('fs');
const path = require('path');

const src = path.join(__dirname,'src');
const out = path.join(__dirname,'..');
if (!fs.existsSync(out)) fs.mkdirSync(out, { recursive: true });

const template = fs.readFileSync(path.join(src,'Pecivo.htm'),'utf8');
const data = fs.readFileSync(path.join(src,'images.json'),'utf8');

let outHtml = template
  .replace(/(<script name="images">)/, `$1\n${data}\n`)

fs.writeFileSync(path.join(out,'Pecivo.htm'), outHtml, 'utf8');
console.log('Built Pecivo.htm');
