# Address plan

| Resource      | Location        | CIDR / address           |
|---------------|-----------------|--------------------------|
| ewb-vpc-a     | VPC A           | 10.10.0.0/16             |
| ewb-a-public  | VPC A, public   | 10.10.1.0/24             |
| ewb-a-private | VPC A, private  | 10.10.2.0/24             |
| ewb-vpc-b     | VPC B           | 10.20.0.0/16             |
| ewb-b-private | VPC B, private  | 10.20.1.0/24             |
| ewb-bastion   | ewb-a-public    | 10.10.1.10 + public IPv4 |
| ewb-app-a     | ewb-a-private   | 10.10.2.10 (no public IP)|
| ewb-app-b     | ewb-b-private   | 10.20.1.10 (no public IP)|

Other names: `ewb-igw-a`, `ewb-rt-a-public`, `ewb-rt-a-private`,
`ewb-rt-b-private`, `ewb-sg-bastion`, `ewb-sg-app-a`, `ewb-sg-app-b`,
`ewb-a-b-peer`, key pair `ewb-lab`.

## Route tables

**ewb-rt-a-public** (assoc: ewb-a-public)

| Destination  | Target | Purpose                 |
|--------------|--------|-------------------------|
| 10.10.0.0/16 | local  | Bastion to App-A        |
| 0.0.0.0/0    | igw    | Bastion internet access |
| 10.20.0.0/16 | pcx    | Bastion SSH to App-B    |

**ewb-rt-a-private** (assoc: ewb-a-private)

| Destination  | Target | Purpose        |
|--------------|--------|----------------|
| 10.10.0.0/16 | local  | VPC A          |
| 10.20.0.0/16 | pcx    | App-A to VPC B |

**ewb-rt-b-private** (assoc: ewb-b-private)

| Destination  | Target | Purpose              |
|--------------|--------|----------------------|
| 10.20.0.0/16 | local  | VPC B                |
| 10.10.0.0/16 | pcx    | Return path to VPC A |

## Security group inbound rules

| Security group | Type / port       | Source             |
|----------------|-------------------|--------------------|
| ewb-sg-bastion | SSH / TCP 22      | your public IP /32 |
| ewb-sg-app-a   | SSH / TCP 22      | 10.10.1.10/32      |
| ewb-sg-app-a   | ICMP echo request | 10.20.1.10/32      |
| ewb-sg-app-b   | SSH / TCP 22      | 10.10.1.10/32      |
| ewb-sg-app-b   | ICMP echo request | 10.10.2.10/32      |
