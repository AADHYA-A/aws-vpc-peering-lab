output "bastion_public_ip" {
  description = "Put this in ~/.ssh/config as BASTION_PUBLIC_IP."
  value       = aws_instance.bastion.public_ip
}

output "inventory" {
  description = "Record these IDs in your report."
  value = {
    vpc_a_id     = aws_vpc.a.id
    vpc_b_id     = aws_vpc.b.id
    peering_id   = try(aws_vpc_peering_connection.a_b[0].id, "peering disabled")
    igw_id       = aws_internet_gateway.a.id
    bastion_id   = aws_instance.bastion.id
    app_a_id     = aws_instance.app_a.id
    app_b_id     = aws_instance.app_b.id
    app_a_public = coalesce(aws_instance.app_a.public_ip, "none")
    app_b_public = coalesce(aws_instance.app_b.public_ip, "none")
  }
}
