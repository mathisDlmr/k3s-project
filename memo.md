## Scan Réseau

```bash
nmap -sn reseau/mask
```

## Modif config réseau

```bash
sudo nano /etc/netplan/01-wifi.yaml
```

```yaml
network:
  version: 2
  renderer: networkd      

  ethernets:
    enp3s0:
      dhcp4: true

  wifis:
    wlp1s0:
      dhcp4: true
      access-points:
        "NomDuWifi":
          password: "MotDePasseWifi"
```

```bash
sudo netplan generate
sudo netplan apply
ip a
```

## TODO

* Support SFTP
