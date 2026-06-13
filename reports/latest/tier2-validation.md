# Tier 2 AI Runtime Validation

Profile: ai370 | Mode: safe | Offline: false
Status: WARN

## Acceptance
- Ollama: missing
- llama.cpp: missing (binary: n/a)
- GGUF models staged: 0
- PyTorch: available (ROCm: false)
- HF cache ready: available
- Open WebUI (opt): missing
- Local inference smoke: pass

Next: Run `./ai370-optimize.sh tier2-validate` (when implemented) or ensure this JSON has status PASS/WARN before Tier 5.
See reports/latest/llm-validation.json for detailed legacy LLM visibility.
