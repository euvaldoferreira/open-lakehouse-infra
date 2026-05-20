#!/bin/bash
# =============================================================================
# Jupyter Container Entrypoint
# Runs as root: fixes volume permissions, then starts JupyterLab
# =============================================================================

set -e

# Fix ownership of volumes mounted in jovyan's home (created as root by Docker)
chown -R jovyan:users /home/jovyan/.local              2>/dev/null || true
chown -R jovyan:users /home/jovyan/output              2>/dev/null || true
chown -R jovyan:users /home/jovyan/work/pipelines      2>/dev/null || true
chown -R jovyan:users /home/jovyan/work/exploratory    2>/dev/null || true

# ---------------------------------------------------------------------------
# Git configuration for jovyan (GitHub integration)
# Vars injected by docker-compose: GIT_USER_NAME, GIT_USER_EMAIL, GITHUB_TOKEN
# ---------------------------------------------------------------------------
JOVYAN_GITCONFIG=/home/jovyan/.gitconfig
JOVYAN_GITATTRIBUTES=/home/jovyan/.config/git/attributes

if [ -n "${GIT_USER_NAME}" ]; then
    git config --file "$JOVYAN_GITCONFIG" user.name "${GIT_USER_NAME}"
fi
if [ -n "${GIT_USER_EMAIL}" ]; then
    git config --file "$JOVYAN_GITCONFIG" user.email "${GIT_USER_EMAIL}"
fi

# nbstripout: global filter strips cell outputs before every commit
git config --file "$JOVYAN_GITCONFIG" filter.nbstripout.clean    'nbstripout'
git config --file "$JOVYAN_GITCONFIG" filter.nbstripout.smudge   cat
git config --file "$JOVYAN_GITCONFIG" filter.nbstripout.required true
git config --file "$JOVYAN_GITCONFIG" diff.ipynb.textconv        'nbstripout -t'
mkdir -p "$(dirname "$JOVYAN_GITATTRIBUTES")"
grep -qxF '*.ipynb filter=nbstripout diff=ipynb' "$JOVYAN_GITATTRIBUTES" 2>/dev/null \
    || echo '*.ipynb filter=nbstripout diff=ipynb' >> "$JOVYAN_GITATTRIBUTES"

# GitHub token: HTTPS auth via credential store (token never reaches notebook code)
if [ -n "${GITHUB_TOKEN}" ]; then
    git config --file "$JOVYAN_GITCONFIG" credential.helper store
    printf 'https://%s:%s@github.com\n' "${GIT_USER_NAME:-x-token}" "${GITHUB_TOKEN}" \
        > /home/jovyan/.git-credentials
    chmod 600 /home/jovyan/.git-credentials
fi

chown -R jovyan:users "$JOVYAN_GITCONFIG" /home/jovyan/.config/git 2>/dev/null || true
[ -f /home/jovyan/.git-credentials ] && chown jovyan:users /home/jovyan/.git-credentials 2>/dev/null || true

# Hand off to the original JupyterLab startup (drops to jovyan internally)
exec start-notebook.sh "$@"
