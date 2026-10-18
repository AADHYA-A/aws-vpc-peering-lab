# Test plan and evidence

Record real output for every test. Label each screenshot with host, test and result.

| # | Test | Where / command | Expected |
|---|------|-----------------|----------|
| 01 | Baseline (no peering) | App-A: `ping -c 4 10.20.1.10` | No replies |
| 02 | Forward path | App-A: `ping -c 4 10.20.1.10` | 4 replies, 0% loss |
| 03 | Reverse path | App-B: `ping -c 4 10.10.2.10` | 4 replies, 0% loss |
| 04 | Private SSH | Laptop: `ssh ewb-app-b` | Shell on App-B via bastion |
| 05 | Isolation | EC2 console | No public IPv4 on App-A / App-B |
| 06 | Controlled failure | Remove App-B ICMP rule, ping from App-A | Replies stop, then resume after restore |

Identify the host inside each private instance:

```bash
hostname
hostname -I
ping -c 4 PEER_PRIVATE_IP
```

## Running the tests with Terraform

```bash
# Baseline (test 01): no peering
terraform apply -var enable_peering=false
ssh ewb-app-a            # then: ping -c 4 10.20.1.10  -> no replies

# Connect the VPCs (tests 02-05)
terraform apply -var enable_peering=true

# Controlled failure (test 06)
terraform apply -var enable_app_b_icmp_rule=false   # ping fails
terraform apply -var enable_app_b_icmp_rule=true    # ping recovers
```

Note: `-var` on the command line overrides `terraform.tfvars`, so keep the other
toggle at its default (true) when you use these.

## Questions to be able to answer
1. Why is the return route needed?
2. Why is the App-B SSH source the bastion private IP?
3. Why does Active peering not guarantee a successful ping?
4. Can VPC B use VPC A's internet gateway over peering?
