# CodeArtifact e ECR na AWS

Explorando e documentando os principais recursos do **AWS CodeArtifact** e do **Amazon Elastic Container Registry (ECR)**, com exemplos práticos para começar.

## Objetivos

- Entender quando usar o CodeArtifact e o ECR.
- Criar os recursos básicos usando a AWS CLI.
- Publicar, consumir e versionar pacotes e imagens de contêiner.
- Registrar boas práticas de segurança, acesso e limpeza.

## Pré-requisitos

- Uma conta AWS com permissões para CodeArtifact, ECR e IAM.
- AWS CLI instalada e configurada no WSL:

	```bash
	aws configure
	```

- Uma região escolhida para os exemplos. Os recursos e os comandos abaixo devem usar a mesma região.
- Para ECR, Docker instalado e em execução.
- Para publicar pacotes no CodeArtifact, o gerenciador correspondente instalado, como npm, Maven, NuGet ou pip.

Defina algumas variáveis para evitar repetir valores nos comandos:

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

Os exemplos deste repositório usam Bash no WSL. Não é necessário configurar o npm globalmente: os scripts usam um `.npmrc` temporário com o token do CodeArtifact.

## AWS CodeArtifact

O CodeArtifact é um repositório gerenciado para armazenar, publicar e compartilhar dependências de software. Ele pode funcionar como repositório privado e também como proxy de repositórios públicos, reduzindo a dependência direta dos ambientes de build em serviços externos.

### Principais features

- Repositórios privados para pacotes npm, Maven, NuGet, PyPI e outros formatos suportados.
- Domínios para organizar repositórios e aplicar políticas de acesso.
- Repositórios upstream para buscar dependências públicas por meio do CodeArtifact.
- Integração com IAM, CloudTrail e serviços de CI/CD.
- Controle de versões, publicação e consumo de pacotes com autenticação temporária.
- Criptografia com AWS KMS e possibilidade de usar uma chave gerenciada pelo cliente.

### Primeiros passos

#### 1. Criar um domínio e um repositório

```bash
export CODEARTIFACT_DOMAIN=meu-dominio
export CODEARTIFACT_REPOSITORY=meu-repositorio

aws codeartifact create-domain \
	--domain "$CODEARTIFACT_DOMAIN" \
	--region "$AWS_REGION"

aws codeartifact create-repository \
	--domain "$CODEARTIFACT_DOMAIN" \
	--repository "$CODEARTIFACT_REPOSITORY" \
	--domain-owner "$AWS_ACCOUNT_ID" \
	--description "Repositório privado de pacotes" \
	--region "$AWS_REGION"
```

#### 2. Obter um token de autorização

O token é temporário. Em pipelines, prefira solicitá-lo durante a execução em vez de gravá-lo no código ou em arquivos versionados.

```bash
export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
	--domain "$CODEARTIFACT_DOMAIN" \
	--domain-owner "$AWS_ACCOUNT_ID" \
	--region "$AWS_REGION" \
	--query authorizationToken \
	--output text)
```

#### 3. Configurar um cliente de pacotes

Exemplo com npm:

```bash
export CODEARTIFACT_ENDPOINT=$(aws codeartifact get-repository-endpoint \
	--domain "$CODEARTIFACT_DOMAIN" \
	--domain-owner "$AWS_ACCOUNT_ID" \
	--repository "$CODEARTIFACT_REPOSITORY" \
	--format npm \
	--region "$AWS_REGION" \
	--query repositoryEndpoint \
	--output text)

Para este repositório, use `scripts/publish-codeartifact.sh` e `scripts/consume-codeartifact.sh`. Eles configuram o endpoint apenas durante o comando e removem o token ao terminar.
```

Depois disso, use os scripts deste repositório para publicar e consumir o pacote. Eles configuram o token de autenticação temporariamente, sem alterar o registry global do npm.

Para Maven, NuGet e Python, consulte os comandos específicos gerados pelo botão **View connection instructions** do repositório no console ou pelo comando `aws codeartifact get-repository-endpoint`.

### Próximos tópicos de CodeArtifact

- Configuração de repositórios upstream e conexão com o npmjs, PyPI ou Maven Central.
- Políticas IAM para administradores, publicadores e consumidores.
- Integração com CodeBuild, GitHub Actions e outros pipelines.
- Retenção, limpeza de versões e custos.
- Uso de VPC endpoints quando o build não deve acessar a internet.

## Fluxo reproduzível deste projeto

O repositório contém dois exemplos independentes. O projeto Expo `socorro` fica disponível como referência, mas não é necessário para executar os testes de CodeArtifact e ECR:

- `codeartifact-demo/`: pacote npm pequeno para publicar e consumir no CodeArtifact.
- `ecr-demo/`: aplicação web mínima construída com Node dentro do Docker e servida com Nginx.

Os comandos abaixo usam Bash no WSL e devem ser executados na raiz deste repositório.

### Pré-requisitos

- AWS CLI configurada (`aws configure`).
- Node.js e npm instalados.
- Docker Desktop iniciado para o fluxo do ECR.
- Permissões IAM para CodeArtifact, ECR e `sts:GetCallerIdentity`.

### 1. Definir variáveis AWS

```bash
export AWS_REGION="us-east-1"
export CODEARTIFACT_DOMAIN="meu-dominio"
export CODEARTIFACT_REPOSITORY="meu-repositorio"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
```

### 2. Criar o domínio e o repositório CodeArtifact

