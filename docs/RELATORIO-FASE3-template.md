# Tech Challenge - Fase 3 | ToggleMaster

## Participantes

| Nome | RM | Discord |
|---|---|---|
| Lucas Gabriel E. Campos | RM371200 | Campalô |
| Rafael Marques Muniz | RM373742 | KaollanRafa |
| Edson Maciel do Vale Junior | RM372784 | EJR_04#8240 |
| João Pedro Soares Oliveira | RM371227 | Jotape |
| Matheus Villão Gonçalves | RM370682 | villao. |

## Links

- Repositório GitHub: https://github.com/EdsonJunior04/togglemaster-tech-challenge-fase-2.git
- Vídeo demonstrativo: (cole aqui)
- Documentação/diagramas: (cole aqui, se houver)

## Resumo do Projeto

Na Fase 2, o ToggleMaster foi migrado de monólito para 5 microsserviços
(auth, flag, targeting, evaluation, analytics) rodando em Kubernetes (EKS),
mas toda a infraestrutura foi provisionada manualmente pelo console AWS e o
deploy era feito via `kubectl apply` local.

Na Fase 3, o objetivo foi eliminar esses dois pontos de dor:

1. **Infraestrutura como Código**: toda a infraestrutura (VPC, EKS, 3 RDS
   PostgreSQL, ElastiCache Redis, DynamoDB, SQS, 5 repositórios ECR) passou a
   ser provisionada via Terraform modularizado, com state remoto em S3.
2. **DevSecOps + GitOps**: cada microsserviço ganhou um pipeline de CI
   (GitHub Actions) com build, lint, SAST (gosec/bandit), SCA (Trivy) e
   scan de imagem, bloqueando vulnerabilidades críticas. O deploy deixou de
   ser via `kubectl apply` manual e passou a ser via ArgoCD, que sincroniza
   automaticamente os manifestos de um diretório `gitops/` sempre que o
   pipeline atualiza a tag da imagem.

## Desafios Encontrados e Decisões Tomadas

*(preencher com a experiência real do grupo — alguns pontos comuns para
adaptar:)*

- **Restrição do AWS Academy (sem IAM custom)**: o cluster EKS e os Node
  Groups foram associados à `LabRole` existente via `data "aws_iam_role"`,
  em vez de criar roles/policies novas — decisão obrigatória para quem usa
  conta de laboratório.
- **Credenciais temporárias**: como o AWS Academy expira a sessão, o
  `AWS_SESSION_TOKEN` precisa ser atualizado nos Secrets do GitHub Actions e
  no Secret `aws-credentials` do cluster a cada nova sessão de lab.
- **GitOps no mesmo repositório**: optamos por manter os manifestos de
  deploy numa pasta `gitops/` dentro do monorepo em vez de um repositório
  separado, simplificando a autenticação do pipeline (usa o `GITHUB_TOKEN`
  nativo em vez de um PAT).
- **Nomenclatura de recursos**: a fila SQS e a tabela DynamoDB foram
  nomeadas para bater exatamente com o que os serviços já esperavam no
  ConfigMap da Fase 2, evitando reescrever código de aplicação.

## Estimativa de Custos AWS

*(print da AWS Pricing Calculator ou do Cost Explorer aqui)*

## Conclusão

*(preencher)*
