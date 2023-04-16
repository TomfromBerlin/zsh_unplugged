#
# unplugged - https://github.com/mattmc3/zsh_unplugged
#
# Simple, ultra-fast, minimalist Zsh plugin management functions.
#
# Usage:
# source ${ZDOTDIR:-~}/unplugged.zsh
# repos=(
#   zsh-users/zsh-syntax-highlighting
#   zsh-users/zsh-autosuggestions
#   zsh-users/zsh-history-substring-search
# )
# plugin-load $repos
#

# Set the plugin destination.
: ${ZPLUGINDIR:=${ZDOTDIR:-$HOME/.config/zsh}/plugins}
autoload -Uz zrecompile

##? Clone zsh plugins in parallel and ensure proper plugin init files exist.
function plugin-clone {
  emulate -L zsh; setopt local_options no_monitor
  local repo repodir

  for repo in ${(u)@}; do
    repodir=$ZPLUGINDIR/${repo:t}
    [[ ! -d $repodir ]] || continue
    echo "Cloning $repo..."
    (
      command git clone -q --depth 1 --recursive --shallow-submodules \
        ${ZPLUGIN_GITURL:-https://github.com}/$repo $repodir
      local initfile=$repodir/${repo:t}.plugin.zsh
      if [[ ! -e $initfile ]]; then
        local -a initfiles=($repodir/*.{plugin.,}{z,}sh{-theme,}(N))
        (( $#initfiles )) && ln -sf $initfiles[1] $initfile
      fi
      plugin-compile $repodir
    ) &
  done
  wait
}

##? Load zsh plugins.
function plugin-load {
  local plugin pluginfile source_cmd
  local -a repos initpaths

  # repos are in the form user/repo. They contain a slash, but don't start with one.
  repos=(${${(M)@:#*/*}:#/*})
  plugin-clone $repos
  (( $+functions[zsh-defer] )) && source_cmd=(zsh-defer .) || source_cmd=(.)

  for plugin in $@; do
    pluginfile=${plugin:t}/${plugin:t}.plugin.zsh
    initpaths=(
      $ZPLUGINDIR/${pluginfile}(N)
      ${ZDOTDIR:-$HOME/.config/zsh}/plugins/${pluginfile}(N)
      $ZSH_CUSTOM/plugins/${pluginfile}(N)
    )
    if ! (( $#initpaths )); then
      echo >&2 "Plugin not found '$plugin'."
      continue
    fi
    pluginfile=$initpaths[1]
    fpath+=($pluginfile:h)
    $source_cmd $pluginfile
  done
}

##? Update plugins
function plugin-update {
  emulate -L zsh
  setopt local_options extended_glob glob_dots no_monitor
  local repodir
  for repodir in $ZPLUGINDIR/**/.git(N/); do
    repodir=${repodir:A:h}
    local url=$(git -C $repodir config remote.origin.url)
    echo "Updating ${url:h:t}/${url:t}..."
    command git -C $repodir pull --quiet --ff --depth 1 --rebase --autostash &
  done
  wait
  plugin-compile
  echo "Update complete."
}

function plugin-compile {
  local zfile
  for zfile in ${1:-ZPLUGINDIR}/**/*.zsh{,-theme}(N); do
    [[ $zfile != */test-data/* ]] || continue
    zrecompile -pq "$zfile"
  done
}
