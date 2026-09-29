# Imagem web reduzida para o ECR

O `Dockerfile` representa um pipeline simplificado de aplicação:

1. A imagem Node instala as dependências e executa `npm run build`.
2. A imagem Nginx recebe o artefato gerado e serve a aplicação.

O exemplo não depende do Expo, Firebase ou do projeto `socorro`. Isso permite testar o fluxo do ECR mesmo quando o build web completo do aplicativo não está funcionando.

Execute a partir da raiz do repositório:

```bash
docker build -f ecr-demo/Dockerfile -t socorro-web:1.0.0 .
docker run --rm -p 8080:80 socorro-web:1.0.0
```

Abra `http://localhost:8080` para testar localmente. A aplicação exibirá o identificador do build gerado dentro do container.

Para publicar no ECR, defina a região e a conta, autentique o Docker e aplique a tag do seu registry:

```bash
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
registry="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" |
	docker login --username AWS --password-stdin "$registry"

docker tag socorro-web:1.0.0 "$registry/socorro-web:1.0.0"
docker push "$registry/socorro-web:1.0.0"
```
