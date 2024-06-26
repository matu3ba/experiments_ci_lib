## Experiemnts towards a Continous Integration library

### Why?

* Zig for static typing and extensible build system
* More control and flexibility on user permissions management
* Simpler debugging of the CI and user programs with elevated permissions
* Clang and zig behavior tested upstream
* User land upfront decidable resource usage and scheduling rules

### Why not?

* Few security related projects like sandboxing, VMs, hypervisors
* Projects not widely used
* No extensive (attack vector) tests for various use cases

### Idealized vs Reality

Purpose of Continous Integration [CI]: Remote execution service of configurable
runtime environments[1] with the option to do problem debugging[2] and access
control to prevent, restrict and/or detect hostile takeover (attempts) of
infrastructure through malicious actors[3].
Based on access control and detection and/or design, recovery or system
reproducibility from an as minimal as secure and safe trusted immutable
(bootstrapping) system may be implemented[4].

Concrete CI implementations may then choose different tradeoffs for these
purposes, for example what user interactions the control server allows, if and
how runners are added, what they consist of physically, how and what work is
assigned and synchronized, how data (permissions, configuration, files, source
code) are stored, cached, archived.

### Simplified building blocks

* Inspired by https://gregoryszorc.com/blog/2021/04/07/modern-ci-is-too-complex-and-misdirected/
* Build your own remote code execution as service platform to device tradeoffs on
  near real time and batch/delayed execution
* Single DAG dictating all build, testing, and release tasks (zig build)
* Uploading your DAG to an execution service
* Configuration + debugging customer responsibility

### Challenges

* mutable system ressources create nonreproducible (global) state
  + sandboxing, virtualization, minimal system images resets
* sandboxing control potentially unviable (for proprietary systems)
  + virtualization, minimal system images resets
* cross-compiling limited for proprietary systems
  + documentation, hardware and licenses to cope
* qemu has huge attack surface due to hugely untested and complex code
  + limit access, verified Kernels or hypervisors (sel4)?
