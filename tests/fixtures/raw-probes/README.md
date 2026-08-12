# Raw Stage 1 probe fixtures

The `v1/` directory contains sanitized raw probe artifacts used by portable
system-profile tests. These fixtures intentionally cover the reference
EliteMini AI370, another Ryzen AI platform, unsupported hosts, missing tools,
unreadable probes, degraded drivers, and unrelated accelerator nodes. The
canonical S1-M1 command replays them with `--fixture` so portable tests never
depend on the executing host.
