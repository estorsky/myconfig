#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -e $0))

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
mv ~/.vim/coc-settings.json         ~/dotfiles_old/
mv ~/.config/nvim/coc-settings.json ~/dotfiles_old/
mv ~/.vim/spell/ru.utf-8.add        ~/dotfiles_old/
mv ~/.mybashrc.sh                   ~/dotfiles_old/
mv ~/.git-prompt.sh                 ~/dotfiles_old/
mv ~/.tmux.conf                     ~/dotfiles_old/
# mv ~/.config/albert/albert.conf     ~/dotfiles_old/
# mv ~/.albertignore                  ~/dotfiles_old/
mv ~/.config/rofi/config.rasi       ~/dotfiles_old/
mv ~/.config/feh/themes             ~/dotfiles_old/
mv ~/.config/i3/config              ~/dotfiles_old/
mv ~/.config/sway/config            ~/dotfiles_old/
mv ~/.config/waybar/config          ~/dotfiles_old/
mv ~/.config/waybar/style.css       ~/dotfiles_old/
mv ~/.config/kitty/kitty.conf       ~/dotfiles_old/
mv ~/.config/dunst/dunstrc          ~/dotfiles_old/
mv ~/.config/ranger/rc.conf         ~/dotfiles_old/
mv ~/.zshrc                         ~/dotfiles_old/
mv ~/.ignore                        ~/dotfiles_old/
mv ~/.gitconfig                     ~/dotfiles_old/
mv ~/.config/autorandr              ~/dotfiles_old/

#CREATE DIRS
mkdir -p ~/remote

#VIM
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo -n -e "${GREEN}"
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    vim +"source $SCRIPT_DIR/vim/vimrc" +PlugInstall +qa
    echo -n -e "${RED}"
fi
ln -s "$SCRIPT_DIR/vim/vimrc" ~/.vimrc
mkdir -p ~/.vim/spell
ln -s "$SCRIPT_DIR/vim/vim_spell_dict" ~/.vim/spell/ru.utf-8.add
ln -s "$SCRIPT_DIR/vim/coc-settings.json" ~/.vim/coc-settings.json

#NVIM
if ! [ -d ~/.config/nvim ]; then
    mkdir ~/.config/nvim
fi
ln -s "$SCRIPT_DIR/vim/nvimrc" ~/.config/nvim/init.vim
ln -s "$SCRIPT_DIR/vim/coc-settings.json" ~/.config/nvim/coc-settings.json

#BASH
ln -s "$SCRIPT_DIR/bashrc" ~/.mybashrc.sh
if ! grep -Fxq "source ~/.mybashrc.sh" ~/.bashrc
then
    echo "source ~/.mybashrc.sh" >> ~/.bashrc
fi

#GIT-PROMPT
rm -f ~/.git-prompt.sh
echo -n -e "${GREEN}"
curl -fLo ~/.git-prompt.sh \
    https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh
echo -n -e "${RED}"

#TMUX
ln -s "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

#ALBERT
# if ! [ -d ~/.config/albert ]; then
    # mkdir ~/.config/albert
# fi
# ln -s $SCRIPT_DIR/albert.conf  ~/.config/albert/albert.conf
# ln -s $SCRIPT_DIR/albertignore ~/.albertignore

#ROFI
if ! [ -d ~/.config/rofi ]; then
    mkdir ~/.config/rofi
fi
ln -s "$SCRIPT_DIR/rofi" ~/.config/rofi/config.rasi

#FEH
if ! [ -d ~/.config/feh ]; then
    mkdir ~/.config/feh
fi
ln -s "$SCRIPT_DIR/feh_themes" ~/.config/feh/themes

#I3
if ! [ -d ~/.config/i3 ]; then
    mkdir ~/.config/i3
fi
ln -s "$SCRIPT_DIR/i3" ~/.config/i3/config

#I3BLOCKS
git clone https://github.com/vivien/i3blocks-contrib ~/.config/i3blocks

#SWAY
if ! [ -d ~/.config/sway ]; then
    mkdir ~/.config/sway
fi
ln -s "$SCRIPT_DIR/sway/config" ~/.config/sway/config
if ! [ -d ~/work ]; then
    ln -s "$SCRIPT_DIR/sway/default_monitor_preset" ~/.config/sway/default_monitor_preset
else
    ln -s "$SCRIPT_DIR/sway/work_monitor_preset" ~/.config/sway/default_monitor_preset
fi

#WAYBAR
if ! [ -d ~/.config/waybar ]; then
    mkdir ~/.config/waybar
fi
ln -s "$SCRIPT_DIR/sway/waybar/config" ~/.config/waybar/config
ln -s "$SCRIPT_DIR/sway/waybar/style.css" ~/.config/waybar/style.css

#KITTY
if ! [ -d ~/.config/kitty ]; then
    mkdir ~/.config/kitty
fi
ln -s "$SCRIPT_DIR/kitty.conf" ~/.config/kitty/kitty.conf

#DUNST
if ! [ -d ~/.config/dunst ]; then
    mkdir ~/.config/dunst
fi
ln -s "$SCRIPT_DIR/dunstrc" ~/.config/dunst/dunstrc

#RANGER
if ! [ -d ~/.config/ranger ]; then
    mkdir ~/.config/ranger
fi
ln -s "$SCRIPT_DIR/ranger" ~/.config/ranger/rc.conf

#ZSH
if ! [ -d ~/.oh-my-zsh ]; then
    echo -n -e "${GREEN}"
    git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
    echo -n -e "${RED}"
fi
ln -s "$SCRIPT_DIR/zshrc" ~/.zshrc

#AG
ln -s "$SCRIPT_DIR/ignore" ~/.ignore

#GITCONFIG
ln -s "$SCRIPT_DIR/gitconfig" ~/.gitconfig
ln -s "$SCRIPT_DIR/git_funcs.sh" ~/.git_funcs.sh

#AUTORANDR
product_serial="$(sudo cat /sys/devices/virtual/dmi/id/product_serial)"
ln -s "$SCRIPT_DIR/autorandr/${product_serial}" ~/.config/autorandr

#WORK DOTFILES
if [ -d ~/work ]; then
    echo -n -e "${GREEN}"
    echo "install dotfiles for work"
    echo -n -e "${RED}"

    #CREATE WORK DIRS
    mkdir -p ~/shared/{bins,configs,firmwares,logs,other,screenshots,trash}

    #DOCKER
    sudo rm -f /etc/docker/daemon.json
    sudo mkdir -p /etc/docker && sudo cp "$SCRIPT_DIR/work/daemon.json" /etc/docker/

    #GITCONFIG
    rm -f ~/work/.gitconfig
    ln -s "$SCRIPT_DIR/work/gitconfig" ~/work/.gitconfig
fi


echo -e "${BLUE}done"

