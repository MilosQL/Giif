#### Lab requirements

- Optimally 4 servers.

- Each server should have its iDRAC and at least two 1 Gbps ports connected. 

- 10 Gbps are not strictly needed but could find its use in performance-based scenarios such as DTN. 

- One /29, or more comfortably /28, public subnet, residing on its own broadcast segment/VLAN.

- One /24 private (RFC 1918) subnet, SNAT-ed behind a public IP address. This subnet should also reside on its own exclusive broadcast domain/VLAN.

- A set of broadcast domains (i.e., VLANs) which are clear of any kind of IP configuration. The number of VLANs should roughly correspond to the number hosts supported by the public subnet.

- The ability to occasionally change the network configuration (trunks and access ports) on the networking device facing the servers. (If a standalone L2 switch is involved, this can fall on the framework operator.)

- One-time action of re-configuring iDRACs IP settings to match the new private subnet.
