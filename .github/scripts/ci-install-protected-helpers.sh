#!/usr/bin/env bash
# Install root-owned portable CI helpers outside the test-writable checkout.
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
test_user="${AI370_CI_TEST_USER:-ai370ci}"
ci_root='/opt/ai370-ci'

if ! sudo -n true 2>/dev/null; then
  echo '::error::Protected CI helper install requires passwordless sudo'
  exit 1
fi

install_one() {
  local src="$1"
  local dest="$2"
  if [[ ! -f "$src" ]]; then
    echo "::error::Missing CI helper source: $src"
    exit 1
  fi
  sudo install -D -m 0755 -o root -g root "$src" "$dest"
}

sudo mkdir -p "${ci_root}/bin" "${ci_root}/helpers"
sudo chown root:root "$ci_root" "${ci_root}/bin" "${ci_root}/helpers"
sudo chmod 0755 "$ci_root" "${ci_root}/bin" "${ci_root}/helpers"

install_one "${repo_root}/.github/scripts/ci-host-drift-canary.sh" "${ci_root}/helpers/ci-host-drift-canary.sh"
install_one "${repo_root}/.github/scripts/ci-stage-reports-for-upload.sh" "${ci_root}/helpers/ci-stage-reports-for-upload.sh"
install_one "${repo_root}/.github/scripts/ci-prepare-portable-test-user.sh" "${ci_root}/helpers/ci-prepare-portable-test-user.sh"
install_one "${repo_root}/.github/scripts/ci-drop-runner-sudo.sh" "${ci_root}/helpers/ci-drop-runner-sudo.sh"

sudo tee "${ci_root}/bin/ci-as-test-user.sh" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
test_user='${test_user}'
workspace='${repo_root}'
if [[ "\$#" -lt 1 ]]; then
  echo 'usage: ci-as-test-user.sh command [args...]' >&2
  exit 2
fi
if ! id "\$test_user" >/dev/null 2>&1; then
  echo '::error::Portable test user missing; run ci-prepare-portable-test-user.sh first'
  exit 1
fi
home_dir="\$(eval echo "~\${test_user}")"
exec sudo -n -u "\$test_user" -H env \\
  AI370_CI_NO_HOST_MUTATION="\${AI370_CI_NO_HOST_MUTATION:-}" \\
  RUNNER_TEMP="\${RUNNER_TEMP:-}" \\
  HOME="\$home_dir" \\
  bash -lc "cd \"\${workspace}\" && exec \"\\\$@\"" -- "\$@"
EOF
sudo chmod 0755 "${ci_root}/bin/ci-as-test-user.sh"
sudo chown root:root "${ci_root}/bin/ci-as-test-user.sh"

config_path="${ci_root}/config"
sudo tee "$config_path" >/dev/null <<EOF
# Managed by ci-install-protected-helpers.sh; do not edit on runners.
AI370_CI_TEST_USER='${test_user}'
GITHUB_WORKSPACE='${repo_root}'
EOF
sudo chmod 0644 "$config_path"
sudo chown root:root "$config_path"

echo "Installed protected portable CI helpers under ${ci_root}"