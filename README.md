# Network Theory Resilience Metric (NTRM)
The Network Theory Resilience Metric (NTRM) samples cascade scenarios from 
a MATPOWER case file, then runs the AC Cascading Failure Model (AC-CFM) code,
for all the resulting cases. Then, a set of network science metrics for the
network under study are derived, using MATLAB and BCT functions. The following
parameters are calculated:

- Degree centrality of each node (bus)
- Eigenvecor centrality of each node (bus)
- Betweenness centrality of each node (bus)
- Closeness centrality of each node (bus)
- Clustering coefficient of each node (bus)
- Self-admittance of each bus
- Edge betweenness centrality for each edge (branch)
- [Degree of node(i) * Degree of node(j)] for each edge (branch)
- Total load shedding each branch causes in all scenarios
- Total amount of times each branch contributed to a cascade

# Prerequisites:
- Matlab R2020b or later (but may work with earlier versions)
- Matpower 7.1 or later
    https://matpower.org/, or https://github.com/MATPOWER/matpower
- AC-CFM and its prerequisites
    https://github.com/mnoebels/AC-CFM, Reference: Noebels, M.,
    Preece, R., Panteli, M. "AC Cascading Failure Model for
    Resilience Analysis in Power Networks." IEEE Systems Journal (2020).
- Brain Connectivity Toolbox (BCT)
    https://sites.google.com/site/bctnet/home, Reference: Rubinov M,
    Sporns O, "Complex network measures of brain connectivity:
    Uses and interpretations", (2010) NeuroImage 52:1059-69.

# Usage
```
ntrm('MATPOWER case file name', [sample size])
```

e.g.  results = ntrm('case39', 500)

# Acknowledgements
The authors would like to thank Mathaios Panteli for valuable discussions
and support. This work was supported by the Engineering and Physical
Sciences Research Council [EP/W034204/1]
