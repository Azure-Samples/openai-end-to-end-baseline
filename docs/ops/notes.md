# Ops in Open AI & Prompt Flow architecture

Outcome: Customers understand how to design typical deployment operation flows around this specific architecture.

Topics: Infrastructure Ops, Chat App, and [LLMOps flow](https://github.com/microsoft/llmops-promptflow-template)

What: Text and Diagrams

How?

- Interview style?
- Everyone can take a topic and submit some seed text?
- One person to draft it and the rest of us review?
- ?

Two articles possible:

- MUST have for the Reference Architecture, something like <https://learn.microsoft.com/azure/architecture/web-apps/app-service/architectures/baseline-zone-redundant#deployment>  -- This is P0.
- CAN have a dedicated guide that allows us to go even deeper.

Who (roles) is involved?

- Infrastructure
- Application Developer
- Data scientist
- Applied scientist

Where are actions performed?

- Playground
- Authoring
- Prompt engineering
- Application development
- Model finetuning
- A/B deployments

Assets:

- Code repo layout (app colocation with infra and models)
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

What infrastructure is per engineer?

Anything shared across environments?

What infrastructure becomes a singleton used across multiple workloads?
What infrastructure is workload specific?

Same question as about, but for components of Azure ML Studio 
Like: Runtimes, dedicated compute, deployments, traffic splitting

Same question as about, but for components of Azure Open AI Studio
Like: Models, runtimes
