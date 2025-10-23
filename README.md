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

### Run Instructions

To run the steady-state and transient calculations:

```bash
./squirrel-opt -i channel_SS.i
./squirrel-opt -i channel.i
```

These commands will produce a steady-state solution from **`channel_SS.i`**, which is then used to restart the transient simulation in **`channel.i`**.
The transient represents a **10 pcm positive reactivity insertion**, without temperature feedback.

---

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


### 🧮 Steady-State Calculation – `channel_SS.i`

This file defines two main variables:

* **C** – delayed neutron precursor (DNP) concentration
* **flux** – neutron flux in the channel

The governing equation solved is:

[
\frac{\partial C(x,t)}{\partial t} = \beta , \text{flux}(x) - \lambda C(x,t) - \frac{\partial}{\partial x}(U(x,t) C(x,t))
]

Boundary conditions define inflow and outflow for the advected DNPs, while the flux shape is given by a sinusoidal function over the domain.
The time stepper iterates until steady-state convergence is reached.

The DNP concentration is then transferred to **`Squirrel_SS.i`**, which computes the **static reactivity loss** due to fuel motion.

Expected result:

```
| time           | B              | Rho_Flow       | S              |
|----------------|----------------|----------------|----------------|
|   1.048575e+03 |   7.905694e-01 |   1.217096e-03 |   4.782904e-03 |
```

🧾 **Static reactivity loss:** 121.7 pcm (steady after ~1000 s)

---

### ⚡ Transient Calculation – `channel.i`

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

---

## 📊 Results Summary

| Case              | Reactivity Insertion | Temperature Feedback | Final Power (at 10 s) | Behavior                         |
| ----------------- | -------------------- | -------------------- | --------------------- | -------------------------------- |
| 1D Channel        | +10 pcm              | ❌ No                 | 1.32× steady-state    | Power rises continuously         |
| 1D Channel (Temp) | +10 pcm              | ✅ Yes                | 1.00× steady-state    | Power stabilizes due to feedback |

---

## 🖼️ Suggested Result Figures

You can include these plots in the results section:

1. **Power vs. Time** – for both transients
   → *Plot from `power_scalar` output.*
2. **Temperature vs. Position (steady state)** – from `T` field
   → *Compare core vs. outlet region.*
3. **Reactivity Components** – show `rho_insertion`, `rho_T`, and `rho_external` evolution.

Example placeholder (insert your plot later):

```markdown
![Power Transient Comparison](results/power_transient_comparison.png)
*Figure 1: Power evolution for transients with and without temperature feedback.*
```

---

## 📂 Input File Overview

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

---

## 🧠 Notes

* Always run steady-state simulations before transients.
* Ensure correct linking of output and restart files.
* The examples are simplified but illustrate the main Squirrel–MOOSE coupling workflow.

