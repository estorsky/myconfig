#!/bin/bash

DIR=$(dirname $(readlink -e $0))

RED='\e[0;91m'
GREEN='\e[0;92m'
BLUE='\e[0;94m'
WHITE='\e[0;97m'

[ "$(ls -A ~/dotfiles_old)" ] \
    && echo -e "${GREEN}backup to ~/dotfiles_old${WHITE}" || \
    rm -r ~/dotfiles_old

#backup
echo -n -e "${RED}"
mkdir ~/dotfiles_old
mv ~/.vimrc                         ~/dotfiles_old/
mv ~/.config/nvim/init.vim          ~/dotfiles_old/
mv ~/.mybashrc.sh                   ~/dotfiles_old/
mv ~/.tmux.conf                     ~/dotfiles_old/
mv ~/.git-prompt.sh                 ~/dotfiles_old/
mv ~/.config/albert/albert.conf     ~/dotfiles_old/
mv ~/.config/feh/themes             ~/dotfiles_old/
mv ~/.config/i3/config              ~/dotfiles_old/
mv ~/.config/kitty/kitty.conf       ~/dotfiles_old/
mv ~/.config/dunst/dunstrc          ~/dotfiles_old/
mv ~/.config/ranger/rc.conf         ~/dotfiles_old/


#VIM
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo -n -e "${GREEN}"
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    vi +"source $DIR/vimrc" +PlugInstall +qa
    echo -n -e "${RED}"
fi
ln $DIR/vimrc ~/.vimrc

#NVIM
if ! [ -d ~/.config/nvim ]; then
    mkdir ~/.config/nvim
fi
ln $DIR/nvimrc ~/.config/nvim/init.vim

#BASH
ln $DIR/bashrc ~/.mybashrc.sh
if ! grep -Fxq "source ~/.mybashrc.sh" ~/.bashrc
then
    echo "source ~/.mybashrc.sh" >> ~/.bashrc
fi

#TMUX
ln $DIR/tmux.conf ~/.tmux.conf

#ALBERT
if ! [ -d ~/.config/albert ]; then
    mkdir ~/.config/albert
fi
ln $DIR/albert.conf ~/.config/albert/albert.conf

#FEH
if ! [ -d ~/.config/feh ]; then
    mkdir ~/.config/feh
fi
ln $DIR/feh_themes ~/.config/feh/themes

#I3
if ! [ -d ~/.config/i3 ]; then
    mkdir ~/.config/i3
fi
ln $DIR/i3 ~/.config/i3/config

#KITTY
if ! [ -d ~/.config/kitty ]; then
    mkdir ~/.config/kitty
fi
ln $DIR/kitty.conf ~/.config/kitty/kitty.conf

#DUNST
if ! [ -d ~/.config/dunst ]; then
    mkdir ~/.config/dunst
fi
ln $DIR/dunstrc ~/.config/dunst/dunstrc

#RANGER
if ! [ -d ~/.config/ranger ]; then
    mkdir ~/.config/ranger
fi
ln $DIR/ranger ~/.config/ranger/rc.conf

#GIT-PROMPT
rm -f ~/.git-prompt.sh
echo -n -e "${GREEN}"
curl -fLo ~/.git-prompt.sh \
    https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh
echo -n -e "${RED}"
# ln $DIR/git-prompt.sh ~/.git-prompt.sh

echo -e "${BLUE}done"

