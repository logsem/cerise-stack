This directory contains the Coq mechanization accompanying the submission
"Efficient and Provable Local Capability Revocation using Uninitialized
Capabilities".

# Building and browsing the proofs

You need to have [opam](https://opam.ocaml.org/) >= 2.0 installed. If this is
the first time you install opam, you additionally need to run `opam init`.

Then, let us create a fresh *local* opam switch with everything needed. This
will install coq and iris in a local `_opam` directory:

```
   opam switch create -y --repositories=default,coq-released=https://coq.inria.fr/opam/released . ocaml-base-compiler.4.08.1
   eval $(opam env)
   opam install coqide  # optional, but useful to browse the proofs
```

Then, build the development:

```
make -jN  # replace N with the number of CPU cores of your machine
```

We recommend that you have **32Gb of RAM+swap**. Please be aware that the
development takes around 1h to compile. In particular, the files
`theories/examples/awkward_example{,_u}.v` can each take up to 25 minutes to
compile.

It is possible to run `make fundamental` to only build files up to the
Fundamental Theorem. This usually takes up 20 minutes.


After building, one can use `coqide` to browse the proofs (ProofGeneral works as
well):

``` 
coqide theories/fundamental.v  # for instance
```

## Troubleshooting

If the opam invocation fails at some point, either remove the `_opam` directory
and re-run the command (this will redo everything), or do `eval $(opam env)` and
then `opam install -y .` (this will continue from where it failed).

## Cleanup

It is enough to remove the `_opam` directory to get rid of everything that has
been installed for building the proofs.

To additionally get rid of *anything opam-related in general*, additionally
remove `~/.opam` (if you just installed opam and do not plan on using it
further).


# Documentation

After building the development, documentation generated using Coqdoc can be
created using `make html`. 

Then, browse the `html/toc.html` file.

Note that we have included a copy of the generated html files as a supplemental material. 

# Organization

First is a lookup table for the definitions in the paper. 

| *paper*                                                | *file* or *folder*                    | *name*                                               |
|--------------------------------------------------------|---------------------------------------|------------------------------------------------------|
| Machine words, machine state and instructions (Fig 1)  | machine\_base.v                       |                                                      |
| Permission and locality hierarchy (Fig 2)              | machine\_base.v                       | `PermFlowsTo` - `LocalityFlowsTo`                    |
| Operational semantics: reduction steps (Fig 3)         | cap\_lang.v                           | `prim_step`                                          |
| Operational semantics: instruction semantics (Fig 4)   | cap\_lang.v                           | `exec`                                               |
| Separation Logic Specifications (Fig 6)                | rules/*                               | e.g. `rules_Store.v\wp_store_success_reg`            |
| rclear Specification (Fig 6)                           | examples/stack\_macros.v              | `rclear_spec`                                        |
| Safety with Revocation (Fig 9)                         | logrel.v                              |                                                      |
| Expression relation (Fig 9)                            | logrel.v                              | `interp_expr`                                        |
| Register relation (Fig 9)                              | logrel.v                              | `interp_reg`                                         |
| Value relation (Fig 9)                                 | logrel.v                              | `interp1` (and its fixpoint `interp`)                |
| State relation (Fig 9)                                 | logrel.v                              | `region_state_*`                                     |
| Standard State Transition System (Fig 10)              | region\_invariants.v                  | `region_type` with `std_rel_pub` and `std_rel_priv`  |
| Standard Resources (Fig 11)                            | region\_invariants.v                  | inlined in `region_map_def`                          |
| Mstd                                                   | sts.v                                 | `sts_full_std`, with the global gname (γs\_std)      |
| Mcus                                                   | sts.v                                 | `sts_full`, with the global gnames (γs\_loc,γr\_loc) |
| stsCollection                                          | sts.v                                 | `sts_full_world`                                     |
| sharedResources                                        | region\_invariants.v                  | `region`                                             |
| Fundamental Theorem of Logical Relations (Theorem 6.1) | fundamental.v                         | `fundamental_from_interp`                            |
| Awkward Example: g1 (Fig 13)                           | examples/awkward\_example\_preamble.v | `awkward_preamble_instrs`                            |
| Awkward Example: f1 (Fig 13)                           | examples/awkward\_example\_u.v        | `awkward_instrs`                                     |
| Lemma 6.2                                              | examples/awkward\_example\_preamble.v | `awkward_preamble_spec`                              |
| Theorem 6.3                                            | examples/awkward\_example\_adequacy.v | `awkward_example_adequacy`                           |

Next we describe the file organization of the implementation. 

The organization of the `theories/` folder is as follows.

## Operational semantics

- `addr_reg.v`: Defines registers and the set of (finite) memory addresses.

- `machine_base.v`: Contains the syntax (permissions, capability, instructions,
  ...) of the capability machine.

- `machine_parameters.v`: Defines a number of "settings" for the machine, that
  parameterize the whole development (e.g. the specific encoding scheme for
  instructions, etc.).

- `cap_lang.v`: Defines the operational semantics of the machine, and the
  embedding of the capability machine language into Iris.

- `machine_run.v`: Defines an executable version of the operational semantics,
  allowing to use them as an interpreter to run a concrete machine
  configuration.

## Program logic

- `monocmra.v`, `mono_ref.v`: Definition of monotonic references in Iris, used
  to define the points-to predicate for memory addresses.

- `region.v`: Auxiliary definitions to reason about consecutive range of
  addresses and memory words.

- `rules_base.v`: Contains some of the core resource algebras for the program
  logic, namely the definition for points to predicates with permissions.

- `rules.v`: Imports all the Hoare triple rules for each instruction. These
  rules are separated into separate files (located in the `rules/` folder).

## Logical relation

- `multiple_updates.v`: Auxiliary definitions to reason about multiple updates
  to a world.

- `region_invariants.v`: Definitions for standard resources, and the shared
  resources map *sharedResources*. Contains some lemmas for "opening" and
  "closing" the map, akin to opening and closing invariants.

- `region_invariants_revocation.v`: Lemmas for revoking standard resources
  (setting *Temporary* invariants to a *Revoked* state).

- `region_invariants_static.v`: Lemmas for manipulating frozen standard
  resources.

- `region_invariants_uninitialized.v`: Lemmas for manipulating frozen standard
  singleton resources. These are specifically for manipulating the resources
  that are related to the interpretation of uninitialized capabilities.

- `sts.v`: The definition of *stsCollection*, and associated lemmas.

- `logrel.v`: The definition of the logical relation.

- `monotone.v`: Proof of the monotonicity of the value relation with regards to
  public future worlds, and private future worlds for non local words.

- `fundamental.v`: Contains *Theorem 6.1: fundamental theorem of logical
  relations*. Each case (one for each instruction) is proved in a separate file
  (located in the `ftlr/` folder), which are all imported and applied in this
  file.

## Case studies

In the `examples` folder:

- `stack_macros.v` and `stack_macros_u.v`: Specifications for some useful
  macros, the former for a RWLX stack and the latter for a URWLX stack.

- `scall.v`, `scall_u.v`: Specification of a safe calling convention for a RWLX
  and URWLX stack respectively. Each specification is split up into two parts:
  the prologue is the specification for the code before the jump, the epilogue
  is the specification for the activation record.

- `lse.v` : A small and simple example that relies on local state encapsulation. 

- `malloc.v`: A simple malloc implementation, and its specification.

- `awkward_example.v`, `awkward_example_u.v`: The proof of safety for the body
  of the awkward example (the former using scall with stack clearing, the latter
  using scallU without stack clearing).

- `awkward_example_preamble.v`: Proof of safety of the preamble to the awkward
  example (in which a closure to the body of the awkward example is dynamically
  allocated). This corresponds to *Lemma 6.2*.

- `awkward_example_adequacy.v`: Proof of correctness of the awkward example
  against the operational semantics of the machine, *Theorem 6.3*.

- `awkward_example_concrete.v`: A concrete instantiation of the correctness
  theorem of the awkward example on a concrete machine, linked with a concrete
  "adversarial program". Then, we also prove that this concrete machine
  configurations indeed runs and gracefully halts.


# Differences with the paper

Some definitions have different names from the paper.

*name in paper => name in mechanization*

In the operational semantics:

| *name in paper*   | *name in mechanization*   |
|-------------------|---------------------------|
| SingleStep        | Instr Executable          |
| Done Standby      | Instr NextI               |
| Done Halted       | Instr Halted              |
| Done Failed       | Instr Failed              |
| Repeat _          | Seq _                     |

In the model:

| *name in paper* | *name in mechanization* |
|-----------------|-------------------------|
| Frozen          | Static                  |
| stsCollection   | full_sts_world          |
| sharedResources | region                  |

In `scall.v` and `scall_u.v` : the scall macro is in both cases slightly unfolded, as it does not include the part of the calling convention which stores local state on the stack. That part is inlined into the awkward examples. 

In `awkward_example_u.v`: in the mechanized version of the awkward example (uninitialized version), we clear the local stack frame in two stages: before the second call, we clear the part of the frame which is frozen during the first call, but passed to the adversary during the second call (i.e. a single address at the top of the first local stack frame), and before returning to the caller we clear the rest of the local stack frame (see Section 4.2 for further detail on clearing the local stack frame upon returning to an adversary call). 
