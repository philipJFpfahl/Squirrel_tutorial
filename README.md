# Squirrel Tutorial

To download Squirrel, for the theory and an explanation of the kernels see the Squirrel github: https://github.com/philipJFpfahl/Squirrel
These inputs where part of a DTU university course.
Author: Philip Pfahl
Contact: Philip.j.f.pfahl@gmail.com

In this tutorial the basic application of Squirrel is shown with an simplified 1D channel setup.
The 1D channel folder contains all the nessesary inputs to use Squirrel, neglecting temperature effects. The 1D channel temp folder contains the same inputs with themperature feedback.
This tutorial shows how to calculate a steady state solution of a Molten Salt Reactor with flowing fuel and how to run a transients from the steady state output. 

## Model
The model consits of two areas. One critical area (the core) and a non critical area (outside of the core).

```
[Mesh]
    #generate active core region and out of core region
    [cmbn]
        type = CartesianMeshGenerator
        dim = 1
        dx = '${fparse L/2} ${fparse L/2}'
        ix = '${nx} ${nx}'
        subdomain_id = '1 0'
      []
[]
```


## 1D channel
This folder contains four input files. The two input files with the subscript \_SS are for steady state calculations and are used as inputs for the transient simulation.


## 1D channel temp
