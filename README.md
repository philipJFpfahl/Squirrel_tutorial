Here’s a more structured and consistent version of your README with added file labels, formatting, and equations preserved exactly as requested:

---

# 🐿️ Squirrel Tutorial

This repository provides a simple tutorial demonstrating the use of **Squirrel**, a framework for modeling delayed neutron precursor (DNP) transport and feedback effects in flowing-fuel reactor systems.

📘 For downloading Squirrel, theoretical background, and kernel explanations, see the official repository:
🔗 [Squirrel GitHub – by Philip Pfahl](https://github.com/philipJFpfahl/Squirrel)

These input files were originally part of a DTU university course.
**Author:** Philip Pfahl
**Contact:** [Philip.j.f.pfahl@gmail.com](mailto:Philip.j.f.pfahl@gmail.com)

---

## Overview

This tutorial demonstrates the basic application of Squirrel using a **simplified 1D channel model**. Two setups are included:

1. **1D channel** – neglecting temperature feedback
2. **1D channel (temp)** – including temperature feedback

Each setup illustrates how to compute a **steady-state** solution for a molten salt reactor with flowing fuel and how to **run transient simulations** from that steady-state condition.

### 📂 Input File Overview

| Input File                   | Description                                            |
| ---------------------------- | ------------------------------------------------------ |
| **`channel_SS.i`**           | Steady-state DNP and flux calculation                  |
| **`Squirrel_SS.i`**          | Reactivity loss postprocessing for steady state        |
| **`channel.i`**              | Transient simulation restart (no temperature feedback) |
| **`Squirrel.i`**             | Power evolution and flux scaling during transient      |
| **`channel_SS.i`** *(temp)*  | Steady-state with temperature variable                 |
| **`Squirrel_SS.i`** *(temp)* | Steady-state with thermal feedback enabled             |
| **`channel.i`** *(temp)*     | Transient with temperature feedback                    |
| **`Squirrel.i`** *(temp)*    | Transient calculation with thermal reactivity effects  |

### Run Instructions

To run the steady-state and transient calculations:

```bash
./squirrel-opt -i channel_SS.i
./squirrel-opt -i channel.i
```

These commands will produce a steady-state solution from **`channel_SS.i`**, which is then used to restart the transient simulation in **`channel.i`**.
The transient represents a **10 pcm positive reactivity insertion**, without temperature feedback.

---

## 🧩 Model Description

The model consists of two 1D regions of equal length (**L/2**):

* A **critical core region** (where fission occurs)
* A **non-critical out-of-core region**

```ini
[Mesh]
    [cmbn]
        type = CartesianMeshGenerator
        dim = 1
        dx = '${fparse L/2} ${fparse L/2}'
        ix = '${nx} ${nx}'
        subdomain_id = '1 0'
    []
[]
```

A constant flow of fuel salt from left to right is assumed.

---

### 1D channel

This folder contains four input files. The two input files with the subscript `_SS` are for steady-state calculations and need to be run first. The outputs are used as inputs for the transient simulation.

---

## The Steady-State Calculations

**Starting with the `channel_SS.i` file:**
Two variables are defined. The DNP concentration "C" with one group, and the flux "flux" in the channel.

```ini
[Variables]
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]

[AuxVariables]
    [flux]
        family = MONOMIAL
        order = CONSTANT
        fv = true
    []
[]
```

Now we define the Kernels to solve:

$$\frac{\partial  c(x,t)}{\partial t}   =  \beta \cdot \text{flux}(x) - \lambda \cdot c(x,t) - \frac{\partial}{\partial x} \mathbf{U}(x,t) \cdot c(x,t) $$

```ini
[FVKernels]
  #Time kernel
  [C_time]
    type = FVTimeKernel
    variable = C
  []
  #DNP production kernel
  [C_external]
    type = FVCoupledForce
    variable = C
    coef = ${fparse beta}  
    v = 'flux'
    block = '1'
  []
  #DNP decay kernel
  [C_interal]
    type = FVCoupledForce
    variable = C
    coef =   ${fparse -lambda}
    v = C
  []
  #Advection kernel
  [C_advection]
    type = FVAdvection
    variable = C
    velocity = '${vel} 0 0'
  []
[]
```

There is a time kernel, a production kernel (restricted to block 1, where the reactor is critical), a decay kernel, and an advection kernel.
We will assume that the flux and the fission rate are the same. That is not correct, but could be corrected with a simple factor that cancels in the equation.

Likewise, we will define an outflow and inflow boundary condition for the advected DNP concentration.

```ini
[FVBCs]
  [inlet_C]
    type = FVFunctorDirichletBC
    boundary = 'left'
    variable = C
    functor = BC_C 
  []
  [Outlet_C]
    type = FVConstantScalarOutflowBC
    velocity = '${vel} 0 0'
    variable = C
    boundary = 'right'
  []
[]
```

And we define the shape of the flux on the whole domain.

```ini
[FVICs]
  [flux_ic]
    type = FVFunctionIC
    variable = 'flux'
    function = parsed_function
  []
[]

[Functions]
  [parsed_function]
    type = ParsedFunction
    expression = '0.5*sin(2*x*pi/L)'
    symbol_names = 'L'
    symbol_values = '${L}'
  []
[]
```

With the time stepper, we let the solution converge.

```ini
[TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.001
    optimal_iterations = 20
    iteration_window = 2
    growth_factor = 2
    cutback_factor = 0.5
[]
```

The DNP concentration will be sent to the `Squirrel_SS.i` file.

```ini
[MultiApps]
    [Squirrel]
      type = TransientMultiApp
      input_files = "Squirrel_SS.i"
      execute_on= "timestep_end "
      sub_cycling = false
    []
[]

[Transfers]
    [push_C]
        type = MultiAppGeneralFieldShapeEvaluationTransfer
        to_multi_app = Squirrel 
        source_variable = C  
        variable = C
        execute_on= "timestep_end initial"
    [] 
[]
```

---

### In the `Squirrel_SS.i` file:

The transferred information is used to calculate the static reactivity loss.

We define the same variable on the same mesh, but both are known values.

```ini
[AuxVariables]
  [flux]
    type = MooseVariableFVReal
  []
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
  []
[]
```

Using the postprocessors of Squirrel, we can calculate the static reactivity loss due to the flowing fuel `Rho_flow` and the spatially weighted (or effective) DNP source `S`.

```ini
[Postprocessors]
 [Rho_Flow]
  type = ParsedPostprocessor
  function = 'beta-S'
  pp_names = 'S'
  constant_names =  'beta'
  constant_expressions ='${beta}'
 []
 [B]
  type = TwoValuesL2Norm
  variable = flux
  other_variable = flux
  execute_on = 'initial'
  execution_order_group = -1
  block = 1
 []
 [S] 
  type = WeightDNPPostprocessor
  variable = flux
  other_variable = C
  Norm = B
  lambda = ${lambda}
  execute_on = 'initial timestep_end'
  block = 1
 [] 
[]
```

In this example, the loss should be **121.7 pcm**.

```bash
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: | time           | B              | Rho_Flow       | S              |
Squirrel0: +----------------+----------------+----------------+----------------+
Squirrel0: |   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
Squirrel0: +----------------+----------------+----------------+----------------+
```

We can see that it is reached after **~1000s**.

---

## The Transient Calculation

For the `channel.i` file:

Not much is changing since the thermal hydraulics stay the same.
We will now do a normal restart using the `channel_SS_out.e` file.

```ini
[Mesh]
  file = 'channel_SS_out.e'
[]
```

```ini
[Problem]
    kernel_coverage_check=false
    allow_initial_conditions_with_restart = true
[]
```

```ini
[Variables]
  [C]
      family = MONOMIAL
      order = CONSTANT
      fv = true
      initial_from_file
```
