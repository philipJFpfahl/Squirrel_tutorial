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
| **`1D_channel/channel_SS.i`**           | Steady-state DNP and flux calculation                  |
| **`1D_channel/Squirrel_SS.i`**          | Reactivity loss postprocessing for steady state        |
| **`1D_channel/channel.i`**              | Transient simulation restart (no temperature feedback) |
| **`1D_channel/Squirrel.i`**             | Power evolution and flux scaling during transient      |
| **`1D_channel_temp/channel_SS.i`**      | Steady-state with temperature variable                 |
| **`1D_channel_temp/Squirrel_SS.i`**     | Steady-state with thermal feedback enabled             |
| **`1D_channel_temp/channel.i`**         | Transient with temperature feedback                    |
| **`1D_channel_temp/Squirrel.i`**        | Transient calculation with thermal reactivity effects  |

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

## ⚙️ 1D Channel Case (No Temperature Feedback)

This folder contains four input files. The two with the **_SS** suffix are for steady-state calculations and must be executed first.
Their output files are used as inputs for the transient simulations.


### 🧮 Steady-State Calculation 

This file defines two main variables:

* **C** – delayed neutron precursor (DNP) concentration
* **flux** – neutron flux in the channel
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

The governing equation solved is:


$$\frac{\partial C(x,t)}{\partial t} = \beta , \text{flux}(x) - \lambda C(x,t) - \frac{\partial}{\partial x}(U(x,t) C(x,t))$$

with the coresponding Kernels:
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
We will assume that the flux, and the fission rate are the same. That is not correct, but could be corrected with a simple factor that canceled in the equation. It is still possible to simply add that factor.

Boundary conditions define inflow and outflow for the advected DNPs.

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

With the time steper we let the solution converge 

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


The DNP concentration is then transferred to **`Squirrel_SS.i`**, which computes the **static reactivity loss** due to fuel motion.


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
Now in the **`Squirrel_SS.i`** file:

The transfered information is used to calculate the static reactivity loss. 

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

using the post processors of Squirrel we can calculate the static reactivity loss due to the flowing fuel.

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



Expected result:

```
| time           | B              | Rho_Flow       | S              |
|----------------|----------------|----------------|----------------|
|   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
```

🧾 **Static reactivity loss:** 121.7 pcm (steady after ~1000 s)

---

### ⚡ Transient Calculation – 

This simulation restarts from the steady-state output (**`channel_SS_out.e`**) and adds a **10 pcm reactivity insertion**.
It also uses **`Squirrel.i`** to update the flux dynamically.

Power is scaled using the scalar variable `power_scalar`, which follows:

[
\frac{dp(t)}{dt} = \frac{(\rho_{insertion} + \rho_{external} - \beta)}{\Lambda}p(t) + \frac{S}{\Lambda}
]

For this case:

```
| time | power_scalar |
|------|---------------|
| 10 s | 1.3188        |
```

➡️ The power continues to rise due to the absence of temperature feedback.

---

## 🌡️ 1D Channel with Temperature Feedback

This folder again includes four input files (**`channel_SS.i`**, **`channel.i`**, and corresponding **Squirrel** files).
Now, temperature feedback is introduced through an additional field **T**.

### Run Instructions

```bash
./squirrel-opt -i channel_SS.i
./squirrel-opt -i channel.i
```

### 🧮 Steady-State – `channel_SS.i`

A new variable **T** is introduced, governed by advection, heating in the active region, and cooling in the heat exchanger.

### ⚡ Transient – `channel.i` and `Squirrel.i`

The temperature is transferred to **`Squirrel.i`**, where the **temperature feedback reactivity** is computed via:

[
\rho_T = \int (\text{T} - \text{T}_\text{ref}) , w(\text{flux}) , dx
]

This feedback modifies the power equation:

[
\frac{dp}{dt} = \frac{(\rho_{insertion} + \rho_{external} + \rho_T - \beta)}{\Lambda}p + \frac{S}{\Lambda}
]

Output:

```
| time | power_scalar |
|------|---------------|
| 10 s | 1.0038        |
```

➡️ The temperature feedback stabilizes the power, returning it close to the steady-state value.


## 🧠 Notes

* Always run steady-state simulations before transients.
* Ensure correct linking of output and restart files.
* The examples are simplified but illustrate the main Squirrel–MOOSE coupling workflow.

