# dotfiles
## some binds
### term

| Action          | Binding                       |
| --------------- | ----------------------------- |
| shift + mouse   | sel area                      |

### picocom

| Action             | Binding                       |
| ------------------ | ----------------------------- |
| ctrl + a  ctrl + x | exit picocom                  |

### bash

| Action          | Binding                       |
| --------------- | ----------------------------- |
| ctrl + w        | del word before cursor        |
| ctrl + u        | del line before cursor        |
| ctrl + a        | mv to start line              |
| ctrl + e        | mv to end line                |
| ctrl + b        | mv back one character         |
| alt + b         | mv back one word              |
| ctrl + f        | mv forw one character         |
| alt + f         | mv forw one word              |

### zsh

| Action          | Binding                       |
| --------------- | ----------------------------- |
| ctrl + t        | fzf file                      |
| alt + c         | cd dir                        |

### tmux

| Action           | Binding                       |
| ---------------- | ----------------------------- |
| prefix + p / n   | prev / next win               |
| prefix + &       | win win                       |
| prefix + x       | kill pane                     |
| prefix + d       | detach                        |
| prefix + space   | change loc win                |
| prefix +  { / }  | move pane left/right          |
| prefix + z       | fullsize win                  |
| prefix + /       | serach                        |
| prefix + ,       | rename window                 |
| prefix w         | win list                      |
| prefix !         | pane on new window            |
| :capture-pane    | pane copy in buf              |
| prefix [         | copy mode                     |
|                  | space - select                |
|                  | enter - paste in buf          |
|                  | * -  search cur word          |
|                  | :choose-buffer / = - open buf |
| prefix + ( / )   | prev/next session             |
| prefix + L       | last session                  |
| list-keys        | -                             |
| ---------------- | ----------------------------- |
| copy mode: y     | copy to clipboard             |
| prefix + Alt + x | kill window                   |
| prefix + X       | kill session                  |
| prefix + I       | install plugins               |
| prefix + U       | update plugins                |

### dunst
| Action               | Binding                       |
| -------------------- | ----------------------------- |
| shift + space        | hide notif                    |
| ctrl + shift + space | hide all notif                |
| ctrl + \`            | show old notif                |
| ctrl + shift + .     | show context menu             |

### vim

| Action          | Binding                       |
| --------------- | ----------------------------- |
| ^               | start line                    |
| ctrl + w q      | close win                     |
| ctrl + w n      | new win                       |
| ctrl + w o      | close all win, but cur        |
| :noh            | hide highlight                |
| dt'             | del to '                      |
| mp              | create mark p                 |
| ''              | last location                 |
| ; + ''          | last tab                      |
| 'p              | mv to mark p                  |
| '.              | mv to last change             |
| mD              | global mark                   |
| gf              | open file                     |
| I               | insert in start line          |
| ; + cm          | comment block                 |
| ; + cc          | comment line                  |
| ; + cu          | uncomment                     |
| ctrl + w H      | turn vert split               |
| ctrl + w K      | turn hori split               |
| ctrl + w L      | mv win right                  |
| ctrl + w S      | hori split                    |
| ctrl + w v      | vert split                    |
| ctrl+w < / >    | resize win                    |
| shift+z+z       | :wq                           |
| ctrl+z          | bg                            |
| ==              | indent line                   |
| ctrl + p / n    | autocomplete                  |
| gUw             | capitalized word              |
| :%s/str/str1/gc | replace word with req         |
| gt / gT         | next / prev tab               |
| ctrl + w T      | open win in new tab           |
| [b / ]b         | switch buf                    |
| ]l / [l         | go to err linter?             |
| ] \<space\>     | space before after cur line   |
| ]e / [e         | mv line up/down               |
| ctrl + d / u    | scroll half page              |
| ctrl + f / b    | scroll page                   |
| zz              | cursor centered               |
| 3K              | open man 3                    |
| J               | del symb \n                   |
| :Tabularize /\  | tabularize \                  |
| :tabdo e        | reload all tabs               |
| :set syntax=sh  | syntax hi                     |
| [{  /  }]       | go to parent bracket          |
| [[  /  ]]       | go to bracket                 |
| ; + t           | new tab                       |
| Enter           | highlight cur word            |
| ; + m           | Marks                         |
| *               | search whole word under cur   |
| ; + /           | search whole word             |
| %               | move to '({""})'              |
| ctrl + c        | copy to clipboard             |
| E file.txt      | open file in new tab          |
| /nnoremap\|vnoremap | hi several words          |

### spell checking

| Action          | Binding                       |
| --------------- | ----------------------------- |
| ]s / [s         | next/prev misspelled word     |
| z=              | show alternatives             |
| zg              | add word to dict              |
| zug             | undo add work to dict         |
| zw              | mark word incorrect           |

#### paste text in several lines
* Move the cursor to the n in name.
* Enter visual block mode (Ctrlv).
* Press j three times (or 3j).
* Press I (capital i).
* Type text.
* Press Esc.

### macros

| Action          | Binding                       |
| --------------- | ----------------------------- |
| qa              | rec macros "a"                |
| q               | stop rec                      |
| @a              | run macros "a"                |
| @@              | repeat last macros            |


### ctags

| Action          | Binding                       |
| --------------- | ----------------------------- |
| ctrl + ]        | go to def                     |
| ctrl + t        | go back                       |
| ctrl + w + ]    | go to def in new window       |
| ctrl + w + t    | go back in new window         |


### nerdtree:

| Action          | Binding                       |
| --------------- | ----------------------------- |
| i               | open in hori win              |
| s               | open in vert win              |
| t               | open in new tab               |
| m               | menu                          |
| cd              | change dir                    |

### fzf

| Command           | List                                                                     |
| ----------------- | -------------------------------------------------------------------------|
| `Files [PATH]`    | Files (similar to  `:FZF` )                                              |
| `GFiles [OPTS]`   | Git files ( `git ls-files` )                                             |
| `GFiles?`         | Git files ( `git status` )                                               |
| `Buffers`         | Open buffers                                                             |
| `Colors`          | Color schemes                                                            |
| `Ag [PATTERN]`    | {ag}{6} search result ( `ALT-A` to select all, `ALT-D`  to deselect all) |
| `Rg [PATTERN]`    | {rg}{7} search result ( `ALT-A` to select all, `ALT-D`  to deselect all) |
| `Lines [QUERY]`   | Lines in loaded buffers                                                  |
| `BLines [QUERY]`  | Lines in the current buffer                                              |
| `Tags [QUERY]`    | Tags in the project ( `ctags -R` )                                       |
| `BTags [QUERY]`   | Tags in the current buffer                                               |
| `Marks`           | Marks                                                                    |
| `Windows`         | Windows                                                                  |
| `Locate PATTERN`  | `locate`  command output                                                 |
| `History`         | `v:oldfiles`  and open buffers                                           |
| `History:`        | Command history                                                          |
| `History/`        | Search history                                                           |
| `Snippets`        | Snippets ({UltiSnips}{8})                                                |
| `Commits`         | Git commits (requires {fugitive.vim}{9})                                 |
| `BCommits`        | Git commits for the current buffer                                       |
| `Commands`        | Commands                                                                 |
| `Maps`            | Normal mode mappings                                                     |
| `Helptags`        | Help tags [1]                                                            |
| `Filetypes`       | File types                                                               |
| p / n             | prev / next search                                                       |
| tab               | select several files                                                     |

#### [Search syntax](https://github.com/junegunn/fzf#search-syntax)

Unless otherwise specified, fzf starts in "extended-search mode" where you can
type in multiple search terms delimited by spaces. e.g. `^music .mp3$ sbtrkt
!fire`

| Token     | Match type                 | Description                          |
| --------- | -------------------------- | ------------------------------------ |
| `sbtrkt`  | fuzzy-match                | Items that match `sbtrkt`            |
| `'wild`   | exact-match (quoted)       | Items that include `wild`            |
| `^music`  | prefix-exact-match         | Items that start with `music`        |
| `.mp3$`   | suffix-exact-match         | Items that end with `.mp3`           |
| `!fire`   | inverse-exact-match        | Items that do not include `fire`     |
| `!^music` | inverse-prefix-exact-match | Items that do not start with `music` |
| `!.mp3$`  | inverse-suffix-exact-match | Items that do not end with `.mp3`    |

### ag:

| Action          | Binding                       |
| --------------- | ----------------------------- |
| :Ag def ./      | ?                             |

### fugitive:

| Action              | Binding                       |
| ------------------- | ----------------------------- |
| cc                  | commit                        |
| --                  | add all                       |
| O                   | jump in new tab               |
| in Gblame: Ctrl + o | going back to edit file       |

### gitgutter:

| Action          | Binding                       |
| --------------- | ----------------------------- |
| ]c / [c         | go to next / prev changes     |
| ;hu             | undo changes                  |
| ;hp             | previw                        |
| ;hs             | stage                         |
| git reset HEAD^ | roll back last commit         |

### InstantMarkdown:

| Action                 | Binding                       |
| ---------------        | ----------------------------- |
| InstantMarkdownPreview | open md in browser            |
| InstantMarkdownStop    | stop md prew                  |

### EUNUCH.VIM

| Action          | Binding                                                              |
| --------------- | -------------------------------------------------------------------- |
| :Delete         | Delete a buffer and the file on disk simultaneously.                 |
| :Unlink         | Like :Delete, but keeps the now empty buffer.                        |
| :Move           | Rename a buffer and the file on disk simultaneously.                 |
| :Rename         | Like :Move, but relative to the current file's containing directory. |
| :Chmod          | Change the permissions of the current file.                          |
| :Mkdir          | Create a directory, defaulting to the parent of the current file.    |
| :Cfind          | Run find and load the results into the quickfix list.                |
| :Clocate        | Run locate and load the results into the quickfix list.              |
| :Lfind/         | Llocate: Like above, but use the location list.                      |
| :Wall           | Write every open window. Handy for kicking off tools like guard.     |
| :SudoWrite      | Write a privileged file with sudo.                                   |
| :SudoEdit       | Edit a privileged file with sudo.                                    |
| |File type detection for sudo -e is based on original file name.                       |
| |New files created with a shebang line are automatically made executable.              |
| |New init scripts are automatically prepopulated with /etc/init.d/skeleton.            |

### CtrlSF

| Action                 | Binding                                                                              |
| ---------------------- | ------------------------------------------------------------------------------------ |
| Enter, o, double-click | Open corresponding file of current line in the window which CtrlSF is launched from. |
| C + O                  | Like Enter but open file in a horizontal split window.                               |
| t                      | Like Enter but open file in a new tab.                                               |
| p                      | Like Enter but open file in a preview window.                                        |
| P                      | Like Enter but open file in a preview window and switch focus to it.                 |
| O                      | Like Enter but always leave CtrlSF window opening.                                   |
| T                      | Like t but focus CtrlSF window instead of new opened tab.                            |
| M                      | Switch result window between normal view and compact view.                           |
| q                      | Quit CtrlSF window.                                                                  |
| C + J                  | Move cursor to next match.                                                           |
| C + K                  | Move cursor to previous match.                                                       |
| C + C                  | Stop a background searching process.                                                 |
| q                      | Close preview window.                                                                |


### Funcs and tricks
#### simple func
    map <silent> <C-d> :call MyTabClose()<CR>
    function! MyTabClose()
            let numtab = tabpagenr()
            if ( numtab == 1 )
                    qa
            else
                    tabclose
            endif
    endfunction


https://i3wm.org/docs/refcard.html

### pyrightconfig.json
{
    "extraPaths": [
        "/home/estor/.local/lib/python3.10/site-packages/",
        "/usr/lib64/python3.10/site-packages/"
    ]
}

### clangd
:CocCommand workspace.showOutput
