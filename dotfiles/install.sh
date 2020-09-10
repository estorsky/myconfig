#!/bin/bash

DIR=$(dirname $(readlink -e $0))

RED='\e[0;91m'
GREEN='\e[0;92m'
BLUE='\e[0;94m'
WHITE='\e[0;97m'


#backup
echo -e "${GREEN}backup to ~/dotfiles_old${WHITE}"
echo -n -e "${RED}"
rm -rf ~/dotfiles_old
mkdir ~/dotfiles_old
mv ~/.vimrc                         ~/dotfiles_old/
mv ~/.config/nvim/init.vim          ~/dotfiles_old/
mv ~/.mybashrc.sh                   ~/dotfiles_old/
mv ~/.tmux.conf                     ~/dotfiles_old/
mv ~/.git-prompt.sh                 ~/dotfiles_old/
mv ~/.config/albert/albert.conf     ~/dotfiles_old/
mv ~/.albertignore                  ~/dotfiles_old/
mv ~/.config/feh/themes             ~/dotfiles_old/
mv ~/.config/i3/config              ~/dotfiles_old/
mv ~/.config/kitty/kitty.conf       ~/dotfiles_old/
mv ~/.config/dunst/dunstrc          ~/dotfiles_old/
mv ~/.config/ranger/rc.conf         ~/dotfiles_old/
mv ~/.zshrc                         ~/dotfiles_old/
mv ~/.ignore                        ~/dotfiles_old/
mv ~/.gitconfig                     ~/dotfiles_old/


#VIM
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo -n -e "${GREEN}"
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    vi +"source $DIR/vimrc" +PlugInstall +qa
    echo -n -e "${RED}"
fi
ln -s $DIR/vimrc ~/.vimrc

#NVIM
if ! [ -d ~/.config/nvim ]; then
    mkdir ~/.config/nvim
fi
ln -s $DIR/nvimrc ~/.config/nvim/init.vim

#BASH
ln -s $DIR/bashrc ~/.mybashrc.sh
if ! grep -Fxq "source ~/.mybashrc.sh" ~/.bashrc
then
    echo "source ~/.mybashrc.sh" >> ~/.bashrc
fi

#TMUX
ln -s $DIR/tmux.conf ~/.tmux.conf

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

go get -u github.com/arl/gitmux

#ALBERT
if ! [ -d ~/.config/albert ]; then
    mkdir ~/.config/albert
fi
ln -s $DIR/albert.conf  ~/.config/albert/albert.conf
ln -s $DIR/albertignore ~/.albertignore

#FEH
if ! [ -d ~/.config/feh ]; then
    mkdir ~/.config/feh
fi
ln -s $DIR/feh_themes ~/.config/feh/themes

#I3
if ! [ -d ~/.config/i3 ]; then
    mkdir ~/.config/i3
fi
ln -s $DIR/i3 ~/.config/i3/config

#KITTY
if ! [ -d ~/.config/kitty ]; then
    mkdir ~/.config/kitty
fi
ln -s $DIR/kitty.conf ~/.config/kitty/kitty.conf

#DUNST
if ! [ -d ~/.config/dunst ]; then
    mkdir ~/.config/dunst
fi
ln -s $DIR/dunstrc ~/.config/dunst/dunstrc

#RANGER
if ! [ -d ~/.config/ranger ]; then
    mkdir ~/.config/ranger
fi
ln -s $DIR/ranger ~/.config/ranger/rc.conf

#GIT-PROMPT
rm -f ~/.git-prompt.sh
echo -n -e "${GREEN}"
curl -fLo ~/.git-prompt.sh \
    https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh
echo -n -e "${RED}"

#ZSH
if ! [ -d ~/.oh-my-zsh ]; then
    echo -n -e "${GREEN}"
    git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
    echo -n -e "${RED}"
fi
ln -s $DIR/zshrc ~/.zshrc

#AG
ln -s $DIR/ignore ~/.ignore

#GITCONFIG
ln -s $DIR/gitconfig ~/.gitconfig


#WORK DOTFILES
if [ -d ~/work ]; then
    echo -n -e "${GREEN}"
    echo "install dotfiles for work"
    echo -n -e "${RED}"

    #DOCKER
    sudo rm -f /etc/docker/daemon.json
    sudo mkdir -p /etc/docker && sudo cp $DIR/work/daemon.json /etc/docker/

    #GITCONFIG
    rm -f ~/work/.gitconfig
    ln -s $DIR/work/gitconfig ~/work/.gitconfig
fi


echo -e "${BLUE}done"

