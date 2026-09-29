# Pacote demonstrativo do CodeArtifact

Pacote npm pequeno usado para demonstrar publicação e consumo no AWS CodeArtifact.

Ele representa uma biblioteca que poderia substituir uma pequena função compartilhada do aplicativo `socorro`, sem publicar o aplicativo inteiro. Neste exemplo, a biblioteca normaliza nomes de serviços antes de exibi-los ou salvá-los.

## Uso

```js
const { formatServiceName } = require('socorro-demo-utils');

formatServiceName('  Pintura   residencial ');
// Pintura residencial
```
