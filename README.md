# htbscan

adaptive nmap scanner that escalates through increasingly aggressive scan techniques until it finds open ports. built for htb and ctf environments where you just want to find what's open without babysitting nmap.

fair warning — i whipped this up with AI because i got tired of manually re-running nmap with different flags every time a box was being difficult. it works, i use it, but **do not blindly run this on an actual pentest.** on real engagements you need to understand what you're sending and why. automated scanning without thought is how you get caught, miss things, or knock over a production server.

## how it works

runs 5 stages, bailing out as soon as it finds open ports:

1. syn scan top 1000 ports
2. syn scan top 10000 ports
3. syn scan all 65535 ports (aggressive rate)
4. syn scan all 65535 ports (slow, for rate-limited/firewalled targets)
5. udp top 100 ports (always runs)

auto-detects icmp blocking and sets `-Pn`. runs version/script detection on anything it finds. all nmap output saved to the output directory.

## usage

```
chmod +x htbscan.sh
./htbscan.sh <ip> [outdir]
```

outdir defaults to `nmap/` if you don't specify one.

```
./htbscan.sh 10.129.244.220
./htbscan.sh 10.129.244.220 nmap/initial
./htbscan.sh -h
```

requires `sudo` for syn/udp scans.

## author

[@jkonpc](https://github.com/jkonpc)
