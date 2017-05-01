#!/bin/bash

if [ "$( uname )" == "Darwin" ];
then
    IS_MACOS=true
fi

VIM_DIR="${HOME}/.vim"
VIMRC="${HOME}/.vimrc"
GITCONFIG="${HOME}/.gitconfig"

if [ "${IS_MACOS}" == "true" ];
then
    FONTS_DIR="${HOME}/Library/Fonts"
    BASH_PROFILE="${HOME}/.bash_profile"
else
    FONTS_DIR="${HOME}/.fonts"
    BASH_PROFILE="${HOME}/.bashrc"
fi

function get_extension
{
    local fullname="${1}"
    local filename="${fullname##*/}"
    local extension="${filename##*.}"
    echo "${extension}" | tr '[:upper:]' '[:lower:]'
}


function strip_extension
{
    local name="${1}"
    echo "${name%.*}"
}


function make_dir
{
    local folder="$1"
    if [ ! -d "${folder}" ]
    then
        mkdir -p "${folder}"
    fi
}


function git_clone
{
    local remote="${1}"
    local clone_dir="${2:-${CLONE_DIR}}"
    local branch_or_tag="${3}"
    local current="$( pwd )"

    make_dir "${clone_dir}"

    # human repo name
    local repo="$(  basename "${remote}" )"

    # clone absolute path
    clone="${clone_dir}/${repo}"
    if [ -d "${clone}" ]
    then
        echo "Repository '${repo}' already cloned. Updating from upstream..."
        ( cd "${clone}" && git pull --rebase && git submodule update --init --recursive --force )
    else
        if [ -n "${branch_or_tag}" ]
        then
            git clone --recursive --branch "${branch_or_tag}" "${remote}" "${clone}"
        else
            git clone --recursive "${remote}" "${clone}"
        fi
    fi
}


function ubuntu_install {
    sudo apt-get update
    sudo apt-get install -y software-properties-common \
                            build-essential \
                            bash-completion \
                            cmake \
                            clang \
                            python-dev \
                            python3-dev \
                            curl \
                            htop \
                            tree \
                            rsync \
                            mercurial \
                            subversion \
                            silversearcher-ag \
                            vim-nox \
                            imagemagick \
                            openimageio-tools \
                            p7zip-full \
                            p7zip-rar

    # uptodate git
    sudo add-apt-repository ppa:git-core/ppa
    sudo apt-get update
    sudo apt-get install git

    # docker:
    sudo apt-get install -y apt-transport-https ca-certificates linux-image-extra-$(uname -r) linux-image-extra-virtual
    sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    local docker_source="deb https://apt.dockerproject.org/repo ubuntu-xenial main"
    local docker_sources="/etc/apt/sources.list.d/docker.list"
    if ! grep -q "${dockersource}" "${docker_sources}";
    then
        echo "${docker_source}" | sudo tee -a "${docker_sources}"
    fi
    sudo apt-get update
    sudo apt-get install -y docker-engine
    sudo service docker start

    # slow down on brute force ssh (see http://askubuntu.com/a/32256/212079)
    sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j LOG --log-prefix "SSH_brute_force "
    sudo iptables -A INPUT -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP

    git_completion
    docker_completion
}


function homebrew_packages_install
{
    declare -a packages=("${!1}")
    for package in "${packages[@]}"
    do
        if ! brew list "${package}" 1>/dev/null
        then
            brew install "${package}"
        else
            brew upgrade "${package}"
        fi
    done
}


function homebrew_install
{
    # install homebrew and some utils
    if ! brew --version 2>/dev/null
    then
        ruby -e "$( curl -fsSkL raw.github.com/mxcl/homebrew/go )"
    fi
    brew update
    brew doctor

    local code_packages=( git readline cmake valgrind libyaml htop-osx )
    local compression_packages=( p7zip )
    local db_packages=( sqlite )
    local font_packages=( fontconfig freetype )
    local image_packages=( imagemagick ffmpeg jpeg libpng libtiff )
    local network_packages=( wget ack ag openssl )

    homebrew_packages_install network_packages[@]
    homebrew_packages_install compression_packages[@]
    homebrew_packages_install image_packages[@]
    homebrew_packages_install db_packages[@]
    homebrew_packages_install font_packages[@]
    homebrew_packages_install code_packages[@]

    brew doctor
}

function python_packages_install
{
    local -a packages=( "${!1}" )
    for package in "${packages[@]}"
    do
        pip install "${package}"
    done
}


