# CodeArtifact e ECR na AWS

Explorando e documentando os principais recursos do **AWS CodeArtifact** e do **Amazon Elastic Container Registry (ECR)**, com exemplos práticos para começar.

## Objetivos

- Entender quando usar o CodeArtifact e o ECR.
- Criar os recursos básicos usando a AWS CLI.
- Publicar, consumir e versionar pacotes e imagens de contêiner.
- Registrar boas práticas de segurança, acesso e limpeza.

## Pré-requisitos

- Uma conta AWS com permissões para CodeArtifact, ECR e IAM.
- AWS CLI instalada e configurada:

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

> No Windows PowerShell, use `$env:AWS_REGION = "us-east-1"` e `$env:AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)`.

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

npm config set registry="${CODEARTIFACT_ENDPOINT}/"
npm config set "//${CODEARTIFACT_ENDPOINT#https:}/:_authToken" "$CODEARTIFACT_AUTH_TOKEN"
```

Depois disso, publique e instale pacotes conforme o fluxo do projeto:

```bash
npm publish
npm install nome-do-pacote
```

Para Maven, NuGet e Python, consulte os comandos específicos gerados pelo botão **View connection instructions** do repositório no console ou pelo comando `aws codeartifact get-repository-endpoint`.

### Próximos tópicos de CodeArtifact

- Configuração de repositórios upstream e conexão com o npmjs, PyPI ou Maven Central.
- Políticas IAM para administradores, publicadores e consumidores.
- Integração com CodeBuild, GitHub Actions e outros pipelines.
- Retenção, limpeza de versões e custos.
- Uso de VPC endpoints quando o build não deve acessar a internet.

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

docker build -t "$ECR_REPOSITORY:$IMAGE_TAG" .
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

## Estrutura planejada

```text
.
├── README.md
├── codeartifact/
│   ├── conceitos.md
│   ├── primeiros-passos.md
│   └── boas-praticas.md
└── ecr/
		├── conceitos.md
		├── primeiros-passos.md
		└── boas-praticas.md
```

## Referências oficiais

- [AWS CodeArtifact](https://aws.amazon.com/codeartifact/)
- [Documentação do CodeArtifact](https://docs.aws.amazon.com/codeartifact/)
- [Amazon ECR](https://aws.amazon.com/ecr/)
- [Documentação do Amazon ECR](https://docs.aws.amazon.com/ecr/)
