# Neura Task Hub

A decentralized AI task marketplace built on Stacks, enabling clients to post tasks with STX rewards and AI providers to claim, complete, and earn payments.

## Features

- **Post Tasks**: Clients create tasks with STX rewards (balance validated)
- **Claim Tasks**: Providers claim tasks (prevents double-claiming)
- **Submit Results**: Providers submit output hash upon completion
- **Release Payment**: Clients validate and release STX to providers
- **Auto-Refund**: Unclaimed tasks refund after deadline

## Contract Functions

| Function | Role | Purpose |
|----------|------|---------|
| `post-task` | Client | Create task with reward |
| `claim-task` | Provider | Claim unclaimed task |
| `submit-result` | Provider | Submit output hash |
| `release-payment` | Client | Release STX to provider |
| `refund-task` | Anyone | Refund expired unclaimed tasks |
| `get-task` | Public | Query task details |

'm in read-only mode. Switch to Code mode if you'd like to refine this or create a full README.md file.