function python_install
{
    # set up a default virtualenv (installed by homebrew)
    easy_install --upgrade pip

    # install extra packages
    local scientific_packages=( numpy scipy scikit-learn matplotlib networkx pandas nltk )
    local ipython_packages=( readline ipython )
    local web_packages=( beautifulsoup requests )
    local linter_packages=( flake8 pyflakes pylint )
    local other_packages=( awscli argparse nose python-dateutil pycrypto )

    python_packages_install scientific_packages[@]
    python_packages_install ipython_packages[@]
    python_packages_install web_packages[@]
    python_packages_install linter_packages[@]
    python_packages_install other_packages[@]
}


function vim_install
{
    # requires vim 7.4.615+ (see https://github.com/Shougo/unite.vim/issues/798)
    # Use e.g. `[sudo] add-apt-repository ppa:pi-rho/dev`

    local vundle="${VIM_DIR}/bundle/Vundle.vim"
    if [ ! -d "${vundle}" ]
    then
        git clone "https://github.com/VundleVim/Vundle.vim.git" "${vundle}"
    fi
    vim +VundleClean +VundleInstall +qall  # install all plugins from vimrc

    local vimproc="${VIM_DIR}/bundle/vimproc.vim"
    if [ -d "${vimproc}" ]
    then
        ( cd "${vimproc}" && make )
    fi

    local ycm="${VIM_DIR}/bundle/YouCompleteMe"
    if [ -d "${ycm}" ]
    then
        ( cd "${ycm}" && ./install.py --clang-completer )
        ln -s vim/ycm_extra_conf.py ${HOME}/.vim/ycm_extra_conf.py
        pip install jedi  # python autocompletion
    fi
}


function fonts_install {
    mkdir -p "${FONTS_DIR}"
    sudo cp "fonts/Anonymice Powerline.ttf" "${FONTS_DIR}"
    fc-cache -f -v
}


function git_completion
{
    # fetch git-completion.bash
    curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > "${HOME}/.git-completion.bash"
}


function docker_completion
{
    # fetch docker-completion.bash
    curl https://raw.githubusercontent.com/docker/docker/master/contrib/completion/bash/docker > "${HOME}/.docker-completion.bash"
}


###############
# 1. distribute configuration files
###############
# sets medium font anti-aliasing
## see: http://osxdaily.com/2012/06/09/mac-screen-blurry-optimize-troubleshoot-font-smoothing-os-x/
if [ "${IS_MACOS}" == "true" ];
then
    defaults -currentHost write -globalDomain AppleFontSmoothing -int 2
fi

# create soft links for all config files
current_directory="$( pwd )"
## git
ln -fs "${current_directory}/git/gitconfig"         "${GITCONFIG}"
## terminal
ln -fs "${current_directory}/terminal/agignore"     "${HOME}/.agignore"
ln -fs "${current_directory}/terminal/bash_profile" "${BASH_PROFILE}"
ln -fs "${current_directory}/terminal/gdbinit"      "${HOME}/.gdbinit"
ln -fs "${current_directory}/terminal/inputrc"      "${HOME}/.inputrc"
ln -fs "${current_directory}/terminal/screenrc"     "${HOME}/.screenrc"
## vim
ln -fs "${current_directory}/vim/vimrc"             "${VIMRC}"

source "${BASH_PROFILE}"

###############
# 2. install required components if needed
###############
# parse command line arguments
while [ $# -ge 1 ] ; do
    case $1 in
        --all)
            if [ "${IS_MACOS}" == "true" ];
            then
                homebrew_install
                # terminal theme needs to be 'default'ed manually
                open "${current_directory}/terminal/wombat.terminal"
            else
                ubuntu_install
                gconftool-2 --load terminal/gnome-profile.terminal
                # http://stackoverflow.com/questions/31097684/ctrl-v-mapped-to-paste-instead-block-visual-mode-in-vim-on-elementary-os-linux
                if "$( lsb_release -si )" = "elementary";
                then
                    dconf write /org/pantheon/terminal/settings/natural-copy-paste false
                fi
            fi

            fonts_install
            git_completion
            python_install
            vim_install

            shift 1 ;;  # drop current command line arg
        --fonts)
            fonts_install
            shift 1 ;;
        --git)
            git_completion
            shift 1 ;;
        --homebrew)
            homebrew_install
            shift 1 ;;
        --python)
            python_install
            shift 1 ;;
        --vim)
            vim_install
            shift 1 ;;
        --ubuntu)
            ubuntu_install
            shift 1 ;;
        --help)
            echo "Usage: $0 [--all|--fonts|--ubuntu|--homebrew|--vim|--python|--git|--help]"
            shift 1 ;;
    esac
done
