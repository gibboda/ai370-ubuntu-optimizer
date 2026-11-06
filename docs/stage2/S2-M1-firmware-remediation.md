# S2-M1 firmware policy remediation (read-only)

Stage 2 firmware validation (`stage2-firmware-validate`, `scripts/20-check-bios.sh`,
`scripts/s2-m1-publish-firmware-validation.py`) consumes the canonical Stage 1 profile
(`reports/latest/s1-m5-system-profile.json`) and publishes
`s2-m1-firmware-validation.json`. **Stage 2 never flashes firmware, changes Secure Boot,
or installs microcode packages.**

## Inputs

| Input | Source | Role |
| --- | --- | --- |
| BIOS identity (version, date, vendor) | S1-M5 profile `firmware` / `system` | Facts only |
| Classified `platform_id` | S1-M5 profile `classification` | Selects policy from `configs/profiles/<platform_id>.env` |
| CLI `--profile` | Command argument | Compatibility label; **not** the BIOS policy source |
| fwupd / linux-firmware / Secure Boot | Live probes in `20-check-bios.sh` | Supplemental visibility; not flash actions |

Policy compares observed BIOS version to `EXPECTED_BIOS_VERSION` in the classified
platform `.env` when the profile has **project-verified** evidence that a specific
BIOS matters (for example `configs/profiles/ai370.env` with `2.01`). The target is
**advisory**: mismatch sets `bios_acceptable: false` and produces WARN, never FAIL.
Profiles such as `ai470` intentionally omit `EXPECTED_BIOS_VERSION`; a single Stage 1
probe observation belongs in fixtures or comments, not as an enforcement target.

Matching uses exact version-token equality (case-insensitive, optional leading `v`,
token split on whitespace and non-`.`/`_`/`-` separators). Substring matches such as
`1.00` inside `11.00` are rejected.

## Interpreting status

| Report `status` | Meaning |
| --- | --- |
| `PASS` | No policy warnings recorded |
| `WARN` | Policy or supplemental checks produced warnings; review before enablement |
| `FAIL` | Reserved for publisher/validation failures (not used for BIOS mismatch alone) |

## WARN codes and non-mutating remediation

### BIOS policy (`policy.bios_acceptable`)

| Condition | Typical cause | Operator action (manual, outside Stage 2) |
| --- | --- | --- |
| `false` | Observed BIOS ≠ classified-platform `EXPECTED_BIOS_VERSION` | Update BIOS from the OEM or Minisforum support page for your model. Re-run `stage1` then `stage2-firmware-validate`. Do **not** expect this toolkit to flash firmware. |
| `unknown` | Missing observed BIOS or no expected target for the classified platform | Ensure `stage1` collected firmware facts. For reference AI370, confirm DMI is readable. Generic hosts may legitimately have no BIOS target. |

Warning text example: `Observed BIOS X does not match classified-platform target Y.`

### Supplemental live checks (`facts` / compatibility JSON)

| Signal | WARN when | Remediation |
| --- | --- | --- |
| `fwupd.status: missing` | `fwupdmgr` not installed | Optional: `sudo apt install fwupd` and reboot if you use LVFS updates manually. Stage 2 does not invoke flashing. |
| `fwupd.devices_visible: false` | fwupd present but no devices listed | Check OEM firmware channel; verify USB/AC during OEM updates. |
| `linux_firmware.firmware_root_present: false` | `/lib/firmware` missing | Install `linux-firmware` with the distribution package manager. |
| `secure_boot.state: enabled` | Modules blocked by policy | Adjust firmware Secure Boot policy or enroll signing keys per Ubuntu/AMD guidance before expecting `amdgpu` / NPU modules. |
| `microcode.packages` empty | CPU microcode packages not reported | Install distribution `amd64-microcode` / `intel-microcode` if applicable; reboot. |

## Strict reference-platform mode

`AI370_STAGE1_STRICT` / `--strict` on platform validation is **reference-platform**
opt-in (AI370 gfx1150 / XDNA2 expectations). It is not generic-host policy. Firmware
remediation for strict GPU/NPU gates is documented under S2-M7 in `docs/ROADMAP.md`.

## Commands (read-only)

```bash
./ai370-optimize.sh stage1
./ai370-optimize.sh stage2-firmware-validate
```

Inspect `reports/latest/s2-m1-firmware-validation.json` and the paired Markdown under
`reports/latest/tier1-firmware*.md` (compatibility until R1).

## Related artifacts

- Schema: `configs/schemas/s2-m1-firmware-validation.schema.json`
- Policy library: `scripts/lib/firmware_policy.py`
- Tests: `tests/test_s2_m1_firmware.py`
