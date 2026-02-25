# MagnusBilling 7 + Asterisk 13 - Docker

Sistema VoIP completo para EasyPanel.

## 📋 O que está incluído

| Serviço | Descrição |
|---------|-----------|
| **Asterisk 13** | PBX VoIP - Sinalização SIP, RTP, IAX2 |
| **MagnusBilling 7** | Interface web para gerenciar o Asterisk |
| **MariaDB** | Banco de dados MySQL |
| **Apache2 + PHP** | Servidor web |
| **Supervisor** | Gerenciador de processos |

---

## 🚀 Deploy no EasyPanel

### 1. Criar novo serviço
- Tipo: **App**
- Source: **Git Repository**
- Repository: `https://github.com/joaocachorro75/magnusbilling-docker`

### 2. Configurar portas
No EasyPanel, adicionar as portas:

```
80/tcp      - HTTP
443/tcp     - HTTPS (opcional)
5060/udp    - SIP UDP
5060/tcp    - SIP TCP
5038/tcp    - AMI (Asterisk Manager)
4569/udp    - IAX2 (opcional)
10000-20000/udp - RTP (Áudio)
```

### 3. Variáveis de ambiente

```env
TZ=America/Belem
MYSQL_ROOT_PASSWORD=sua_senha_segura
MYSQL_DATABASE=mbilling
MYSQL_USER=mbilling
MYSQL_PASSWORD=sua_senha_segura
AMI_PASSWORD=sua_senha_ami
```

### 4. Volumes (Persistência)

Adicionar volumes no EasyPanel:
- `/var/lib/mysql` - Banco de dados
- `/var/log/asterisk` - Logs do Asterisk
- `/etc/asterisk` - Configurações do Asterisk
- `/var/www/html/mbilling/protected/runtime` - Runtime

### 5. Privilégios

**IMPORTANTE:** O container precisa de privilégios elevados para o Asterisk funcionar.

No EasyPanel:
- Habilitar **Privileged Mode**
- Adicionar capabilities: `NET_ADMIN`, `SYS_ADMIN`

---

## ⚠️ IMPORTANTE: Modo Host

Para **produção VoIP**, recomenda-se usar `network_mode: host` porque:

1. SIP não funciona bem com NAT do Docker
2. RTP precisa de IP real para áudio
3. Performance é melhor

No EasyPanel, se disponível, configure:
```
network_mode: host
```

E **NÃO** mapeie as portas individualmente.

---

## 🔑 Credenciais Padrão

### MagnusBilling Web
- **URL:** `http://seu-ip/`
- **Usuário:** `root`
- **Senha:** `magnus`

### MySQL
- **Host:** `localhost`
- **Banco:** `mbilling`
- **Usuário:** `mbilling`
- **Senha:** (definida na env `MYSQL_PASSWORD`)

### Asterisk AMI
- **Porta:** `5038`
- **Usuário:** `magnus`
- **Senha:** (definida na env `AMI_PASSWORD`)

---

## 📞 Portas e Protocolos

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 80 | TCP | Interface web |
| 443 | TCP | HTTPS (opcional) |
| 5060 | UDP | SIP (sinalização) |
| 5060 | TCP | SIP sobre TCP |
| 5038 | TCP | AMI (Manager Interface) |
| 4569 | UDP | IAX2 (inter-Asterisk) |
| 10000-20000 | UDP | RTP (áudio das chamadas) |

---

## 🛠️ Comandos Úteis

### Entrar no container
```bash
docker exec -it magnusbilling bash
```

### Ver status do Asterisk
```bash
docker exec -it magnusbilling asterisk -rx "core show status"
```

### Ver peers SIP registrados
```bash
docker exec -it magnusbilling asterisk -rx "sip show peers"
```

### Reiniciar Asterisk
```bash
docker exec -it magnusbilling asterisk -rx "core restart now"
```

### Ver logs do Asterisk
```bash
docker exec -it magnusbilling tail -f /var/log/asterisk/messages
```

### Conectar no MySQL
```bash
docker exec -it magnusbilling mysql -u mbilling -p
```

---

## 📁 Estrutura de Arquivos

```
/var/www/html/mbilling/     # MagnusBilling
/etc/asterisk/              # Configurações Asterisk
/var/log/asterisk/          # Logs Asterisk
/var/spool/asterisk/        # Gravações, voicemail
/var/lib/mysql/             # Banco de dados
```

---

## 🔧 Configuração SIP

O arquivo `/etc/asterisk/sip.conf` é gerado automaticamente.

Para adicionar troncos/ramais, use a interface do MagnusBilling.

---

## 🐛 Troubleshooting

### Asterisk não inicia
```bash
# Verificar permissões
docker exec -it magnusbilling chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk

# Verificar configuração
docker exec -it magnusbilling asterisk -c
```

### Sem áudio nas chamadas
- Verificar se portas RTP (10000-20000/udp) estão abertas
- Verificar firewall
- Considerar usar `network_mode: host`

### MySQL não conecta
```bash
# Verificar se MariaDB está rodando
docker exec -it magnusbilling service mariadb status

# Iniciar manualmente
docker exec -it magnusbilling service mariadb start
```

---

## 📚 Documentação

- [MagnusBilling Docs](https://magnusbilling.org)
- [Asterisk Wiki](https://wiki.asterisk.org)
- [YouTube - MagnusBilling](https://www.youtube.com/channel/UCish_6Lxfkh29n4CLVEd90Q)

---

## 📝 Notas

1. **Backup:** Sempre faça backup do banco e configurações antes de atualizar
2. **Segurança:** Altere todas as senhas padrão
3. **Firewall:** Configure fail2ban (já incluído)
4. **SSL:** Configure HTTPS para produção

---

Criado para To-Ligado.com
