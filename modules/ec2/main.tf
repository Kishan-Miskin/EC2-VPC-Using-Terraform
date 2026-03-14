locals {
  resolved_ami = var.ami_id != null ? var.ami_id : "ami-0b6c6ebed2801a5cb"
}

resource "aws_instance" "this" {
  ami                    = local.resolved_ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = { Name = "${var.project_name}-root-vol" }
  }

  user_data = <<-USERDATA
#!/bin/bash
exec > /var/log/user-data.log 2>&1
yum update -y
yum install -y httpd python3
systemctl start httpd
systemctl enable httpd

PROJECT="${var.project_name}"

# Write HTML using Python to avoid all heredoc issues
python3 - << 'PYHTML'
import os
project = os.environ.get('PROJECT', 'MyProject')
html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>""" + project + """</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #0a0a0f; color: #ccc; font-family: sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
  .card { background: #111118; border: 1px solid #222; border-radius: 16px; padding: 48px 40px; max-width: 560px; width: 90%; text-align: center; }
  h1 { color: #7c3aed; font-size: 2rem; margin-bottom: 8px; }
  p { color: #666; font-size: 0.9rem; margin-bottom: 32px; }
  .grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 12px; margin-bottom: 24px; }
  .stat { background: #0d0d14; border: 1px solid #1e1e2e; border-radius: 10px; padding: 14px 8px; }
  .lbl { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: #444; margin-bottom: 6px; }
  .val { font-size: 0.85rem; font-weight: 600; color: #a78bfa; }
  .val.w { color: #ccc; }
  .dot { display: inline-block; width: 7px; height: 7px; background: #4ade80; border-radius: 50%; margin-right: 4px; }
  .footer { font-size: 0.7rem; color: #333; }
</style>
</head>
<body>
<div class="card">
  <h1>""" + project + """</h1>
  <p>Running on AWS EC2 &mdash; Provisioned with Terraform</p>
  <div class="grid">
    <div class="stat"><div class="lbl">Status</div><div class="val w"><span class="dot"></span>Online</div></div>
    <div class="stat"><div class="lbl">Hostname</div><div class="val" id="hn">…</div></div>
    <div class="stat"><div class="lbl">CPU</div><div class="val" id="cpu">…</div></div>
    <div class="stat"><div class="lbl">Memory</div><div class="val" id="mem">…</div></div>
    <div class="stat"><div class="lbl">Disk</div><div class="val" id="disk">…</div></div>
    <div class="stat"><div class="lbl">Uptime</div><div class="val w" id="up">…</div></div>
  </div>
  <div class="footer">Managed by Terraform &bull; """ + project + """</div>
</div>
<script>
async function go(){
  try{
    const d=await(await fetch('/metrics')).json();
    if(d.hostname) document.getElementById('hn').textContent=d.hostname;
    if(d.cpu)      document.getElementById('cpu').textContent=d.cpu.used.toFixed(1)+'%';
    if(d.mem)      document.getElementById('mem').textContent=d.mem.used_pct.toFixed(1)+'%';
    if(d.mounts&&d.mounts[0]) document.getElementById('disk').textContent=d.mounts[0].use_pct.toFixed(0)+'%';
    if(d.sys)      document.getElementById('up').textContent=d.sys.uptime;
  }catch(e){}
  setTimeout(go,5000);
}
go();
</script>
</body>
</html>"""
with open('/var/www/html/index.html', 'w') as f:
    f.write(html)
PYHTML

# ── Metrics API ──────────────────────────────────────────────────
cat > /usr/local/bin/metrics_server.py << 'PY'
#!/usr/bin/env python3
import http.server,json,os,re,socket,time,subprocess
def read(p):
    try:
        with open(p) as f: return f.read()
    except: return ''
def meminfo():
    d={}
    for l in read('/proc/meminfo').splitlines():
        k,v=l.split(':');d[k.strip()]=int(v.strip().split()[0])
    tot=d.get('MemTotal',1);av=d.get('MemAvailable',d.get('MemFree',0));used=tot-av
    return{'used_pct':used/tot*100,'total_mb':tot/1024,'used_mb':used/1024,'avail_mb':av/1024,
           'cached_mb':(d.get('Cached',0)+d.get('SReclaimable',0))/1024,'buffers_mb':d.get('Buffers',0)/1024,
           'swap_total_mb':d.get('SwapTotal',0)/1024,'swap_used_mb':(d.get('SwapTotal',0)-d.get('SwapFree',0))/1024}
_p={}
def cpu():
    ls=[l for l in read('/proc/stat').splitlines() if l.startswith('cpu')]
    pl=lambda l:[int(x) for x in l.split()[1:]]
    ov=pl(ls[0]);co=[pl(l) for l in ls[1:] if l.startswith('cpu')]
    def pc(p,c):
        dp=[a-b for a,b in zip(c,p)];t=sum(dp);idle=dp[3]+(dp[4] if len(dp)>4 else 0);u=t-idle
        return{'used':u/t*100 if t else 0,'user':dp[0]/t*100 if t else 0,'sys':dp[2]/t*100 if t else 0,
               'idle':idle/t*100 if t else 100,'iowait':dp[4]/t*100 if len(dp)>4 and t else 0},u/t*100 if t else 0
    po=_p.get('o',ov);pc2=_p.get('c',co);_p['o']=ov;_p['c']=co
    info,_=pc(po,ov)
    return info,[round(pc(p,c)[1],1) for p,c in zip(pc2,co)]
def mounts():
    out=[];seen=set()
    skip={'tmpfs','devtmpfs','sysfs','proc','cgroup','cgroup2','pstore','debugfs','configfs','securityfs','autofs','mqueue','hugetlbfs','bpf','tracefs'}
    for l in read('/proc/mounts').splitlines():
        p=l.split()
        if len(p)<3:continue
        mnt,fs=p[1],p[2]
        if fs in skip and mnt not in('/','/boot'):continue
        if mnt in seen:continue
        seen.add(mnt)
        try:
            s=os.statvfs(mnt);tot=s.f_blocks*s.f_frsize;free=s.f_bavail*s.f_frsize;used=tot-s.f_bfree*s.f_frsize
            h=lambda b:f'{b/1048576:.1f}MB' if b<1073741824 else f'{b/1073741824:.2f}GB'
            out.append({'mount':mnt,'fs':fs,'size':h(tot),'used':h(used),'avail':h(free),'use_pct':round(used/tot*100 if tot else 0,1)})
        except:pass
    return out
def sysinfo():
    up=float(read('/proc/uptime').split()[0]);d,r=divmod(int(up),86400);h,r=divmod(r,3600)
    osn=next((l.split('=',1)[1].strip('"') for l in read('/etc/os-release').splitlines() if l.startswith('PRETTY_NAME=')),'')
    return{'uptime':(f'{d}d ' if d else '')+f'{h:02d}h {r//60:02d}m',
           'load':' / '.join(read('/proc/loadavg').split()[:3]),
           'procs':len([p for p in os.listdir('/proc') if p.isdigit()]),
           'kernel':os.uname().release,'arch':os.uname().machine,'os':osn}
def net():
    out=[]
    for l in read('/proc/net/dev').splitlines()[2:]:
        p=l.split();i=p[0].rstrip(':')
        if i=='lo':continue
        ip=''
        try:
            m=re.search(r'inet (\S+)',subprocess.check_output(['ip','addr','show',i],text=True))
            if m:ip=m.group(1).split('/')[0]
        except:pass
        out.append({'iface':i,'rx_bytes':int(p[1]),'tx_bytes':int(p[9]),'ip':ip})
    return out
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path=='/metrics':
            ci,co=cpu()
            data=json.dumps({'hostname':socket.gethostname(),'cpu':ci,'cores':co,
                             'mem':meminfo(),'mounts':mounts(),'net':net(),'sys':sysinfo()})
            self.send_response(200);self.send_header('Content-Type','application/json')
            self.send_header('Access-Control-Allow-Origin','*');self.end_headers()
            self.wfile.write(data.encode())
        else:
            self.send_response(404);self.end_headers()
    def log_message(self,*a):pass
if __name__=='__main__':
    read('/proc/stat');time.sleep(0.4);cpu()
    http.server.HTTPServer(('',8080),H).serve_forever()
PY

chmod +x /usr/local/bin/metrics_server.py

cat >> /etc/httpd/conf/httpd.conf << 'APACHE'
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
ProxyPass /metrics http://127.0.0.1:8080/metrics
ProxyPassReverse /metrics http://127.0.0.1:8080/metrics
APACHE

cat > /etc/systemd/system/metrics.service << 'SVC'
[Unit]
Description=Metrics API
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/metrics_server.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable --now metrics
systemctl restart httpd
USERDATA

  tags = { Name = "${var.project_name}-ec2" }
}