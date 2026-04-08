# Acestream Proxy

Acestream engine'i Docker üzerinden çalıştırarak HTTP proxy görevi gören Home Assistant addon'u.

## Kullanım

Addon çalıştıktan sonra:

```
http://<HA_IP>:6878/ace/getstream?id=<CONTENT_ID>
```

## Gereksinimler

Docker socket erişimi gereklidir. SSH üzerinden:

```bash
chmod 666 /var/run/docker.sock
```

Daha fazla bilgi için [GitHub sayfasını](https://github.com/sekertr/acestream-ha-addon) ziyaret edin.
