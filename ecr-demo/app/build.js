const fs = require('node:fs');
const path = require('node:path');

const sourcePath = path.join(__dirname, 'src', 'index.html');
const outputDirectory = path.join(__dirname, 'dist');
const outputPath = path.join(outputDirectory, 'index.html');
const buildTime = process.env.BUILD_TIME || new Date().toISOString();

fs.mkdirSync(outputDirectory, { recursive: true });
const html = fs.readFileSync(sourcePath, 'utf8').replace('__BUILD_TIME__', buildTime);
fs.writeFileSync(outputPath, html);
console.log(`Built ${outputPath}`);