```bash
aws codeartifact create-domain \
	--domain "$CODEARTIFACT_DOMAIN" \
	--region "$AWS_REGION"

aws codeartifact create-repository \
	--domain "$CODEARTIFACT_DOMAIN" \
	--repository "$CODEARTIFACT_REPOSITORY" \
	--domain-owner "$AWS_ACCOUNT_ID" \
	--region "$AWS_REGION"
```

Se os recursos já existirem, esses dois comandos podem retornar erro; nesse caso, continue para a publicação.

### 3. Publicar e consumir no CodeArtifact

O script solicita um token temporário, cria um `.npmrc` temporário e o remove ao terminar:

```bash
chmod +x scripts/*.sh
./scripts/publish-codeartifact.sh
./scripts/consume-codeartifact.sh
```

O segundo script instala `socorro-demo-utils` em `codeartifact-demo-consumer/` e executa a função publicada. Essa função representa uma pequena parte reutilizável do app, como normalização de nomes de serviços. O token não é salvo no projeto.

### 4. Criar o repositório ECR

```bash
aws ecr create-repository \
	--repository-name socorro-web \
	--image-scanning-configuration scanOnPush=true \
	--region "$AWS_REGION"
```

### 5. Gerar e testar a imagem localmente

```bash
docker build -f ecr-demo/Dockerfile -t socorro-web:1.0.0 .
docker run --rm -p 8080:80 socorro-web:1.0.0
```

Abra `http://localhost:8080` no navegador. O build é reduzido de propósito: a etapa Node simula a construção da aplicação e a etapa Nginx simula o runtime da imagem publicada no ECR. O `socorro` não é necessário para esse teste.

### 6. Publicar a imagem no ECR

```bash
export ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" |
	docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker tag socorro-web:1.0.0 "$ECR_REGISTRY/socorro-web:1.0.0"
docker push "$ECR_REGISTRY/socorro-web:1.0.0"
```

Para limpar os recursos de teste depois, remova a imagem e o repositório ECR e, separadamente, as versões do pacote e o repositório CodeArtifact conforme a política da sua conta AWS.

## Amazon ECR

O Amazon ECR é um registro gerenciado para armazenar, verificar, versionar e distribuir imagens de contêiner. Ele se integra ao ECS, EKS, Fargate, CodeBuild e outras ferramentas de execução ou entrega.

### Principais features

- Repositórios privados e públicos para imagens OCI/Docker.
- Tags imutáveis e configuração de escaneamento de vulnerabilidades.
- Criptografia em repouso com AWS KMS.
- Políticas de ciclo de vida para remover imagens antigas.
- Replicação entre regiões e contas.
- Integração com IAM, CloudTrail, ECS, EKS e CI/CD.

### Primeiros passos

#### 1. Criar um repositório

```bash
export ECR_REPOSITORY=meu-aplicativo

aws ecr create-repository \
	--repository-name "$ECR_REPOSITORY" \
	--image-scanning-configuration scanOnPush=true \
	--image-tag-mutability IMMUTABLE \
	--region "$AWS_REGION"
```

> Tags imutáveis ajudam a evitar que uma tag existente seja sobrescrita acidentalmente. Para fluxos que exigem tags mutáveis, altere `IMMUTABLE` para `MUTABLE`.

#### 2. Autenticar o Docker

```bash
aws ecr get-login-password --region "$AWS_REGION" | \
	docker login --username AWS --password-stdin \
	"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
```

#### 3. Criar, marcar e publicar uma imagem

```bash
export IMAGE_TAG=1.0.0
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export IMAGE_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

docker build -f ecr-demo/Dockerfile -t "$ECR_REPOSITORY:$IMAGE_TAG" .
docker tag "$ECR_REPOSITORY:$IMAGE_TAG" "$IMAGE_URI"
docker push "$IMAGE_URI"
```

#### 4. Consultar e baixar imagens

```bash
aws ecr describe-images \
	--repository-name "$ECR_REPOSITORY" \
	--region "$AWS_REGION"

docker pull "$IMAGE_URI"
```

### Próximos tópicos de ECR

- Políticas de ciclo de vida e remoção de imagens não utilizadas.
- Escaneamento básico e enhanced scanning com Amazon Inspector.
- Pull through cache para imagens públicas.
- Replicação entre regiões e contas AWS.
- Integração com ECS, EKS, Fargate e pipelines de CI/CD.
- Uso de digest em produção, em vez de depender apenas de tags.

## Segurança e custos

- Conceda o menor conjunto possível de permissões IAM.
- Não versionar tokens, chaves AWS ou credenciais de registry.
- Prefira roles para workloads e pipelines em vez de credenciais de longa duração.
- Monitore acessos com CloudTrail e custos com AWS Cost Explorer.
- Defina políticas de retenção para evitar acumular pacotes e imagens sem uso.

## Estrutura atual

```text
.
├── README.md
├── codeartifact-demo/
│   ├── index.js
│   ├── package.json
│   └── README.md
├── ecr-demo/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── README.md
│   └── app/
│       ├── build.js
│       ├── package.json
│       └── src/index.html
├── scripts/
│   ├── publish-codeartifact.sh
│   └── consume-codeartifact.sh
└── socorro/
    └── aplicativo Expo de referência
```

## Referências oficiais

- [AWS CodeArtifact](https://aws.amazon.com/codeartifact/)
- [Documentação do CodeArtifact](https://docs.aws.amazon.com/codeartifact/)
- [Amazon ECR](https://aws.amazon.com/ecr/)
- [Documentação do Amazon ECR](https://docs.aws.amazon.com/ecr/)
