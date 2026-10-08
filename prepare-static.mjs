import {mkdirSync,copyFileSync,readdirSync,statSync} from 'node:fs';
const files=['index.html','sw.js','stock-persistence.js','manifest.webmanifest',...readdirSync('.').filter(file=>/\.(png|svg)$/i.test(file)&&statSync(file).isFile())];
mkdirSync('dist',{recursive:true});
for(const file of files)copyFileSync(file,'dist/'+file);
console.log('Preparados '+files.length+' archivos públicos de Phelox.');
