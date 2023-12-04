# Ops in Open AI & Prompt Flow architecture

Outcome: Customers understand how to design typical operations flows around this architecture.
Topics: Infrastructure Ops and LLMOps flow
What: Text and Diagrams

Who (roles) is involved?

- Infrastructure
- Application Developer
- Data scientist
- Applied scientist

Where are actions performed?

- Playground
- Prompt engineering
- Application development
- Model finetuning

Assets:

- Hosting infrastructure
- LLM
- agents
- plugins
- prompts
- prompt flows
- chains
- APIs

Moving from local experiementation to production.

Relationship to MLOps?

What?

- Pre production environments
- Production environments

Flow Lifecycle as compared to infrastructure lifecycle.

What infrastructure is transient?  for example, only used during LLMOps CE steps?

What infrastructure is permanent per environment?

Anything shared across environments?

What infrastructure becomes a singleton used across multiple workloads?
What infrastructure is workload specific?

Same question as about, but for components of Azure ML Studio 
Like: Runtimes, dedicated compute, deployments, traffic splitting

Same question as about, but for components of Azure Open AI Studio
Like: Models, runtimes
