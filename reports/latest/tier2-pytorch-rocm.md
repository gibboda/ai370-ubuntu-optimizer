# Tier 2 PyTorch ROCm Status

Profile: ai370 | Mode: safe | Offline: false
Status: PASS

- PyTorch: available
- ROCm runtime: visible
- torch.version.hip: true
- Install action: pip-install-rocm

```text
Looking in indexes: https://download.pytorch.org/whl/nightly/rocm6.4
Requirement already satisfied: torch in ./.ai370-ai/venv/lib/python3.14/site-packages (2.10.0.dev20251031+rocm6.4)
Requirement already satisfied: torchvision in ./.ai370-ai/venv/lib/python3.14/site-packages (0.25.0.dev20251113+rocm6.4)
Requirement already satisfied: torchaudio in ./.ai370-ai/venv/lib/python3.14/site-packages (2.10.0.dev20251113+rocm6.4)
Requirement already satisfied: filelock in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (3.29.3)
Requirement already satisfied: typing-extensions>=4.10.0 in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (4.15.0)
Requirement already satisfied: setuptools in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (70.2.0)
Requirement already satisfied: sympy>=1.13.3 in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (1.14.0)
Requirement already satisfied: networkx>=2.5.1 in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (3.6.1)
Requirement already satisfied: jinja2 in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (3.1.6)
Requirement already satisfied: fsspec>=0.8.5 in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (2026.4.0)
Requirement already satisfied: pytorch-triton-rocm==3.5.0+git7416ffcb in ./.ai370-ai/venv/lib/python3.14/site-packages (from torch) (3.5.0+git7416ffcb)
Requirement already satisfied: numpy in ./.ai370-ai/venv/lib/python3.14/site-packages (from torchvision) (2.5.1)
Requirement already satisfied: pillow!=8.3.*,>=5.3.0 in ./.ai370-ai/venv/lib/python3.14/site-packages (from torchvision) (12.2.0)
Requirement already satisfied: mpmath<1.4,>=1.1.0 in ./.ai370-ai/venv/lib/python3.14/site-packages (from sympy>=1.13.3->torch) (1.3.0)
Requirement already satisfied: MarkupSafe>=2.0 in ./.ai370-ai/venv/lib/python3.14/site-packages (from jinja2->torch) (3.0.3)
Using pre-release PyTorch wheels from https://download.pytorch.org/whl/nightly/rocm6.4 because PYTORCH_ENABLE_PRE=auto. Removed cached PyTorch package wheels before install to avoid stale companion wheels. 
```
