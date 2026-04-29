# ai370-ubuntu-optimizer

Ubuntu 26.04 LTS optimization toolkit for the Minisforum EliteMini AI370 and future Ryzen AI systems.

## Primary Target

Default profile:

- Minisforum EliteMini AI370
- AMD Ryzen AI 9 HX 370 / Strix Point
- Radeon 890M integrated GPU
- AMD XDNA2 NPU
- LPDDR5X-7500 memory
- PCIe 4.0 NVMe storage
- BIOS 2.01 baseline

## Design Model

This project is profile-based.

The AI370 profile is the reference implementation, but the core engine is intentionally separated from device profiles so the project can be forked or extended later for other Ryzen AI systems.

```text
core engine + hardware audit + profile rules = safe optimization plan
```

## Execution Order

```text
1. Audit
2. Generate Profile
3. Plan
4. Install
5. Validate
```

The optimizer must never combine audit and install in one step.

## Usage

```bash
./ai370-optimize.sh audit
./ai370-optimize.sh plan --profile ai370
./ai370-optimize.sh install --profile ai370
./ai370-optimize.sh validate --profile ai370
```

## Repository Standards

This repository uses:

- Semantic Versioning
- Conventional Commits
- Gitmoji
- Keep a Changelog
- GPLv3 licensing

Commit format:

```text
<gitmoji> <type>(scope): <summary>
```

Example:

```text
✨ feat(audit): add full AI370 hardware inventory script
```

## License

This project is licensed under the GNU General Public License v3.0 only.

See [LICENSE](LICENSE) for details.
