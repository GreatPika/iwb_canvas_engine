# Architecture

## 1. Purpose

Describe what this document explains, who it is for, and which checked-in files are the real source of truth.

## 2. Package boundary

### Public boundary

- Public package entrypoint:
- Schema write version:
- Schema read versions:

### What the package owns

- 

### What the package does not own

- 

## 3. Architectural goals

1. 
2. 
3. 
4. 

## 4. Public API map

### Boundary contract

- 

### Runtime and view

- 

### Import and serialization

- 

## 5. Core architectural model

### 5.1 Public boundary vs runtime state

### 5.2 Canonical document shape

### 5.3 Read side vs write side

### 5.4 Major runtime seams

## 6. Layered architecture

| Layer | Responsibility | Allowed lower-layer dependencies | Key files / seams |
|---|---|---|---|
| `contract` |  |  |  |
| `core` |  |  |  |
| `model` |  |  |  |
| `controller` |  |  |  |
| `interactive` |  |  |  |
| `render` |  |  |  |
| `serialization` |  |  |  |
| `view` |  |  |  |

### Actual dependency direction

```mermaid
flowchart LR
```

### Important boundary rules

1. 
2. 
3. 

## 7. Runtime building blocks

### Public roots

### Committed store and write subsystem

### Interactive runtime

### View/runtime seam

### Rendering

## 8. Main execution flows

### Build or import flow

### Transactional write flow

### Pointer or interaction flow

### Paint flow

### Serialization flow

## 9. Cross-cutting invariants

1. 
2. 
3. 

## 10. Mechanical enforcement

- 

## 11. Extension guidance

### Safe directions

- 

### Forbidden directions

- 

## 12. Decision records

- ADRs:

## 13. Summary

