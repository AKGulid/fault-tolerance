output "load_balancer_public_ip" {
  description = "Публичный IP-адрес сетевого балансировщика"
  value       = tolist(tolist(yandex_lb_network_load_balancer.web_nlb.listener)[0].external_address_spec)[0].address
}

output "vm_public_ips" {
  description = "Публичные IP-адреса виртуальных машин"
  value       = yandex_compute_instance.web[*].network_interface[0].nat_ip_address
}